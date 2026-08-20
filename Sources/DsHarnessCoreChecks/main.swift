import DsHarnessCore
import Foundation

var failures: [String] = []

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        failures.append(message)
    }
}

let configuration = HarnessConfiguration()
check(
    configuration.serverURL.absoluteString == "http://127.0.0.1:3080",
    "Default server URL must use the official loopback port"
)
check(
    configuration.npxArguments == [
        "--yes",
        "@deepseek-ai/dsh",
        "web",
        "--host",
        "127.0.0.1",
        "--port",
        "3080",
    ],
    "Default npx arguments must launch the official Web UI on the configured port"
)

let balanceJSON = Data(#"""
{
  "is_available": true,
  "balance_infos": [
    {
      "currency": "USD",
      "total_balance": "12.50",
      "granted_balance": "2.50",
      "topped_up_balance": "10.00"
    },
    {
      "currency": "CNY",
      "total_balance": "110.00",
      "granted_balance": "10.00",
      "topped_up_balance": "100.00"
    }
  ]
}
"""#.utf8)

do {
    let balance = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: balanceJSON)
    check(balance.isAvailable, "Balance response must decode is_available")
    check(balance.balanceInfos.count == 2, "Balance response must decode all currencies")
    check(balance.preferredInfo?.currency == "CNY", "CNY must be preferred for the compact summary")
    check(balance.preferredInfo?.displayTotal == "¥110.00", "CNY balance must use a readable symbol")
    check(
        DeepSeekBalanceClient.endpoint.absoluteString == "https://api.deepseek.com/user/balance",
        "Balance client must use the official read-only endpoint"
    )
} catch {
    failures.append("Balance decoding check failed: \(error)")
}

let temporaryDirectory = FileManager.default.temporaryDirectory
    .appending(path: UUID().uuidString, directoryHint: .isDirectory)

do {
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

    let located = ExecutableLocator.locate(
        "sample-tool",
        environment: ["PATH": temporaryDirectory.path]
    )
    check(
        located?.standardizedFileURL == executable.standardizedFileURL,
        "Executable locator must find an executable from PATH"
    )

    let plainFile = temporaryDirectory.appending(path: "plain-file")
    try Data("not executable".utf8).write(to: plainFile)
    let rejected = ExecutableLocator.locate(
        "plain-file",
        environment: ["PATH": temporaryDirectory.path, "HOME": temporaryDirectory.path]
    )
    check(rejected == nil, "Executable locator must reject a non-executable file")
} catch {
    failures.append("Temporary executable check failed: \(error)")
}

// A Finder-launched GUI app inherits a minimal PATH; nvm-installed Node must
// still be discoverable through the version manager directories.
do {
    let nvmHome = temporaryDirectory.appending(path: "nvm-home", directoryHint: .isDirectory)
    let nvmBin = nvmHome.appending(path: ".nvm/versions/node/v22.19.0/bin", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: nvmBin, withIntermediateDirectories: true)
    let nvmNpx = nvmBin.appending(path: "npx")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: nvmNpx)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: nvmNpx.path
    )

    let viaNvm = ExecutableLocator.locate(
        "npx",
        environment: ["PATH": "/usr/bin", "HOME": nvmHome.path]
    )
    check(
        viaNvm?.standardizedFileURL == nvmNpx.standardizedFileURL,
        "Executable locator must find npx installed via nvm when PATH is minimal"
    )
} catch {
    failures.append("nvm discovery check failed: \(error)")
}

let path = ExecutableLocator.pathEnvironment(
    for: URL(fileURLWithPath: "/opt/homebrew/bin/npx"),
    inheritedPath: "/usr/bin:/opt/homebrew/bin:/bin"
)
check(
    path == "/opt/homebrew/bin:/usr/bin:/bin",
    "Child PATH must put the runtime directory first without duplicating it"
)

// The terminator must kill the whole tree (wrapper + its child), mirroring
// how the app stops npx and the node server it spawned.
do {
    let childPIDFile = temporaryDirectory.appending(path: "child.pid")
    let treeScript = temporaryDirectory.appending(path: "tree.sh")
    try Data("#!/bin/sh\nsleep 300 &\necho $! > \(childPIDFile.path)\nwait\n".utf8)
        .write(to: treeScript)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: treeScript.path
    )

    let wrapper = Process()
    wrapper.executableURL = URL(fileURLWithPath: "/bin/sh")
    wrapper.arguments = [treeScript.path]
    wrapper.standardOutput = Pipe()
    wrapper.standardError = Pipe()
    try wrapper.run()
    let wrapperPID = wrapper.processIdentifier

    var childPID: Int32?
    for _ in 0..<100 {
        if let contents = try? String(contentsOf: childPIDFile, encoding: .utf8),
           let pid = Int32(contents.trimmingCharacters(in: .whitespacesAndNewlines))
        {
            childPID = pid
            break
        }
        Thread.sleep(forTimeInterval: 0.05)
    }
    check(childPID != nil, "Terminator test must observe a wrapper child process")

    HarnessProcessTerminator.terminate(wrapperPID: wrapperPID, serverPID: childPID)

    for _ in 0..<50 {
        let wrapperAlive = HarnessProcessTerminator.processExists(wrapperPID)
        let childAlive = childPID.map(HarnessProcessTerminator.processExists) ?? false
        if !wrapperAlive && !childAlive { break }
        Thread.sleep(forTimeInterval: 0.05)
    }
    check(
        !HarnessProcessTerminator.processExists(wrapperPID),
        "Terminator must stop the wrapper process"
    )
    check(
        !(childPID.map(HarnessProcessTerminator.processExists) ?? true),
        "Terminator must stop the wrapper's child process too"
    )
} catch {
    failures.append("Process tree termination check failed: \(error)")
}

// The listener lookup must return the PID of the process owning a port.
// Node is located through the same nvm-aware discovery the app uses.
if let nodeURL = ExecutableLocator.locate("node") {
    do {
        let port = 31_000 + Int.random(in: 0..<1_000)
        let server = Process()
        server.executableURL = nodeURL
        server.arguments = [
            "-e",
            "require('http').createServer((q, s) => s.end('ok')).listen(\(port), '127.0.0.1')",
        ]
        server.standardOutput = Pipe()
        server.standardError = Pipe()
        try server.run()

        var listenerPID: Int32?
        for _ in 0..<100 {
            guard server.isRunning else { break }
            listenerPID = HarnessProcessTerminator.listenerProcessID(forPort: port)
            if listenerPID != nil { break }
            Thread.sleep(forTimeInterval: 0.05)
        }
        if server.isRunning {
            check(
                listenerPID == server.processIdentifier,
                "Listener lookup must return the PID of the process owning the port"
            )
            server.terminate()
            server.waitUntilExit()
        } else {
            // Some CI/sandbox environments prohibit opening even loopback
            // listeners. The production lookup is still exercised anywhere
            // the fixture server can bind successfully.
            server.waitUntilExit()
            print("DsHarnessCoreChecks: skipped listener lookup (loopback bind unavailable)")
        }
    } catch {
        failures.append("Listener lookup check failed: \(error)")
    }
} else {
    failures.append("Listener lookup check requires a locatable node executable")
}

if failures.isEmpty {
    print("DsHarnessCoreChecks: all checks passed")
} else {
    for failure in failures {
        FileHandle.standardError.write(Data("FAIL: \(failure)\n".utf8))
    }
    exit(EXIT_FAILURE)
}
