import Foundation

/// A privacy-conscious snapshot that can be shared when troubleshooting HarnessDock.
public struct HarnessDiagnostics: Equatable, Sendable {
    public let appVersion: String
    public let buildNumber: String?
    public let harnessPackage: String
    public let operatingSystem: String
    public let architecture: String
    public let serviceStatus: String
    public let serverURL: String
    public let workspaceName: String?
    public let nodeExecutable: String?
    public let npxExecutable: String?
    public let cachedHarnessExecutable: String?

    public init(
        appVersion: String,
        buildNumber: String?,
        harnessPackage: String,
        operatingSystem: String,
        architecture: String,
        serviceStatus: String,
        serverURL: String,
        workspaceName: String?,
        nodeExecutable: String?,
        npxExecutable: String?,
        cachedHarnessExecutable: String?
    ) {
        self.appVersion = Self.singleLine(appVersion)
        self.buildNumber = buildNumber.map(Self.singleLine)
        self.harnessPackage = Self.singleLine(harnessPackage)
        self.operatingSystem = Self.singleLine(operatingSystem)
        self.architecture = Self.singleLine(architecture)
        self.serviceStatus = Self.singleLine(serviceStatus)
        self.serverURL = Self.singleLine(serverURL)
        self.workspaceName = workspaceName.map(Self.singleLine)
        self.nodeExecutable = nodeExecutable.map(Self.singleLine)
        self.npxExecutable = npxExecutable.map(Self.singleLine)
        self.cachedHarnessExecutable = cachedHarnessExecutable.map(Self.singleLine)
    }

    public var appVersionDisplay: String {
        guard let buildNumber, !buildNumber.isEmpty else { return appVersion }
        return "\(appVersion) (\(buildNumber))"
    }

    public var systemDisplay: String {
        "\(operatingSystem) · \(architecture)"
    }

    /// A stable report that deliberately excludes credentials, cookies, conversations,
    /// logs, and the full workspace path.
    public var report: String {
        [
            "HarnessDock diagnostics",
            "App: \(appVersionDisplay)",
            "Harness runtime: \(harnessPackage)",
            "System: \(systemDisplay)",
            "Service: \(serviceStatus)",
            "Server: \(serverURL)",
            "Workspace: \(workspaceName ?? "Not selected")",
            "Node: \(nodeExecutable ?? "Not found")",
            "npx: \(npxExecutable ?? "Not found")",
            "Cached dsh: \(cachedHarnessExecutable ?? "Not found")",
            "Privacy: API keys, cookies, conversations, logs, and full workspace paths are excluded.",
        ].joined(separator: "\n")
    }

    /// Replaces the current user's home directory with `~` before a path is displayed
    /// or copied. Other absolute paths are retained because they help identify whether
    /// a tool came from Homebrew, the system, or another runtime manager.
    public static func redactedPath(_ url: URL?, homeDirectory: URL) -> String? {
        guard let path = url?.standardizedFileURL.path, !path.isEmpty else { return nil }
        let homePath = homeDirectory.standardizedFileURL.path
        if path == homePath {
            return "~"
        }
        if path.hasPrefix(homePath + "/") {
            return "~" + path.dropFirst(homePath.count)
        }
        return path
    }

    private static func singleLine(_ value: String) -> String {
        value
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
