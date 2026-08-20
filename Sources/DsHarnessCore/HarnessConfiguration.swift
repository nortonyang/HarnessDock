import Foundation

/// Stable launch values shared by the native shell and its tests.
public struct HarnessConfiguration: Equatable, Sendable {
    public let port: Int
    public let packageName: String

    /// Creates a loopback-only DeepSeek Harness configuration.
    ///
    /// - Parameters:
    ///   - port: The local HTTP port exposed by the Harness Web UI.
    ///   - packageName: The official npm package used to start Harness.
    public init(
        port: Int = 3_080,
        packageName: String = "@deepseek-ai/dsh"
    ) {
        precondition((1...65_535).contains(port), "Port must be between 1 and 65535")
        self.port = port
        self.packageName = packageName
    }

    /// The loopback URL displayed inside the app.
    public var serverURL: URL {
        // The host and validated integer port always produce a valid URL.
        URL(string: "http://127.0.0.1:\(port)")!
    }

    /// Arguments passed to `npx` to launch the official Web UI.
    ///
    /// The host and port are passed explicitly so the app always watches the
    /// port it configured, regardless of any user-level `~/.dsh` settings.
    public var npxArguments: [String] {
        [
            "--yes",
            packageName,
            "web",
            "--host",
            "127.0.0.1",
            "--port",
            String(port),
        ]
    }
}
