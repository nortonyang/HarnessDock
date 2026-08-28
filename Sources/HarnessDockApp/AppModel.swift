import AppKit
import Combine
import Darwin
import HarnessDockCore
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum HarnessStatus: Equatable {
    case idle
    case locatingRuntime
    case launching
    case running(managed: Bool)
    case failed(String)
}

enum AppSurface: String, CaseIterable, Identifiable {
    case harness
    case chat

    var id: Self { self }

    var title: String {
        switch self {
        case .harness: "Harness"
        case .chat: "Chat"
        }
    }
}

enum AppSettingsSection: String, CaseIterable, Identifiable {
    case apiBalance
    case themeBackground
    case language

    var id: Self { self }

    var title: String {
        switch self {
        case .apiBalance: "API 与余额"
        case .themeBackground: "主题背景"
        case .language: "语言"
        }
    }

    var systemImage: String {
        switch self {
        case .apiBalance: "wallet.pass.fill"
        case .themeBackground: "photo.on.rectangle.angled"
        case .language: "globe"
        }
    }
}

enum BalanceState: Equatable {
    case notConfigured
    case loading
    case loaded(DeepSeekBalanceResponse, refreshedAt: Date)
    case failed(String)
}

enum BalanceCredentialSource: Equatable {
    case none
    case environment
    case keychain
}

struct BalanceWebPresentation: Codable, Equatable {
    struct Labels: Codable, Equatable {
        let language: String
        let themeBackground: String
        let themeBackgroundConfigured: String
        let balanceHeading: String
        let peakPeriod: String
        let offPeakPeriod: String
        let collapseBalanceDetails: String
        let collapse: String
        let grantedPrefix: String
        let toppedUpPrefix: String
        let loadingBalance: String
        let sessionTokens: String
        let noUsage: String
        let input: String
        let output: String
        let viewModelPricing: String
        let cacheHit: String
        let cacheMiss: String
        let configureAPIKey: String
        let refresh: String
    }

    struct Entry: Codable, Equatable {
        let currency: String
        let total: String
        let granted: String
        let toppedUp: String
    }

    struct Pricing: Codable, Equatable {
        let currentPeriod: String
        let currentPeriodLabel: String
        let nextPeriodLabel: String
        let nextSwitchLabel: String
        let scheduleLabel: String
        let unitLabel: String
        let sourceLabel: String
        let models: [DeepSeekModelPricing]
    }

    let title: String
    let subtitle: String
    let tone: String
    let state: String
    let error: String?
    let updatedLabel: String?
    let entries: [Entry]
    let pricing: Pricing?
    let labels: Labels
}

struct ThemeBackgroundPresentation: Codable, Equatable {
    let imageDataURL: String?
    let dimmingOpacity: Double
}

private enum ThemeBackgroundError: LocalizedError {
    case invalidImage
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "无法读取这张图片，请选择有效的 JPEG、PNG、HEIC 或其他常见图片。"
        case .storageUnavailable:
            "无法访问应用的本地数据目录。"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var appLanguage: AppLanguage = .system
    @Published private(set) var selectedSurface: AppSurface = .harness
    @Published private(set) var hasOpenedDeepSeekChat = false
    @Published private(set) var workspaceURL: URL?
    @Published private(set) var status: HarnessStatus = .idle
    @Published private(set) var logText = ""
    @Published var webViewIsLoading = false
    @Published var webViewError: String?
    @Published var chatWebViewIsLoading = false
    @Published var chatWebViewError: String?
    @Published var showLogs = false
    @Published private(set) var selectedSettingsSection: AppSettingsSection = .apiBalance
    @Published private(set) var settingsRequestID = 0
    @Published private(set) var homeRequestID = 0
    @Published private(set) var reloadRequestID = 0
    @Published private(set) var chatReloadRequestID = 0
    @Published private(set) var balanceState: BalanceState = .notConfigured
    @Published private(set) var balanceCredentialSource: BalanceCredentialSource = .none
    @Published private(set) var balanceCredentialError: String?
    @Published private(set) var themeBackgroundData: Data?
    @Published private(set) var themeBackgroundDimmingOpacity = 0.62
    @Published private(set) var themeBackgroundError: String?

    let configuration: HarnessConfiguration
    let deepSeekChatURL = URL(string: "https://chat.deepseek.com/")!

    private let workspaceDefaultsKey = "lastWorkspacePath"
    private let themeDimmingDefaultsKey = "themeBackgroundDimmingOpacity"
    private let appLanguageDefaultsKey = "appLanguage"
    private let balanceClient = DeepSeekBalanceClient()
    private let balanceKeychain = BalanceKeychain()
    private var process: Process?
    private var outputPipe: Pipe?
    private var startupTask: Task<Void, Never>?
    private var balanceTask: Task<Void, Never>?
    private var loginShellAPIKey: String?
    private var expectedTerminationProcessIDs = Set<Int32>()
    private var didRestoreWorkspace = false
    /// PID of the `node` process actually serving the port we launched
    /// (npx wraps it, so terminating only npx could orphan the server).
    private var managedServerPID: Int32?

    var projectName: String? {
        workspaceURL?.lastPathComponent
    }

    init() {
        configuration = HarnessConfiguration(port: Self.portArgument() ?? 3_080)
        if let savedLanguage = UserDefaults.standard.string(forKey: appLanguageDefaultsKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            appLanguage = language
        }
        if let savedDimming = UserDefaults.standard.object(
            forKey: themeDimmingDefaultsKey
        ) as? Double {
            themeBackgroundDimmingOpacity = min(max(savedDimming, 0.25), 0.85)
        }
        loadThemeBackground()
        updateBalanceCredentialSource()
    }

    func localized(_ key: String) -> String {
        AppLocalization.localized(key, language: appLanguage)
    }

    func localized(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: localized(key),
            locale: appLanguage.locale,
            arguments: arguments
        )
    }

    func setAppLanguage(_ language: AppLanguage) {
        guard appLanguage != language else { return }
        appLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: appLanguageDefaultsKey)
    }

    var isManagedServer: Bool {
        if case let .running(managed) = status {
            return managed
        }
        return false
    }

    var hasEnvironmentBalanceAPIKey: Bool {
        environmentBalanceAPIKey() != nil
    }

    func balanceWebPresentation(at date: Date = Date()) -> BalanceWebPresentation {
        let pricing = pricingWebPresentation(at: date)
        let labels = balanceWebLabels

        switch balanceState {
        case .notConfigured:
            return BalanceWebPresentation(
                title: localized("配置 API 余额"),
                subtitle: localized("安全配置"),
                tone: "neutral",
                state: "notConfigured",
                error: nil,
                updatedLabel: nil,
                entries: [],
                pricing: pricing,
                labels: labels
            )
        case .loading:
            return BalanceWebPresentation(
                title: localized("正在查询余额"),
                subtitle: localized("DeepSeek 开放平台"),
                tone: "loading",
                state: "loading",
                error: nil,
                updatedLabel: nil,
                entries: [],
                pricing: pricing,
                labels: labels
            )
        case let .failed(message):
            return BalanceWebPresentation(
                title: localized("余额查询失败"),
                subtitle: localized("点击查看详情"),
                tone: "error",
                state: "failed",
                error: message,
                updatedLabel: nil,
                entries: [],
                pricing: pricing,
                labels: labels
            )
        case let .loaded(response, refreshedAt):
            return BalanceWebPresentation(
                title: response.preferredInfo?.displayTotal ?? localized("余额已同步"),
                subtitle: response.isAvailable
                    ? localized("API 余额可用")
                    : localized("API 暂不可用"),
                tone: response.isAvailable ? "success" : "warning",
                state: "loaded",
                error: nil,
                updatedLabel: localized(
                    "更新于 %@",
                    refreshedAt.formatted(date: .omitted, time: .shortened)
                ),
                entries: response.balanceInfos.map {
                    BalanceWebPresentation.Entry(
                        currency: $0.currency.uppercased(),
                        total: $0.displayTotal,
                        granted: $0.displayGranted,
                        toppedUp: $0.displayToppedUp
                    )
                },
                pricing: pricing,
                labels: labels
            )
        }
    }

    private var balanceWebLabels: BalanceWebPresentation.Labels {
        BalanceWebPresentation.Labels(
            language: appLanguage.resolvedIdentifier,
            themeBackground: localized("主题背景"),
            themeBackgroundConfigured: localized("主题背景，已设置"),
            balanceHeading: localized("DeepSeek API 余额"),
            peakPeriod: localized("高峰期"),
            offPeakPeriod: localized("谷时"),
            collapseBalanceDetails: localized("收起余额明细"),
            collapse: localized("收起"),
            grantedPrefix: localized("赠送"),
            toppedUpPrefix: localized("充值"),
            loadingBalance: localized("正在向 DeepSeek 查询余额…"),
            sessionTokens: localized("当前会话 tokens"),
            noUsage: localized("暂无用量"),
            input: localized("输入"),
            output: localized("输出"),
            viewModelPricing: localized("查看模型价格"),
            cacheHit: localized("命中"),
            cacheMiss: localized("未命中"),
            configureAPIKey: localized("配置 API Key"),
            refresh: localized("刷新")
        )
    }

    private func pricingWebPresentation(at date: Date) -> BalanceWebPresentation.Pricing {
        let status = DeepSeekAPIPricing.status(at: date)
        let formatter = DateFormatter()
        formatter.locale = appLanguage.locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "EEE HH:mm"
        let currentPeriod = localized(status.period == .peak ? "高峰" : "谷时")
        let nextPeriod = localized(status.nextPeriod == .peak ? "高峰" : "谷时")

        return BalanceWebPresentation.Pricing(
            currentPeriod: status.period.rawValue,
            currentPeriodLabel: localized("当前%@", currentPeriod),
            nextPeriodLabel: nextPeriod,
            nextSwitchLabel: localized(
                "%@ 切换为%@",
                formatter.string(from: status.nextTransition),
                nextPeriod
            ),
            scheduleLabel: localized("工作日 09:00–12:00、14:00–18:00 高峰；其余谷时（北京时间）"),
            unitLabel: localized("人民币 / 百万 tokens"),
            sourceLabel: localized("DeepSeek 中文价格表"),
            models: DeepSeekAPIPricing.models
        )
    }

    var themeBackgroundPresentation: ThemeBackgroundPresentation {
        ThemeBackgroundPresentation(
            imageDataURL: themeBackgroundData.map {
                "data:image/jpeg;base64,\($0.base64EncodedString())"
            },
            dimmingOpacity: themeBackgroundDimmingOpacity
        )
    }

    var hasThemeBackground: Bool {
        themeBackgroundData != nil
    }

    func restoreWorkspaceIfNeeded() {
        guard !didRestoreWorkspace else { return }
        didRestoreWorkspace = true
        refreshBalance()

        if let argumentWorkspace = Self.workspaceArgument(),
           FileManager.default.fileExists(atPath: argumentWorkspace.path)
        {
            setWorkspace(argumentWorkspace)
            return
        }

        guard let savedPath = UserDefaults.standard.string(forKey: workspaceDefaultsKey) else {
            return
        }
        let savedURL = URL(fileURLWithPath: savedPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: savedURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            UserDefaults.standard.removeObject(forKey: workspaceDefaultsKey)
            return
        }
        setWorkspace(savedURL)
    }

    func chooseWorkspace() {
        let panel = NSOpenPanel()
        panel.title = localized("选择 DeepSeek Harness 工作区")
        panel.message = localized("Harness 的文件和命令权限将以这个项目目录为起点。")
        panel.prompt = localized("打开项目")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = workspaceURL

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        setWorkspace(selectedURL)
    }

    func enterDefaultWorkspace() {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            let message = localized("无法访问应用数据目录，不能创建默认工作区。")
            appendLog(message)
            status = .failed(message)
            return
        }

        let workspaceURL = applicationSupportURL
            .appendingPathComponent("app.dsharness.desktop", isDirectory: true)
            .appendingPathComponent("Workspace", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: workspaceURL,
                withIntermediateDirectories: true
            )
            setWorkspace(workspaceURL)
        } catch {
            let message = localized("无法创建默认工作区：%@", error.localizedDescription)
            appendLog(message)
            status = .failed(message)
        }
    }

    func chooseThemeBackground() {
        let panel = NSOpenPanel()
        panel.title = localized("选择主题背景图片")
        panel.message = localized("图片会缩放后保存在本机应用数据目录，不会写入当前项目。")
        panel.prompt = localized(hasThemeBackground ? "更换背景" : "设为背景")
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        do {
            let data = try Self.normalizedThemeBackgroundData(from: selectedURL)
            let destination = try themeBackgroundFileURL(createDirectory: true)
            try data.write(to: destination, options: .atomic)
            themeBackgroundData = data
            themeBackgroundError = nil
        } catch {
            themeBackgroundError = localized(error.localizedDescription)
        }
    }

    func setThemeBackgroundDimmingOpacity(_ value: Double) {
        let normalizedValue = min(max(value, 0.25), 0.85)
        themeBackgroundDimmingOpacity = normalizedValue
        UserDefaults.standard.set(normalizedValue, forKey: themeDimmingDefaultsKey)
    }

    func removeThemeBackground() {
        do {
            let fileURL = try themeBackgroundFileURL(createDirectory: false)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            themeBackgroundData = nil
            themeBackgroundError = nil
        } catch {
            themeBackgroundError = error.localizedDescription
        }
    }

    func retry() {
        guard let workspaceURL else { return }
        startHarness(in: workspaceURL)
    }

    func stop() {
        startupTask?.cancel()
        startupTask = nil
        balanceTask?.cancel()
        balanceTask = nil
        stopOwnedProcess()
        status = .idle
        webViewIsLoading = false
    }

    func requestHome() {
        homeRequestID += 1
        webViewError = nil
    }

    func requestReload() {
        reloadRequestID += 1
        webViewError = nil
    }

    func selectSurface(_ surface: AppSurface) {
        if surface == .chat {
            hasOpenedDeepSeekChat = true
            chatWebViewError = nil
        }
        selectedSurface = surface
    }

    func requestSelectedSurfaceReload() {
        switch selectedSurface {
        case .harness:
            requestReload()
        case .chat:
            chatReloadRequestID += 1
            chatWebViewError = nil
        }
    }

    func openDeepSeekChatInBrowser() {
        NSWorkspace.shared.open(deepSeekChatURL)
    }

    func openInBrowser() {
        NSWorkspace.shared.open(configuration.serverURL)
    }

    func copyLogs() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logText, forType: .string)
    }

    func refreshBalance() {
        balanceTask?.cancel()
        balanceTask = nil
        balanceCredentialError = nil

        guard let apiKey = balanceAPIKey() else {
            balanceState = .notConfigured
            return
        }

        balanceState = .loading
        let client = balanceClient
        balanceTask = Task { [weak self] in
            do {
                let response = try await client.fetch(apiKey: apiKey)
                guard !Task.isCancelled else { return }
                self?.balanceState = .loaded(response, refreshedAt: Date())
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.balanceState = .failed(self?.balanceFailureMessage(for: error) ?? error.localizedDescription)
            }
        }
    }

    func saveBalanceAPIKey(_ value: String) {
        let credential = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !credential.isEmpty else {
            balanceCredentialError = localized("请输入 DeepSeek API Key。")
            return
        }

        do {
            try balanceKeychain.save(credential)
            balanceCredentialSource = .keychain
            balanceCredentialError = nil
            refreshBalance()
        } catch {
            balanceCredentialError = error.localizedDescription
        }
    }

    func removeBalanceAPIKey() {
        do {
            try balanceKeychain.remove()
            balanceTask?.cancel()
            balanceTask = nil
            balanceCredentialError = nil
            updateBalanceCredentialSource()
            refreshBalance()
        } catch {
            balanceCredentialError = error.localizedDescription
        }
    }

    func handleBalanceWebAction(_ action: String) {
        switch action {
        case "settings":
            requestSettings(.apiBalance)
        case "refresh":
            refreshBalance()
        case "pricing":
            NSWorkspace.shared.open(DeepSeekAPIPricing.sourceURL)
        default:
            break
        }
    }

    func requestSettings(_ section: AppSettingsSection = .apiBalance) {
        selectedSettingsSection = section
        settingsRequestID += 1
    }

    func selectSettingsSection(_ section: AppSettingsSection) {
        selectedSettingsSection = section
    }

    private func loadThemeBackground() {
        do {
            let fileURL = try themeBackgroundFileURL(createDirectory: false)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            let data = try Data(contentsOf: fileURL)
            guard NSImage(data: data) != nil else {
                throw ThemeBackgroundError.invalidImage
            }
            themeBackgroundData = data
        } catch ThemeBackgroundError.storageUnavailable {
            themeBackgroundError = localized(ThemeBackgroundError.storageUnavailable.localizedDescription)
        } catch {
            themeBackgroundError = localized(error.localizedDescription)
        }
    }

    private func themeBackgroundFileURL(createDirectory: Bool) throws -> URL {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ThemeBackgroundError.storageUnavailable
        }

        let directoryURL = applicationSupportURL
            .appendingPathComponent("app.dsharness.desktop", isDirectory: true)
        if createDirectory {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }
        return directoryURL.appendingPathComponent("theme-background.jpg")
    }

    private static func normalizedThemeBackgroundData(from sourceURL: URL) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw ThemeBackgroundError.invalidImage
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2_560,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw ThemeBackgroundError.invalidImage
        }

        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.86]
        ) else {
            throw ThemeBackgroundError.invalidImage
        }
        return data
    }

    private func setWorkspace(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        workspaceURL = standardizedURL
        UserDefaults.standard.set(standardizedURL.path, forKey: workspaceDefaultsKey)
        startHarness(in: standardizedURL)
    }

    private func updateBalanceCredentialSource() {
        do {
            if let credential = try balanceKeychain.read()?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !credential.isEmpty
            {
                balanceCredentialSource = .keychain
                return
            }
        } catch {
            balanceCredentialError = error.localizedDescription
        }

        balanceCredentialSource = environmentBalanceAPIKey() == nil ? .none : .environment
    }

    private func balanceAPIKey() -> String? {
        do {
            if let storedCredential = try balanceKeychain.read() {
                let credential = storedCredential.trimmingCharacters(in: .whitespacesAndNewlines)
                if !credential.isEmpty {
                    balanceCredentialSource = .keychain
                    return credential
                }
            }
        } catch {
            balanceCredentialError = error.localizedDescription
        }

        if let credential = environmentBalanceAPIKey() {
            balanceCredentialSource = .environment
            return credential
        }

        balanceCredentialSource = .none
        return nil
    }

    private func environmentBalanceAPIKey() -> String? {
        Self.inheritedEnvironmentAPIKey() ?? loginShellAPIKey
    }

    private static func inheritedEnvironmentAPIKey() -> String? {
        guard let credential = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !credential.isEmpty
        else {
            return nil
        }
        return credential
    }

    private func balanceFailureMessage(for error: Error) -> String {
        if let balanceError = error as? DeepSeekBalanceError {
            switch balanceError {
            case .missingCredential:
                return localized("尚未配置 DeepSeek API Key。")
            case .invalidCredential:
                return localized("API Key 无效或已失效，请重新配置。")
            case let .httpStatus(code):
                return localized("余额服务返回 HTTP %@，请稍后重试。", String(code))
            case .invalidResponse:
                return localized("余额服务返回了无法识别的数据。")
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return localized("当前无法连接网络。")
            case .timedOut:
                return localized("查询余额超时，请重试。")
            default:
                return localized("暂时无法连接余额服务。")
            }
        }
        return localized("暂时无法查询余额。")
    }

    private func startHarness(in workspace: URL) {
        startupTask?.cancel()
        let previousProcess = process
        stopOwnedProcess()
        logText = ""
        webViewError = nil
        status = .locatingRuntime

        startupTask = Task { [weak self] in
            guard let self else { return }

            if let previousProcess {
                for _ in 0..<20 where previousProcess.isRunning {
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(for: .milliseconds(150))
                }
            }

            guard !Task.isCancelled else { return }
            await self.launchOrAttach(in: workspace)
        }
    }

    private func launchOrAttach(in workspace: URL) async {
        var environment = await resolvedHarnessEnvironment()
        guard !Task.isCancelled else { return }

        if await serverIsReachable() {
            guard await serverIsHarness() else {
                let message = "端口 \(configuration.port) 上已有其他 HTTP 服务，但不是 DeepSeek Harness。请先停止该服务，再重新启动。"
                appendLog(message)
                status = .failed(message)
                return
            }
            appendLog("检测到 \(configuration.serverURL.absoluteString) 已有 Harness 服务，已安全附着；本应用不会停止该进程。")
            status = .running(managed: false)
            homeRequestID += 1
            return
        }

        guard let npxURL = ExecutableLocator.locate("npx") else {
            let message = "找不到 npx。请先安装 Node.js 24 或更高版本，然后重新打开应用。"
            appendLog(message)
            status = .failed(message)
            return
        }

        let cachedRuntimeURL: URL?
        if let package = configuration.pinnedPackage {
            cachedRuntimeURL = ExecutableLocator.locateNpxCachedPackageBinary(
                "dsh",
                packagePath: package.path,
                version: package.version
            )
        } else {
            cachedRuntimeURL = nil
        }
        let executableURL = cachedRuntimeURL ?? npxURL
        let arguments = cachedRuntimeURL == nil
            ? configuration.npxArguments
            : configuration.webArguments

        appendLog("工作区：\(workspace.path)")
        if let cachedRuntimeURL {
            appendLog("已命中版本匹配的本地 DSH 缓存：\(cachedRuntimeURL.path)")
            appendLog("正在启动：dsh \(arguments.joined(separator: " "))")
        } else {
            appendLog("运行环境：\(npxURL.path)")
            appendLog("正在启动：npx \(arguments.joined(separator: " "))")
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = workspace
        process.standardOutput = pipe
        process.standardError = pipe

        let nodePath = ExecutableLocator.pathEnvironment(
            for: npxURL,
            inheritedPath: environment["PATH"]
        )
        environment["PATH"] = cachedRuntimeURL.map {
            ExecutableLocator.pathEnvironment(for: $0, inheritedPath: nodePath)
        } ?? nodePath
        // Preserve a launch-environment DEEPSEEK_API_KEY so the official
        // Harness credential resolver can use environment authentication.
        // A Keychain-only balance credential is never copied into this map.
        environment["NO_COLOR"] = "1"
        process.environment = environment

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.appendLog(chunk)
            }
        }

        process.terminationHandler = { [weak self] terminatedProcess in
            let processID = terminatedProcess.processIdentifier
            let exitCode = terminatedProcess.terminationStatus
            Task { @MainActor [weak self] in
                await self?.processDidTerminate(processID: processID, exitCode: exitCode)
            }
        }

        do {
            try process.run()
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            let message = "无法启动 DeepSeek Harness：\(error.localizedDescription)"
            appendLog(message)
            status = .failed(message)
            return
        }

        self.process = process
        outputPipe = pipe
        status = .launching

        // A cache miss can still require npx to download the pinned official
        // package, so allow a generous window and report progress.
        let waitLimit = 3_600  // 30 minutes of 500ms polls
        for attempt in 0..<waitLimit {
            guard !Task.isCancelled else { return }
            if await serverIsReachable() {
                guard await serverIsHarness() else {
                    let message = "服务已就绪但不是 DeepSeek Harness 页面，无法连接。请检查端口 \(configuration.port) 的占用情况。"
                    appendLog(message)
                    status = .failed(message)
                    stopOwnedProcess()
                    return
                }
                appendLog("DeepSeek Harness 已就绪：\(configuration.serverURL.absoluteString)")
                status = .running(managed: true)
                managedServerPID = HarnessProcessTerminator.listenerProcessID(forPort: configuration.port)
                homeRequestID += 1
                return
            }
            guard process.isRunning else { return }
            if attempt > 0, attempt % 120 == 0 {
                appendLog("仍在等待服务就绪（已等待 \(attempt / 2) 秒，首次运行可能需要下载依赖）…")
            }
            try? await Task.sleep(for: .milliseconds(500))
        }

        let message = "DeepSeek Harness 在 30 分钟内没有就绪。请查看日志后重试。"
        appendLog(message)
        status = .failed(message)
        stopOwnedProcess()
    }

    private func resolvedHarnessEnvironment() async -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        if let inherited = Self.inheritedEnvironmentAPIKey() {
            environment["DEEPSEEK_API_KEY"] = inherited
            return environment
        }

        if let loginShellAPIKey {
            environment["DEEPSEEK_API_KEY"] = loginShellAPIKey
            return environment
        }

        let candidate = await Task.detached(priority: .utility) {
            LoginShellEnvironment.value(
                for: "DEEPSEEK_API_KEY",
                environment: environment
            )
        }.value

        guard let candidate else { return environment }
        loginShellAPIKey = candidate
        environment["DEEPSEEK_API_KEY"] = candidate
        updateBalanceCredentialSource()
        refreshBalance()
        return environment
    }

    private func serverIsReachable() async -> Bool {
        var request = URLRequest(
            url: configuration.serverURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 1
        )
        request.httpMethod = "GET"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200..<400).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    /// Verifies the response on the configured port is the official Harness Web UI
    /// (its HTML embeds a `window.__DSH_BOOT__` bootstrap payload), so the app never
    /// silently attaches to an unrelated service.
    private func serverIsHarness() async -> Bool {
        var request = URLRequest(
            url: configuration.serverURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 2
        )
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<400).contains(httpResponse.statusCode)
            else {
                return false
            }
            return String(data: data, encoding: .utf8)?.contains("__DSH_BOOT__") == true
        } catch {
            return false
        }
    }

    private func stopOwnedProcess() {
        let ownedProcess = process
        let npxPID = ownedProcess?.processIdentifier
        let serverPID = managedServerPID
        self.process = nil
        self.managedServerPID = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil

        guard npxPID != nil || serverPID != nil else { return }

        if let npxPID {
            expectedTerminationProcessIDs.insert(npxPID)
        }
        HarnessProcessTerminator.terminate(wrapperPID: npxPID, serverPID: serverPID)
    }

    private func processDidTerminate(processID: Int32, exitCode: Int32) async {
        if expectedTerminationProcessIDs.remove(processID) != nil {
            return
        }

        guard process?.processIdentifier == processID else { return }
        process = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil

        let message = "DeepSeek Harness 启动器已退出（状态码 \(exitCode)）。"
        appendLog(message)

        // If npx died but the server process we launched still owns the port,
        // keep managing it through its PID instead of orphaning it.
        if let serverPID = managedServerPID, kill(serverPID, 0) == 0, await serverIsHarness() {
            if case .running = status {
                appendLog("服务进程仍在运行，已继续连接；退出应用时仍会停止该进程。")
                return
            }
        }

        managedServerPID = nil
        if case .running = status {
            status = .failed(message)
        } else if case .launching = status {
            status = .failed(message)
        }
    }

    private func appendLog(_ value: String) {
        let normalized = value.replacingOccurrences(of: "\r\n", with: "\n")
        if logText.isEmpty {
            logText = normalized.trimmingCharacters(in: .newlines)
        } else {
            logText += normalized.hasPrefix("\n") ? normalized : "\n\(normalized)"
        }

        if logText.count > 40_000 {
            logText = String(logText.suffix(40_000))
        }
    }

    private static func workspaceArgument() -> URL? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "--workspace"),
              arguments.indices.contains(flagIndex + 1)
        else {
            return nil
        }
        return URL(fileURLWithPath: arguments[flagIndex + 1], isDirectory: true)
    }

    private static func portArgument() -> Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "--port"),
              arguments.indices.contains(flagIndex + 1),
              let port = Int(arguments[flagIndex + 1]),
              (1...65_535).contains(port)
        else {
            return nil
        }
        return port
    }
}
