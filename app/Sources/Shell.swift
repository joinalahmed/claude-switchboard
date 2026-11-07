import Foundation

struct CommandResult {
    var status: Int32
    var stdout: String
    var stderr: String
    var ok: Bool { status == 0 }
}

private final class DataBox: @unchecked Sendable {
    var data = Data()
}

enum Shell {
    static let home = NSHomeDirectory()

    /// The PATH your login shell has. Apps started from Finder get a bare PATH,
    /// which would hide `claude`, `gcloud` and friends.
    static let loginPath: String = {
        let fallback = [
            "/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin",
            Shell.home + "/.local/bin", Shell.home + "/.claude/local", Shell.home + "/bin",
            Shell.home + "/google-cloud-sdk/bin",
            "/usr/bin", "/bin", "/usr/sbin", "/sbin"
        ].joined(separator: ":")
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"
        let r = Shell.exec(shell, ["-l", "-i", "-c", "printf '__P__%s__P__' \"$PATH\""],
                           env: env, cwd: nil, timeout: 8)
        let parts = r.stdout.components(separatedBy: "__P__")
        if parts.count >= 3 && !parts[1].isEmpty {
            return parts[1] + ":" + fallback
        }
        return fallback
    }()

    static func run(_ exe: String, _ args: [String],
                    env extra: [String: String] = [:],
                    cwd: String? = nil,
                    timeout: TimeInterval = 60) -> CommandResult {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Shell.loginPath
        for (k, v) in extra { env[k] = v }
        return Shell.exec(exe, args, env: env, cwd: cwd, timeout: timeout)
    }

    static func runAsync(_ exe: String, _ args: [String],
                         env: [String: String] = [:],
                         cwd: String? = nil,
                         timeout: TimeInterval = 60) async -> CommandResult {
        await withCheckedContinuation { (cont: CheckedContinuation<CommandResult, Never>) in
            DispatchQueue.global().async {
                let r = Shell.run(exe, args, env: env, cwd: cwd, timeout: timeout)
                cont.resume(returning: r)
            }
        }
    }

    static func exec(_ exe: String, _ args: [String],
                     env: [String: String], cwd: String?,
                     timeout: TimeInterval) -> CommandResult {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        p.environment = env
        if let cwd = cwd { p.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        p.standardInput = FileHandle.nullDevice
        do {
            try p.run()
        } catch {
            return CommandResult(status: 127, stdout: "",
                                 stderr: "Couldn't run \(exe): \(error.localizedDescription)")
        }
        let outBox = DataBox()
        let errBox = DataBox()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            outBox.data = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global().async {
            errBox.data = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if p.isRunning { p.terminate() }
        }
        p.waitUntilExit()
        group.wait()
        return CommandResult(
            status: p.terminationStatus,
            stdout: String(data: outBox.data, encoding: .utf8) ?? "",
            stderr: String(data: errBox.data, encoding: .utf8) ?? ""
        )
    }

    /// Single-quote a string for safe use in a shell command line.
    static func quote(_ s: String) -> String {
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Split a command-line fragment into arguments, honoring quotes.
    static func splitArguments(_ s: String) -> [String] {
        var result: [String] = []
        var current = ""
        var hasCurrent = false
        var quoteChar: Character? = nil
        var escaped = false
        for c in s {
            if escaped {
                current.append(c)
                escaped = false
                hasCurrent = true
            } else if c == "\\" && quoteChar != "'" {
                escaped = true
            } else if let q = quoteChar {
                if c == q { quoteChar = nil } else { current.append(c) }
            } else if c == "'" || c == "\"" {
                quoteChar = c
                hasCurrent = true
            } else if c == " " || c == "\t" || c == "\n" {
                if hasCurrent {
                    result.append(current)
                    current = ""
                    hasCurrent = false
                }
            } else {
                current.append(c)
                hasCurrent = true
            }
        }
        if hasCurrent { result.append(current) }
        return result
    }
}
