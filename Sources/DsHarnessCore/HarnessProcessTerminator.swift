import Foundation

/// Stops the process tree that the desktop app starts for the Harness server.
///
/// `npx` only wraps the real server: `npx --yes @deepseek-ai/dsh web` spawns a
/// `node` child that owns the port. Terminating only npx can orphan that child,
/// which then keeps the port (and the old workspace) alive after the app quits.
/// This terminator signals the wrapper, its direct children, and the tracked
/// server PID, then escalates to SIGKILL for anything that survives the grace
/// period.
public enum HarnessProcessTerminator {
    /// Terminates the wrapper process, its whole descendant tree, and the server PID.
    ///
    /// - Parameters:
    ///   - wrapperPID: PID of the `npx` (or equivalent) wrapper process.
    ///   - serverPID: PID of the process directly serving the Harness port.
    ///   - grace: How long to wait for graceful termination before SIGKILL.
    public static func terminate(
        wrapperPID: Int32?,
        serverPID: Int32?,
        grace: TimeInterval = 1.5
    ) {
        guard wrapperPID != nil || serverPID != nil else { return }

        // npx can be several levels deep (npx -> npm -> worker node processes,
        // then the server), so enumerate the whole descendant tree, not just
        // direct children.
        var targets = Set<Int32>()
        if let wrapperPID {
            targets.insert(wrapperPID)
            targets.formUnion(descendantPIDs(of: wrapperPID))
        }
        if let serverPID, serverPID != wrapperPID {
            targets.insert(serverPID)
        }

        for target in targets {
            kill(target, SIGTERM)
        }

        let deadline = Date().addingTimeInterval(grace)
        while Date() < deadline {
            if targets.allSatisfy({ !processExists($0) }) { break }
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Catch anything spawned after the first enumeration.
        if let wrapperPID, processExists(wrapperPID) {
            targets.formUnion(descendantPIDs(of: wrapperPID))
        }
        for target in targets where processExists(target) {
            kill(target, SIGKILL)
        }
    }

    /// All running descendants of `rootPID`, including grandchildren and deeper.
    static func descendantPIDs(of rootPID: Int32) -> [Int32] {
        var result: [Int32] = []
        var queue: [Int32] = [rootPID]
        var visited = Set<Int32>()

        while let current = queue.popLast() {
            guard visited.insert(current).inserted else { continue }
            if current != rootPID { result.append(current) }
            queue.append(contentsOf: directChildren(of: current))
        }
        return result
    }

    /// Direct children of `parentPID`, or an empty array when pgrep is unavailable.
    static func directChildren(of parentPID: Int32) -> [Int32] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-P", String(parentPID)]
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return []
        }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Sends `signal` to every running direct child of `parentPID` (best effort
    /// fallback when pgrep cannot enumerate descendants).
    static func signalChildren(of parentPID: Int32, signal: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        process.arguments = [
            signal == SIGKILL ? "-KILL" : "-TERM",
            "-P",
            String(parentPID),
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }

    /// Returns the PID of the process currently listening on `port`, if any.
    public static func listenerProcessID(forPort port: Int) -> Int32? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-tiTCP:\(port)", "-sTCP:LISTEN"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let line = String(data: data, encoding: .utf8)?
            .split(whereSeparator: \.isNewline).first,
            let pid = Int32(line.trimmingCharacters(in: .whitespaces))
        else {
            return nil
        }
        return pid
    }

    /// True when a process with the given PID exists (zombies included).
    public static func processExists(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0
    }
}
