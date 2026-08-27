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

    /// Finds an executable inside an already-installed npm `_npx` package cache.
    ///
    /// The package version is verified from its `package.json`, so a Finder-launched
    /// app can reuse the exact pinned runtime without asking npm to resolve metadata.
    public static func locateNpxCachedPackageBinary(
        _ binaryName: String,
        packagePath: String,
        version: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL? {
        guard !binaryName.isEmpty,
              !binaryName.contains("/"),
              !packagePath.isEmpty,
              !packagePath.contains(".."),
              !version.isEmpty
        else { return nil }

        var matches: [(binary: URL, modified: Date)] = []

        for cacheRoot in npmCacheRoots(environment: environment, fileManager: fileManager) {
            let npxRoot = cacheRoot.appending(path: "_npx", directoryHint: .isDirectory)
            guard let installations = try? fileManager.contentsOfDirectory(
                at: npxRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for installation in installations {
                let nodeModules = installation.appending(path: "node_modules", directoryHint: .isDirectory)
                let packageDirectory = packagePath
                    .split(separator: "/", omittingEmptySubsequences: true)
                    .reduce(nodeModules) { partial, component in
                        partial.appending(path: String(component), directoryHint: .isDirectory)
                    }
                let packageJSON = packageDirectory.appending(path: "package.json")

                guard let data = try? Data(contentsOf: packageJSON),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      object["version"] as? String == version
                else { continue }

                let binary = nodeModules
                    .appending(path: ".bin", directoryHint: .isDirectory)
                    .appending(path: binaryName)
                guard fileManager.isExecutableFile(atPath: binary.path) else { continue }

                let modified = (try? packageJSON.resourceValues(
                    forKeys: [.contentModificationDateKey]
                ).contentModificationDate) ?? .distantPast
                matches.append((binary.standardizedFileURL, modified))
            }
        }

        return matches.max {
            if $0.modified == $1.modified {
                return $0.binary.path < $1.binary.path
            }
            return $0.modified < $1.modified
        }?.binary
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

    private static func npmCacheRoots(
        environment: [String: String],
        fileManager: FileManager
    ) -> [URL] {
        var paths: [String] = []
        if let configured = environment["npm_config_cache"], !configured.isEmpty {
            paths.append(configured)
        }
        if let configured = environment["NPM_CONFIG_CACHE"], !configured.isEmpty {
            paths.append(configured)
        }

        if let homePath = environment["HOME"], !homePath.isEmpty {
            let home = URL(fileURLWithPath: homePath, isDirectory: true)
            let npmrc = home.appending(path: ".npmrc")
            if let contents = try? String(contentsOf: npmrc, encoding: .utf8),
               let configured = npmCachePath(from: contents, homePath: homePath) {
                paths.append(configured)
            }
            paths.append(home.appending(path: ".npm", directoryHint: .isDirectory).path)
        }

        var visited = Set<String>()
        return paths.compactMap { rawPath in
            let url = URL(fileURLWithPath: rawPath, isDirectory: true).standardizedFileURL
            guard visited.insert(url.path).inserted else { return nil }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else { return nil }
            return url
        }
    }

    private static func npmCachePath(from contents: String, homePath: String) -> String? {
        for rawLine in contents.split(whereSeparator: \Character.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix(";") else { continue }
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "cache"
            else { continue }

            var value = parts[1].trimmingCharacters(in: .whitespaces)
            if value.count >= 2,
               (value.hasPrefix("\"") && value.hasSuffix("\"")
                || value.hasPrefix("'") && value.hasSuffix("'")) {
                value.removeFirst()
                value.removeLast()
            }
            if value == "~" { return homePath }
            if value.hasPrefix("~/") {
                return URL(fileURLWithPath: homePath, isDirectory: true)
                    .appending(path: String(value.dropFirst(2)), directoryHint: .isDirectory)
                    .path
            }
            return value.isEmpty ? nil : value
        }
        return nil
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
