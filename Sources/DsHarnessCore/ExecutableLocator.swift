import Foundation

/// Finds command-line tools when a GUI app has a minimal inherited `PATH`.
public enum ExecutableLocator {
    /// Returns the first executable matching `name` in PATH and common macOS tool directories.
    ///
    /// - Parameters:
    ///   - name: A binary name without a path component.
    ///   - environment: The environment used to derive PATH and the user's home directory.
    ///   - additionalDirectories: Directories searched after PATH and before standard locations.
    ///   - fileManager: The file manager used for executable checks.
    /// - Returns: An absolute file URL, or `nil` if the executable cannot be found.
    public static func locate(
        _ name: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        additionalDirectories: [URL] = [],
        fileManager: FileManager = .default
    ) -> URL? {
        guard !name.isEmpty, !name.contains("/") else { return nil }

        let pathDirectories = environment["PATH", default: ""]
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0), isDirectory: true) }

        var candidates = pathDirectories + additionalDirectories

        if let home = environment["HOME"], !home.isEmpty {
            let homeURL = URL(fileURLWithPath: home, isDirectory: true)
            candidates.append(homeURL.appending(path: ".volta/bin", directoryHint: .isDirectory))
            candidates.append(homeURL.appending(path: ".local/bin", directoryHint: .isDirectory))
            candidates.append(contentsOf: Self.versionedNodeDirectories(home: homeURL))
        }

        candidates.append(contentsOf: [
            URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/bin", isDirectory: true),
            URL(fileURLWithPath: "/bin", isDirectory: true),
        ])

        var visited = Set<String>()
        for directory in candidates {
            let normalizedDirectory = directory.standardizedFileURL
            guard visited.insert(normalizedDirectory.path).inserted else { continue }
            let candidate = normalizedDirectory.appending(path: name)
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    /// Builds a PATH that keeps the located executable's directory available to child tools.
    ///
    /// - Parameters:
    ///   - executableURL: The executable selected by ``locate(_:environment:additionalDirectories:fileManager:)``.
    ///   - inheritedPath: The parent process PATH.
    /// - Returns: A colon-separated PATH with the executable directory first.
    public static func pathEnvironment(
        for executableURL: URL,
        inheritedPath: String?
    ) -> String {
        let executableDirectory = executableURL.deletingLastPathComponent().path
        let existingDirectories = (inheritedPath ?? "")
            .split(separator: ":")
            .map(String.init)
            .filter { $0 != executableDirectory }
        return ([executableDirectory] + existingDirectories).joined(separator: ":")
    }

    /// Common Node version-manager directories that a Finder-launched GUI app will
    /// not see in its inherited `PATH`.
    ///
    /// Covers nvm (`~/.nvm/versions/node/*/bin` newest first, plus `~/.nvm/current/bin`),
    /// fnm (`~/.fnm/aliases/default/bin`), asdf (`~/.asdf/shims`) and mise
    /// (`~/.local/share/mise/shims`). Only directories that exist are returned.
    static func versionedNodeDirectories(home: URL) -> [URL] {
        let fileManager = FileManager.default
        var directories: [URL] = []

        let nvmVersions = home.appending(
            path: ".nvm/versions/node",
            directoryHint: .isDirectory
        )
        if let versionURLs = try? fileManager.contentsOfDirectory(
            at: nvmVersions,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            let sorted = versionURLs
                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
            directories.append(contentsOf: sorted.map {
                $0.appending(path: "bin", directoryHint: .isDirectory)
            })
        }

        directories.append(home.appending(path: ".nvm/current/bin", directoryHint: .isDirectory))
        directories.append(home.appending(path: ".fnm/aliases/default/bin", directoryHint: .isDirectory))
        directories.append(home.appending(path: ".asdf/shims", directoryHint: .isDirectory))
        directories.append(home.appending(path: ".local/share/mise/shims", directoryHint: .isDirectory))

        return directories.filter {
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: $0.path, isDirectory: &isDirectory)
                && isDirectory.boolValue
        }
    }
}
