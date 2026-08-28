import Foundation

/// Reads one exported variable from the user's interactive login shell.
///
/// Finder-launched macOS apps do not inherit variables exported by shell startup
/// files. This resolver intentionally requests one named value instead of importing
/// the shell's complete environment.
public enum LoginShellEnvironment {
    public static func value(
        for variable: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> String? {
        guard isValidVariableName(variable) else { return nil }

        let shellPath = environment["SHELL"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedShellPath = shellPath.flatMap { $0.isEmpty ? nil : $0 } ?? "/bin/zsh"
        guard fileManager.isExecutableFile(atPath: resolvedShellPath) else { return nil }

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: resolvedShellPath)
        process.arguments = [
            "-ilc",
            "printf '\\036%s\\037' \"$(/usr/bin/printenv \(variable))\"",
        ]
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let start = data.firstIndex(of: 0x1e),
                  let end = data[data.index(after: start)...].firstIndex(of: 0x1f),
                  let value = String(data: data[data.index(after: start)..<end], encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else { return nil }
            return value
        } catch {
            return nil
        }
    }

    private static func isValidVariableName(_ value: String) -> Bool {
        value.range(
            of: #"^[A-Za-z_][A-Za-z0-9_]*$"#,
            options: .regularExpression
        ) != nil
    }
}
