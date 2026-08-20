import AppKit
import Combine
import Darwin
import DsHarnessCore
import Foundation

enum HarnessStatus: Equatable {
    case idle
    case locatingRuntime
    case launching
    case running(managed: Bool)
    case failed(String)
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
    struct Entry: Codable, Equatable {
        let currency: String
        let total: String
        let granted: String
        let toppedUp: String
    }

    let title: String
    let subtitle: String
    let tone: String
    let state: String
    let error: String?
    let updatedLabel: String?
    let entries: [Entry]
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var workspaceURL: URL?
    @Published private(set) var status: HarnessStatus = .idle
    @Published private(set) var logText = ""
    @Published var webViewIsLoading = false
    @Published var webViewError: String?
    @Published var showLogs = false
    @Published var showBalanceSettings = false
    @Published private(set) var homeRequestID = 0
    @Published private(set) var reloadRequestID = 0
    @Published private(set) var balanceState: BalanceState = .notConfigured
    @Published private(set) var balanceCredentialSource: BalanceCredentialSource = .none
    @Published private(set) var balanceCredentialError: String?

    let configuration: HarnessConfiguration

    private let workspaceDefaultsKey = "lastWorkspacePath"
    private let balanceClient = DeepSeekBalanceClient()
    private let balanceKeychain = BalanceKeychain()
    private var process: Process?
    private var outputPipe: Pipe?
    private var startupTask: Task<Void, Never>?
    private var balanceTask: Task<Void, Never>?
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
        updateBalanceCredentialSource()
    }

    var isManagedServer: Bool {
        if case let .running(managed) = status {
            return managed
        }
        return false
    }

    var hasEnvironmentBalanceAPIKey: Bool {
        Self.environmentBalanceAPIKey() != nil
    }

    var balanceWebPresentation: BalanceWebPresentation {
        switch balanceState {
        case .notConfigured:
            return BalanceWebPresentation(
                title: "配置 API 余额",
                subtitle: "安全存储在 macOS 钥匙串",
                tone: "neutral",
                state: "notConfigured",
                error: nil,
                updatedLabel: nil,
                entries: []
            )
        case .loading:
            return BalanceWebPresentation(
                title: "正在查询余额",
                subtitle: "DeepSeek 开放平台",
                tone: "loading",
                state: "loading",
                error: nil,
                updatedLabel: nil,
                entries: []
            )
        case let .failed(message):
            return BalanceWebPresentation(
                title: "余额查询失败",
                subtitle: "点击查看详情",
                tone: "error",
                state: "failed",
                error: message,
                updatedLabel: nil,
                entries: []
            )
        case let .loaded(response, refreshedAt):
            return BalanceWebPresentation(
                title: response.preferredInfo?.displayTotal ?? "余额已同步",
                subtitle: response.isAvailable ? "DeepSeek API 余额 · 可用" : "DeepSeek API 余额 · 暂不可用",
                tone: response.isAvailable ? "success" : "warning",
                state: "loaded",
                error: nil,
                updatedLabel: "更新于 \(refreshedAt.formatted(date: .omitted, time: .shortened))",
                entries: response.balanceInfos.map {
                    BalanceWebPresentation.Entry(
                        currency: $0.currency.uppercased(),
                        total: $0.displayTotal,
                        granted: $0.displayGranted,
                        toppedUp: $0.displayToppedUp
                    )
                }
            )
        }
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
        panel.title = "选择 DeepSeek Harness 工作区"
        panel.message = "Harness 的文件和命令权限将以这个项目目录为起点。"
        panel.prompt = "打开项目"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = workspaceURL

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        setWorkspace(selectedURL)
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
                self?.balanceState = .failed(Self.balanceFailureMessage(for: error))
            }
        }
    }

    func saveBalanceAPIKey(_ value: String) {
        let credential = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !credential.isEmpty else {
            balanceCredentialError = "请输入 DeepSeek API Key。"
            return
        }

        do {
            try balanceKeychain.save(credential)
            balanceCredentialSource = .keychain
            balanceCredentialError = nil
            showBalanceSettings = false
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
            showBalanceSettings = true
        case "refresh":
            refreshBalance()
        default:
            break
        }
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

        balanceCredentialSource = Self.environmentBalanceAPIKey() == nil ? .none : .environment
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

        if let credential = Self.environmentBalanceAPIKey() {
            balanceCredentialSource = .environment
            return credential
        }

        balanceCredentialSource = .none
        return nil
    }

    private static func environmentBalanceAPIKey() -> String? {
        guard let credential = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !credential.isEmpty
        else {
            return nil
        }
        return credential
    }

    private static func balanceFailureMessage(for error: Error) -> String {
        if let balanceError = error as? DeepSeekBalanceError {
            return balanceError.localizedDescription
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "当前无法连接网络。"
            case .timedOut:
                return "查询余额超时，请重试。"
            default:
                return "暂时无法连接余额服务。"
            }
        }
        return "暂时无法查询余额。"
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

        appendLog("工作区：\(workspace.path)")
        appendLog("运行环境：\(npxURL.path)")
        appendLog("正在启动：npx \(configuration.npxArguments.joined(separator: " "))")

        let process = Process()
        let pipe = Pipe()
        process.executableURL = npxURL
        process.arguments = configuration.npxArguments
        process.currentDirectoryURL = workspace
        process.standardOutput = pipe
        process.standardError = pipe

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = ExecutableLocator.pathEnvironment(
            for: npxURL,
            inheritedPath: environment["PATH"]
        )
        // This variable is accepted only as a credential source for the native
        // balance client. Do not expose it to npm, Harness, or Harness plugins.
        environment.removeValue(forKey: "DEEPSEEK_API_KEY")
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

        // First run can take minutes while npx downloads the official package,
        // so allow a generous window and report progress instead of giving up.
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
