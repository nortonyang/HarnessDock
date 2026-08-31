import Foundation

public struct HarnessPetProfileState: Equatable, Sendable {
    public let hasLegacyDependency: Bool
    public let hasLegacyBundle: Bool
    public let hasCurrentDependency: Bool
    public let hasCurrentBundle: Bool
    public let currentDependencySpecifier: String?

    public var needsMigration: Bool {
        hasLegacyDependency || hasLegacyBundle
    }

    public var canBootCurrentPet: Bool {
        !hasLegacyBundle && hasCurrentDependency && hasCurrentBundle
    }

    public func needsBundledRelink(to pluginURL: URL) -> Bool {
        guard let currentDependencySpecifier,
              currentDependencySpecifier.hasPrefix("link:"),
              currentDependencySpecifier.contains(
                "/Contents/Resources/Plugins/harnessdock-pet"
              )
        else { return false }

        return currentDependencySpecifier != "link:\(pluginURL.standardizedFileURL.path)"
    }
}

public enum HarnessPetProfileMigration {
    public static let legacyPackageName = "@dsharness/pet"
    public static let currentPackageName = "@harnessdock/pet"

    public static func state(from manifestData: Data) -> HarnessPetProfileState? {
        guard let manifest = try? JSONSerialization.jsonObject(with: manifestData)
            as? [String: Any]
        else { return nil }

        let dependencies = manifest["dependencies"] as? [String: Any] ?? [:]
        let dsh = manifest["dsh"] as? [String: Any]
        let profile = dsh?["profile"] as? [String: Any]
        let bundles = profile?["bundles"] as? [String] ?? []

        return HarnessPetProfileState(
            hasLegacyDependency: dependencies[legacyPackageName] != nil,
            hasLegacyBundle: bundles.contains(legacyPackageName),
            hasCurrentDependency: dependencies[currentPackageName] != nil,
            hasCurrentBundle: bundles.contains(currentPackageName),
            currentDependencySpecifier: dependencies[currentPackageName] as? String
        )
    }

    public static func manifestURL(
        profile: String = "web",
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        currentDirectory: URL
    ) -> URL {
        let configuredHome = environment["DSH_HOME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let dshHome: URL

        if let configuredHome, !configuredHome.isEmpty {
            if configuredHome == "~" {
                dshHome = homeDirectory
            } else if configuredHome.hasPrefix("~/") {
                dshHome = homeDirectory.appending(
                    path: String(configuredHome.dropFirst(2)),
                    directoryHint: .isDirectory
                )
            } else if configuredHome.hasPrefix("/") {
                dshHome = URL(fileURLWithPath: configuredHome, isDirectory: true)
            } else {
                dshHome = currentDirectory.appending(
                    path: configuredHome,
                    directoryHint: .isDirectory
                )
            }
        } else {
            dshHome = homeDirectory.appending(path: ".dsh", directoryHint: .isDirectory)
        }

        return dshHome
            .standardizedFileURL
            .appending(path: "profiles", directoryHint: .isDirectory)
            .appending(path: profile, directoryHint: .isDirectory)
            .appending(path: "package.json")
    }
}
