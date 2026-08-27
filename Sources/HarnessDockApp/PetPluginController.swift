import AppKit
import HarnessDockCore
import Foundation
import ImageIO

enum PetPackageOrigin: String {
    case bundled
    case codex
    case managed

    var title: String {
        switch self {
        case .bundled:
            "HarnessDock 内置"
        case .codex:
            "Codex 宠物"
        case .managed:
            "HarnessDock 导入"
        }
    }
}

struct PetPluginPackage: Identifiable {
    let id: String
    let manifest: PetPluginManifest
    let directoryURL: URL
    let spritesheetURL: URL
    let image: NSImage
    let origin: PetPackageOrigin

    var displayName: String {
        manifest.name
    }
}

@MainActor
final class PetPluginController: ObservableObject {
    @Published var showSettings = false
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledDefaultsKey) }
    }
    @Published private(set) var packages: [PetPluginPackage] = []
    @Published private(set) var selectedPackageID: String? {
        didSet { defaults.set(selectedPackageID, forKey: Self.selectedPackageDefaultsKey) }
    }
    @Published private(set) var displayScale: Double
    @Published private(set) var lastError: String?

    private static let enabledDefaultsKey = "petPluginEnabled"
    private static let selectedPackageDefaultsKey = "petPluginSelectedPackage"
    private static let scaleDefaultsKey = "petPluginDisplayScale"

    private let defaults: UserDefaults
    private let fileManager: FileManager

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        isEnabled = defaults.object(forKey: Self.enabledDefaultsKey) as? Bool ?? true
        selectedPackageID = defaults.string(forKey: Self.selectedPackageDefaultsKey)
        let savedScale = defaults.object(forKey: Self.scaleDefaultsKey) as? Double ?? 1
        displayScale = min(max(savedScale, 0.65), 1.45)
        refreshPackages()
    }

    var selectedPackage: PetPluginPackage? {
        packages.first { $0.id == selectedPackageID }
    }

    func selectPackage(id: String) {
        guard packages.contains(where: { $0.id == id }) else { return }
        selectedPackageID = id
    }

    func setDisplayScale(_ value: Double) {
        let normalizedValue = min(max(value, 0.65), 1.45)
        displayScale = normalizedValue
        defaults.set(normalizedValue, forKey: Self.scaleDefaultsKey)
    }

    func refreshPackages() {
        var discovered: [PetPluginPackage] = []
        var errors: [String] = []

        if let bundledPetsURL = Self.bundledPetsURL(fileManager: fileManager) {
            scanPackages(
                at: bundledPetsURL,
                origin: .bundled,
                discovered: &discovered,
                errors: &errors
            )
        }

        let codexPetsURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/pets", isDirectory: true)
        scanPackages(
            at: codexPetsURL,
            origin: .codex,
            discovered: &discovered,
            errors: &errors
        )

        if let managedPetsURL = try? Self.managedPetsURL(
            fileManager: fileManager,
            createDirectory: false
        ) {
            scanPackages(
                at: managedPetsURL,
                origin: .managed,
                discovered: &discovered,
                errors: &errors
            )
        }

        packages = discovered.sorted {
            let nameOrder = $0.displayName.localizedStandardCompare($1.displayName)
            if nameOrder == .orderedSame {
                return $0.id < $1.id
            }
            return nameOrder == .orderedAscending
        }

        if selectedPackage == nil {
            selectedPackageID = packages.first {
                $0.origin == .bundled && $0.manifest.id == "deepwhale"
            }?.id ?? packages.first?.id
        }
        lastError = errors.isEmpty
            ? nil
            : "已忽略 \(errors.count) 个无效宠物包：\(errors.prefix(2).joined(separator: "；"))"
    }

    func importPackage(language: AppLanguage = .system) {
        let panel = NSOpenPanel()
        panel.title = AppLocalization.localized("导入 HarnessDock 宠物包", language: language)
        panel.message = AppLocalization.localized(
            "请选择包含 pet.json 与 spritesheet.webp 的宠物文件夹。",
            language: language
        )
        panel.prompt = AppLocalization.localized("导入", language: language)
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        do {
            let sourcePackage = try Self.loadPackage(
                at: sourceURL,
                origin: .managed,
                fileManager: fileManager
            )
            let managedPetsURL = try Self.managedPetsURL(
                fileManager: fileManager,
                createDirectory: true
            )
            let destinationURL = uniqueDestination(
                in: managedPetsURL,
                preferredName: sourcePackage.manifest.id
            )

            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                _ = try Self.loadPackage(
                    at: destinationURL,
                    origin: .managed,
                    fileManager: fileManager
                )
            } catch {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try? fileManager.removeItem(at: destinationURL)
                }
                throw error
            }

            refreshPackages()
            selectedPackageID = Self.packageIdentifier(
                for: destinationURL,
                origin: .managed
            )
            isEnabled = true
        } catch {
            let format = AppLocalization.localized("无法导入宠物包：%@", language: language)
            lastError = String(format: format, locale: language.locale, error.localizedDescription)
        }
    }

    private func scanPackages(
        at rootURL: URL,
        origin: PetPackageOrigin,
        discovered: inout [PetPluginPackage],
        errors: inout [String]
    ) {
        guard fileManager.fileExists(atPath: rootURL.path) else { return }

        do {
            let directories = try fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for directoryURL in directories {
                let values = try? directoryURL.resourceValues(forKeys: [.isDirectoryKey])
                guard values?.isDirectory == true else { continue }
                do {
                    discovered.append(
                        try Self.loadPackage(
                            at: directoryURL,
                            origin: origin,
                            fileManager: fileManager
                        )
                    )
                } catch {
                    errors.append("\(directoryURL.lastPathComponent)：\(error.localizedDescription)")
                }
            }
        } catch {
            errors.append("\(rootURL.lastPathComponent)：\(error.localizedDescription)")
        }
    }

    private func uniqueDestination(in directoryURL: URL, preferredName: String) -> URL {
        var candidate = directoryURL.appendingPathComponent(preferredName, isDirectory: true)
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directoryURL.appendingPathComponent(
                "\(preferredName)-\(suffix)",
                isDirectory: true
            )
            suffix += 1
        }
        return candidate
    }

    private static func loadPackage(
        at directoryURL: URL,
        origin: PetPackageOrigin,
        fileManager: FileManager
    ) throws -> PetPluginPackage {
        let manifestURL = directoryURL.appendingPathComponent("pet.json", isDirectory: false)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw PetPackageLoadError.missingManifest
        }

        let manifest: PetPluginManifest
        do {
            manifest = try JSONDecoder().decode(
                PetPluginManifest.self,
                from: Data(contentsOf: manifestURL)
            )
            try manifest.validate()
        } catch let error as PetPluginManifestError {
            throw error
        } catch {
            throw PetPackageLoadError.invalidManifest(error.localizedDescription)
        }

        let spritesheetURL = try manifest.spritesheetURL(in: directoryURL)
        guard fileManager.fileExists(atPath: spritesheetURL.path) else {
            throw PetPackageLoadError.missingSpritesheet
        }
        guard let imageSource = CGImageSourceCreateWithURL(spritesheetURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
                as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width == PetPluginManifest.canonicalFrameWidth
                * PetPluginManifest.canonicalColumns,
              height == PetPluginManifest.canonicalFrameHeight
                * PetPluginManifest.canonicalRows,
              let image = NSImage(contentsOf: spritesheetURL)
        else {
            throw PetPackageLoadError.invalidSpritesheetDimensions
        }

        return PetPluginPackage(
            id: packageIdentifier(for: directoryURL, origin: origin),
            manifest: manifest,
            directoryURL: directoryURL,
            spritesheetURL: spritesheetURL,
            image: image,
            origin: origin
        )
    }

    private static func packageIdentifier(
        for directoryURL: URL,
        origin: PetPackageOrigin
    ) -> String {
        "\(origin.rawValue):\(directoryURL.lastPathComponent)"
    }

    private static func managedPetsURL(
        fileManager: FileManager,
        createDirectory: Bool
    ) throws -> URL {
        guard let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw PetPackageLoadError.storageUnavailable
        }

        let directoryURL = applicationSupportURL
            .appendingPathComponent("app.dsharness.desktop", isDirectory: true)
            .appendingPathComponent("Pets", isDirectory: true)
        if createDirectory {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }
        return directoryURL
    }

    private static func bundledPetsURL(fileManager: FileManager) -> URL? {
        if let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("Pets", isDirectory: true),
            fileManager.fileExists(atPath: resourceURL.path)
        {
            return resourceURL
        }

        #if SWIFT_PACKAGE
        if let resourceURL = Bundle.module.resourceURL?
            .appendingPathComponent("Pets", isDirectory: true),
            fileManager.fileExists(atPath: resourceURL.path)
        {
            return resourceURL
        }
        #endif

        return nil
    }
}

private enum PetPackageLoadError: LocalizedError {
    case missingManifest
    case invalidManifest(String)
    case missingSpritesheet
    case invalidSpritesheetDimensions
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .missingManifest:
            "缺少 pet.json。"
        case let .invalidManifest(message):
            "pet.json 无效：\(message)"
        case .missingSpritesheet:
            "找不到清单指定的宠物图集。"
        case .invalidSpritesheetDimensions:
            "图集无法读取或不是 1536×1872 像素。"
        case .storageUnavailable:
            "无法访问应用的本地数据目录。"
        }
    }
}
