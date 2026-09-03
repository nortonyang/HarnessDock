import HarnessDockCore
import Foundation

var failures: [String] = []

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        failures.append(message)
    }
}

func isoDate(_ value: String) -> Date {
    guard let date = ISO8601DateFormatter().date(from: value) else {
        fatalError("Invalid test date: \(value)")
    }
    return date
}

let configuration = HarnessConfiguration()
check(
    configuration.serverURL.absoluteString == "http://127.0.0.1:3080",
    "Default server URL must use the official loopback port"
)
check(
    configuration.webArguments == [
        "web",
        "--host",
        "127.0.0.1",
        "--port",
        "3080",
    ],
    "Direct DSH arguments must launch the official Web UI on the configured port"
)
check(
    configuration.npxArguments == [
        "--yes",
        "--prefer-offline",
        "@deepseek-ai/dsh@0.1.0-rc.6",
        "web",
        "--host",
        "127.0.0.1",
        "--port",
        "3080",
    ],
    "Default npx arguments must launch the official Web UI on the configured port"
)
check(
    configuration.pinnedPackage?.path == "@deepseek-ai/dsh"
        && configuration.pinnedPackage?.version == "0.1.0-rc.6",
    "Default package must expose its pinned path and version"
)

let diagnosticsHome = URL(fileURLWithPath: "/Users/example", isDirectory: true)
let diagnostics = HarnessDiagnostics(
    appVersion: "0.1.0",
    buildNumber: "1",
    harnessPackage: configuration.packageName,
    operatingSystem: "macOS 15.0",
    architecture: "arm64",
    serviceStatus: "running",
    serverURL: configuration.serverURL.absoluteString,
    workspaceName: "Sample\nWorkspace",
    nodeExecutable: HarnessDiagnostics.redactedPath(
        URL(fileURLWithPath: "/Users/example/.nvm/current/bin/node"),
        homeDirectory: diagnosticsHome
    ),
    npxExecutable: "/opt/homebrew/bin/npx",
    cachedHarnessExecutable: nil
)
check(diagnostics.appVersionDisplay == "0.1.0 (1)", "Diagnostics must include the build number")
check(diagnostics.workspaceName == "Sample Workspace", "Diagnostics values must stay on one line")
check(
    diagnostics.nodeExecutable == "~/.nvm/current/bin/node",
    "Diagnostics must redact the current user's home directory"
)
check(
    !diagnostics.report.contains("/Users/example"),
    "Diagnostics report must not expose the user's home directory"
)
check(
    diagnostics.report.contains("Workspace: Sample Workspace")
        && diagnostics.report.contains("Cached dsh: Not found"),
    "Diagnostics report must describe the workspace name and missing runtime"
)

let minimalPetManifestJSON = Data(#"""
{
  "id": "sample-pet",
  "name": "Sample Pet",
  "spritesheet": "spritesheet.webp"
}
"""#.utf8)

do {
    let manifest = try JSONDecoder().decode(
        PetPluginManifest.self,
        from: minimalPetManifestJSON
    )
    try manifest.validate()
    check(manifest.frameWidth == 192, "Pet manifest must default to 192px frames")
    check(manifest.frameHeight == 208, "Pet manifest must default to 208px frames")
    check(manifest.columns == 8, "Pet manifest must default to 8 columns")
    check(manifest.rows == 9, "Pet manifest must default to 9 rows")
} catch {
    failures.append("Pet manifest check failed: \(error)")
}

let hatchedPetManifestJSON = Data(#"""
{
  "id": "deepwhale",
  "displayName": "DeepWhale",
  "spritesheetPath": "spritesheet.webp"
}
"""#.utf8)

do {
    let manifest = try JSONDecoder().decode(
        PetPluginManifest.self,
        from: hatchedPetManifestJSON
    )
    try manifest.validate()
    check(manifest.name == "DeepWhale", "Hatched pet displayName alias must decode")
    check(
        manifest.spritesheet == "spritesheet.webp",
        "Hatched pet spritesheetPath alias must decode"
    )
} catch {
    failures.append("Hatched pet manifest alias check failed: \(error)")
}

check(PetAnimationState.idle.layout.row == 0, "Idle pet animation must use row 0")
check(PetAnimationState.idle.layout.frameCount == 6, "Idle pet animation must use 6 frames")
check(PetAnimationState.running.layout.row == 7, "Running pet animation must use row 7")
check(PetAnimationState.failed.layout.frameCount == 8, "Failed pet animation must use 8 frames")
check(PetAnimationState.review.layout.row == 8, "Review pet animation must use row 8")
check(
    PetCommandActivity.running.animationState == .running,
    "Running command activity must use the running animation"
)
check(
    PetCommandActivity.succeeded.animationState == .review,
    "Successful command activity must use the review animation"
)
check(
    PetCommandActivity.failed.terminalResetDelayMilliseconds
        == PetAnimationState.failed.layout.cycleDurationMilliseconds,
    "Failed command activity must reset after one failed animation cycle"
)
check(
    PetCommandActivity(rawValue: "prompt contents") == nil,
    "Command activity must reject arbitrary bridge payloads"
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
    check(
        balance.info(preferredCurrency: "CNY")?.displayTotal == "¥110.00",
        "Chinese balance display must select CNY"
    )
    check(
        balance.info(preferredCurrency: "USD")?.displayTotal == "$12.50",
        "English balance display must select USD"
    )
    check(
        DeepSeekBalanceClient.endpoint.absoluteString == "https://api.deepseek.com/user/balance",
        "Balance client must use the official read-only endpoint"
    )
} catch {
    failures.append("Balance decoding check failed: \(error)")
}

check(
    DeepSeekAPIPricing.period(at: isoDate("2026-08-24T00:59:59Z")) == .offPeak,
    "Pricing must be off-peak before the first weekday interval"
)
check(
    DeepSeekAPIPricing.period(at: isoDate("2026-08-24T01:00:00Z")) == .peak,
    "Pricing must enter peak at 01:00 UTC on weekdays"
)
check(
    DeepSeekAPIPricing.period(at: isoDate("2026-08-24T04:00:00Z")) == .offPeak,
    "Pricing must return off-peak at 04:00 UTC"
)
check(
    DeepSeekAPIPricing.period(at: isoDate("2026-08-24T06:00:00Z")) == .peak,
    "Pricing must enter the second peak interval at 06:00 UTC"
)
check(
    DeepSeekAPIPricing.period(at: isoDate("2026-08-24T10:00:00Z")) == .offPeak,
    "Pricing must return off-peak at 10:00 UTC"
)
check(
    DeepSeekAPIPricing.period(at: isoDate("2026-08-22T07:00:00Z")) == .offPeak,
    "Pricing must remain off-peak during weekends"
)

let weekendTransition = DeepSeekAPIPricing.nextTransition(
    after: isoDate("2026-08-21T10:00:00Z")
)
check(
    weekendTransition == isoDate("2026-08-24T01:00:00Z"),
    "Friday after peak must transition next on Monday at 01:00 UTC"
)
let cnyPricing = DeepSeekAPIPricing.models(for: .cny)
let usdPricing = DeepSeekAPIPricing.models(for: .usd)
check(cnyPricing.count == 2, "CNY pricing must contain the supported V4 models")
check(usdPricing.count == 2, "USD pricing must contain the supported V4 models")
check(
    cnyPricing.first?.peak.cacheHitInput == "¥0.10",
    "V4 Flash peak cache-hit price must match the Chinese official table"
)
check(
    cnyPricing.first { $0.id == "deepseek-v4-pro" }?.peak.output == "¥27.00",
    "V4 Pro peak output price must match the Chinese official table"
)
check(
    usdPricing.first?.peak.cacheHitInput == "$0.014",
    "V4 Flash peak cache-hit price must match the English official table"
)
check(
    usdPricing.first { $0.id == "deepseek-v4-pro" }?.peak.output == "$3.96",
    "V4 Pro peak output price must match the English official table"
)
check(
    DeepSeekAPIPricing.sourceURL(for: .usd).absoluteString
        == "https://api-docs.deepseek.com/quick_start/pricing/",
    "USD pricing must open the official English source"
)

let legacyPetProfile = Data(#"""
{
  "dependencies": {
    "@dsharness/pet": "link:/Applications/DsHarness.app/Contents/Resources/Plugins/dsh-pet"
  },
  "dsh": {
    "profile": {
      "bundles": ["@deepseek-ai/dsh-base", "@dsharness/pet"]
    }
  }
}
"""#.utf8)
let currentPetProfile = Data(#"""
{
  "dependencies": {
    "@harnessdock/pet": "link:/Applications/HarnessDock.app/Contents/Resources/Plugins/harnessdock-pet"
  },
  "dsh": {
    "profile": {
      "bundles": ["@deepseek-ai/dsh-base", "@harnessdock/pet"]
    }
  }
}
"""#.utf8)
check(
    HarnessPetProfileMigration.state(from: legacyPetProfile)?.needsMigration == true,
    "Legacy @dsharness/pet profiles must require migration"
)
check(
    HarnessPetProfileMigration.state(from: currentPetProfile)?.canBootCurrentPet == true,
    "Current @harnessdock/pet profiles must remain untouched"
)
check(
    HarnessPetProfileMigration.state(from: currentPetProfile)?.needsBundledRelink(
        to: URL(
            fileURLWithPath: "/Applications/New/HarnessDock.app/Contents/Resources/Plugins/harnessdock-pet"
        )
    ) == true,
    "Bundled pet links must follow the current HarnessDock app location"
)
check(
    HarnessPetProfileMigration.manifestURL(
        environment: ["DSH_HOME": "./custom-dsh"],
        homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true),
        currentDirectory: URL(fileURLWithPath: "/tmp/workspace", isDirectory: true)
    ).path == "/tmp/workspace/custom-dsh/profiles/web/package.json",
    "Relative DSH_HOME must resolve from the Harness working directory"
)

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

    let npmGlobalBin = temporaryDirectory.appending(
        path: "home/.npm-global/bin",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: npmGlobalBin, withIntermediateDirectories: true)
    let pnpm = npmGlobalBin.appending(path: "pnpm")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: pnpm)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: pnpm.path
    )
    check(
        ExecutableLocator.locate(
            "pnpm",
            environment: [
                "PATH": "/usr/bin",
                "HOME": temporaryDirectory.appending(path: "home").path,
            ]
        )?.standardizedFileURL == pnpm.standardizedFileURL,
        "Finder launches must find pnpm in ~/.npm-global/bin"
    )
} catch {
    failures.append("Temporary executable check failed: \(error)")
}

// Finder-launched apps need one exported credential from the user's login
// shell without importing or exposing the rest of that shell environment.
do {
    let fixture = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: fixture) }
    try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)

    let shell = fixture.appending(path: "test-shell")
    try Data(
        "#!/bin/sh\nprintf 'startup chatter\\n'\nexec /bin/sh -c \"$2\"\n".utf8
    ).write(to: shell)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: shell.path
    )

    let resolved = LoginShellEnvironment.value(
        for: "TEST_API_KEY",
        environment: [
            "SHELL": shell.path,
            "TEST_API_KEY": "secret-from-shell",
            "UNRELATED_VALUE": "must-not-be-returned",
        ]
    )
    check(resolved == "secret-from-shell", "Login shell resolver must isolate one variable")
    check(
        LoginShellEnvironment.value(
            for: "VALUE; /usr/bin/false",
            environment: ["SHELL": shell.path]
        ) == nil,
        "Login shell resolver must reject unsafe variable names"
    )
} catch {
    failures.append("Login shell environment check failed: \(error)")
}

// A Finder launch must honor the user's npm cache from ~/.npmrc and only
// select a runtime whose package.json matches the pinned version.
do {
    let fixture = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: fixture) }

    let home = fixture.appending(path: "home", directoryHint: .isDirectory)
    let cache = fixture.appending(path: "npm-cache", directoryHint: .isDirectory)
    let nodeModules = cache.appending(
        path: "_npx/cache-key/node_modules",
        directoryHint: .isDirectory
    )
    let packageDirectory = nodeModules.appending(
        path: "@deepseek-ai/dsh",
        directoryHint: .isDirectory
    )
    let binaryDirectory = nodeModules.appending(path: ".bin", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
    try Data("cache=\(cache.path)\n".utf8).write(to: home.appending(path: ".npmrc"))
    try Data(#"{"version":"0.1.0-rc.6"}"#.utf8).write(
        to: packageDirectory.appending(path: "package.json")
    )
    let cachedBinary = binaryDirectory.appending(path: "dsh")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: cachedBinary)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: cachedBinary.path
    )

    let located = ExecutableLocator.locateNpxCachedPackageBinary(
        "dsh",
        packagePath: "@deepseek-ai/dsh",
        version: "0.1.0-rc.6",
        environment: ["HOME": home.path]
    )
    check(
        located?.standardizedFileURL == cachedBinary.standardizedFileURL,
        "Cached npm runtime locator must honor ~/.npmrc and match the pinned package"
    )
    let wrongVersion = ExecutableLocator.locateNpxCachedPackageBinary(
        "dsh",
        packagePath: "@deepseek-ai/dsh",
        version: "0.1.0-rc.5",
        environment: ["HOME": home.path]
    )
    check(wrongVersion == nil, "Cached npm runtime locator must reject another version")
} catch {
    failures.append("Cached npm runtime check failed: \(error)")
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
            print("HarnessDockCoreChecks: skipped listener lookup (loopback bind unavailable)")
        }
    } catch {
        failures.append("Listener lookup check failed: \(error)")
    }
} else {
    failures.append("Listener lookup check requires a locatable node executable")
}

if failures.isEmpty {
    print("HarnessDockCoreChecks: all checks passed")
} else {
    for failure in failures {
        FileHandle.standardError.write(Data("FAIL: \(failure)\n".utf8))
    }
    exit(EXIT_FAILURE)
}
