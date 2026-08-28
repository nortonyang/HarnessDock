import Foundation
import Testing
@testable import HarnessDockCore

struct LoginShellEnvironmentTests {
    @Test
    func readsOnlyRequestedVariableFromLoginShell() throws {
        let fixture = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixture) }

        let shell = fixture.appending(path: "test-shell")
        try Data("#!/bin/sh\nprintf 'startup chatter\\n'\nexec /bin/sh -c \"$2\"\n".utf8).write(to: shell)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: shell.path
        )

        let value = LoginShellEnvironment.value(
            for: "TEST_API_KEY",
            environment: [
                "SHELL": shell.path,
                "TEST_API_KEY": "secret-from-shell",
                "UNRELATED_VALUE": "must-not-be-returned",
            ]
        )

        #expect(value == "secret-from-shell")
    }

    @Test
    func returnsNilForMissingValueOrUnsafeName() throws {
        let fixture = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixture) }

        let shell = fixture.appending(path: "test-shell")
        try Data("#!/bin/sh\nexec /bin/sh -c \"$2\"\n".utf8).write(to: shell)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: shell.path
        )

        #expect(LoginShellEnvironment.value(
            for: "MISSING_API_KEY",
            environment: ["SHELL": shell.path]
        ) == nil)
        #expect(LoginShellEnvironment.value(
            for: "VALUE; /usr/bin/false",
            environment: ["SHELL": shell.path]
        ) == nil)
    }
}
