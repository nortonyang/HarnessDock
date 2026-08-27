import Foundation
import Testing
@testable import HarnessDockCore

struct ExecutableLocatorTests {
    @Test
    func locateFindsExecutableFromPath() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let executable = temporaryDirectory.appending(path: "sample-tool")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )

        let result = ExecutableLocator.locate(
            "sample-tool",
            environment: ["PATH": temporaryDirectory.path]
        )

        #expect(result?.standardizedFileURL == executable.standardizedFileURL)
    }

    @Test
    func locateRejectsNonExecutableFile() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let file = temporaryDirectory.appending(path: "sample-tool")
        try Data("not executable".utf8).write(to: file)

        let result = ExecutableLocator.locate(
            "sample-tool",
            environment: ["PATH": temporaryDirectory.path, "HOME": temporaryDirectory.path]
        )

        #expect(result == nil)
    }

    @Test
    func locateFindsNvmInstalledExecutableWithMinimalPath() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let home = temporaryDirectory.appending(path: "home", directoryHint: .isDirectory)
        let bin = home.appending(path: ".nvm/versions/node/v26.7.0/bin", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)

        let npx = bin.appending(path: "npx")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: npx)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: npx.path
        )

        let result = ExecutableLocator.locate(
            "npx",
            environment: ["PATH": "/usr/bin", "HOME": home.path]
        )

        #expect(result?.standardizedFileURL == npx.standardizedFileURL)
    }

    @Test
    func locatePrefersNewestNvmVersion() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let home = temporaryDirectory.appending(path: "home", directoryHint: .isDirectory)
        let oldBin = home.appending(path: ".nvm/versions/node/v22.0.0/bin", directoryHint: .isDirectory)
        let newBin = home.appending(path: ".nvm/versions/node/v26.7.0/bin", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: oldBin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newBin, withIntermediateDirectories: true)

        for (dir, name) in [(oldBin, "old-npx"), (newBin, "new-npx")] {
            let tool = dir.appending(path: name)
            try Data("#!/bin/sh\nexit 0\n".utf8).write(to: tool)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: tool.path
            )
        }

        let oldResult = ExecutableLocator.locate(
            "old-npx",
            environment: ["PATH": "/usr/bin", "HOME": home.path]
        )
        let newResult = ExecutableLocator.locate(
            "new-npx",
            environment: ["PATH": "/usr/bin", "HOME": home.path]
        )

        #expect(oldResult?.standardizedFileURL == oldBin.appending(path: "old-npx").standardizedFileURL)
        #expect(newResult?.standardizedFileURL == newBin.appending(path: "new-npx").standardizedFileURL)
    }

    @Test
    func pathEnvironmentPlacesExecutableDirectoryFirstWithoutDuplicatingIt() {
        let executable = URL(fileURLWithPath: "/opt/homebrew/bin/npx")

        let path = ExecutableLocator.pathEnvironment(
            for: executable,
            inheritedPath: "/usr/bin:/opt/homebrew/bin:/bin"
        )

        #expect(path == "/opt/homebrew/bin:/usr/bin:/bin")
    }
}
