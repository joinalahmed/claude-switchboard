import SwiftUI
import AppKit

private struct Snapshot {
    var providers: [Provider]
    var templates: [Template]
}

@MainActor
final class Store: ObservableObject {
    let dir: String
    let ccp: String

    @Published var providers: [Provider] = []
    @Published var templates: [Template] = []
    @Published var selection: SidebarItem? = nil
    @Published var showAdd = false
    @Published var loaded = false
    @Published var toast: String? = nil
    @Published var testResults: [String: TestResult] = [:]
    @Published var testing: Set<String> = []

    // Terminal integration
    @Published var hook: HookStatus? = nil
    @Published var overrides: [OverrideEntry] = []
    @Published var terminalBusy = false

    // Usage
    @Published var usage: UsageReport? = nil
    @Published var usageLoading = false
    @Published var usageRange: UsageRange {
        didSet { UserDefaults.standard.set(usageRange.rawValue, forKey: "usageRange") }
    }

    @Published var folder: String {
        didSet { UserDefaults.standard.set(folder, forKey: "folder") }
    }
    @Published var recents: [String] {
        didSet { UserDefaults.standard.set(recents, forKey: "recents") }
    }
    @Published var continueSession: Bool {
        didSet { UserDefaults.standard.set(continueSession, forKey: "continue") }
    }
    @Published var extraArgs: String {
        didSet { UserDefaults.standard.set(extraArgs, forKey: "extraArgs") }
    }
    @Published var terminal: TerminalApp {
        didSet { UserDefaults.standard.set(terminal.rawValue, forKey: "terminal") }
    }

    private var toastTask: Task<Void, Never>? = nil

    init() {
        let env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        dir = env["CLAUDE_PROVIDERS_DIR"] ?? (home + "/.claude-providers")
        ccp = env["CCP_BIN"] ?? (home + "/bin/ccp")
        ToolInstaller.installIfNeeded(ccpPath: ccp, providersDir: dir)
        let d = UserDefaults.standard
        folder = d.string(forKey: "folder") ?? home
        recents = d.stringArray(forKey: "recents") ?? []
        continueSession = d.bool(forKey: "continue")
        extraArgs = d.string(forKey: "extraArgs") ?? ""
        terminal = TerminalApp(rawValue: d.string(forKey: "terminal") ?? "") ?? .terminal
        usageRange = UsageRange(rawValue: d.string(forKey: "usageRange") ?? "") ?? .month
        Task.detached { _ = Shell.loginPath }
        Task {
            await self.refresh()
            await self.refreshTerminal()
            await self.loadUsage()
        }
    }

    // MARK: - Loading

    func refresh() async {
        let d = dir
        let snap: Snapshot = await withCheckedContinuation { (cont: CheckedContinuation<Snapshot, Never>) in
            DispatchQueue.global().async {
                let def = Catalog.defaultName(dir: d)
                let providers = Catalog.loadProviders(dir: d, defaultName: def)
                let templates = Catalog.loadTemplates(dir: d)
                cont.resume(returning: Snapshot(providers: providers, templates: templates))
            }
        }
        providers = snap.providers
        templates = snap.templates.sorted { a, b in
            if a.name == "custom" { return false }
            if b.name == "custom" { return true }
            return a.name < b.name
        }
        loaded = true
        switch selection {
        case .none:
            selection = firstSelection()
        case .some(.provider(let n)):
            if !providers.contains(where: { $0.name == n }) { selection = firstSelection() }
        default:
            break
        }
    }

    private func firstSelection() -> SidebarItem? {
        if let p = providers.first(where: { $0.isDefault }) { return .provider(p.name) }
        if let p = providers.first { return .provider(p.name) }
        return nil
    }

    func provider(named name: String) -> Provider? {
        return providers.first(where: { $0.name == name })
    }

    // MARK: - Feedback

    func show(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { self.toast = nil }
        }
    }

    func ccpRun(_ args: [String], env: [String: String] = [:], timeout: TimeInterval = 60) async -> CommandResult {
        var e = env
        e["CLAUDE_PROVIDERS_DIR"] = dir
        return await Shell.runAsync(ccp, args, env: e, timeout: timeout)
    }

    /// The last few meaningful lines of a failed command, without ccp's own prefix.
    static func summarize(_ r: CommandResult) -> String {
        let text = r.stderr.isEmpty ? r.stdout : r.stderr
        let lines = text.split(separator: "\n").map { String($0) }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let cleaned = lines.suffix(3).map { line -> String in
            var l = line
            if l.hasPrefix("ccp: ") { l = String(l.dropFirst(5)) }
            return l
        }
        return cleaned.isEmpty ? "The command failed (exit \(r.status))." : cleaned.joined(separator: "\n")
    }

    // MARK: - Changing providers (all through ccp)

    /// Creates a provider, or replaces one when `replace` is true. Returns an error message on failure.
    func saveProvider(name: String, template: String, values: [String: String],
                      secrets: [String: String], makeDefault: Bool, replace: Bool) async -> String? {
        var args = ["add", name, "-t", template, "--yes"]
        if replace { args += ["--force", "--keep"] }
        if makeDefault { args.append("--default") }
        for key in values.keys.sorted() {
            args += ["--set", "\(key)=\(values[key] ?? "")"]
        }
        var env: [String: String] = [:]
        for (k, v) in secrets where !v.isEmpty { env["CCP_SECRET_\(k)"] = v }
        let r = await ccpRun(args, env: env)
        await refresh()
        return r.ok ? nil : Store.summarize(r)
    }

    func setDefault(_ name: String) async {
        let r = await ccpRun(["default", name])
        await refresh()
        if !r.ok {
            show(Store.summarize(r))
        } else if hook?.installed == true {
            show("\(name) is now the default. New Terminal windows will use it for claude.")
        } else {
            show("\(name) is now the default")
        }
    }

    func delete(_ name: String) async {
        let r = await ccpRun(["remove", name, "--yes"])
        await refresh()
        show(r.ok ? "Deleted \(name)" : Store.summarize(r))
    }

    func saveRaw(_ name: String, text: String) async -> String? {
        let tmp = NSTemporaryDirectory() + "ccp-check-\(UUID().uuidString).sh"
        do { try text.write(toFile: tmp, atomically: true, encoding: .utf8) } catch {
            return "Couldn't write a temporary copy: \(error.localizedDescription)"
        }
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        let check = await Shell.runAsync("/bin/bash", ["-n", tmp])
        if !check.ok {
            let msg = check.stderr.replacingOccurrences(of: tmp, with: "file")
            return "The file has a syntax error:\n" + msg.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let path = dir + "/" + name + ".env"
        do {
            try text.write(toFile: path, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        } catch {
            return "Couldn't save: \(error.localizedDescription)"
        }
        await refresh()
        return nil
    }

    // MARK: - Checking providers

    func test(_ name: String) async {
        testing.insert(name)
        let start = Date()
        let r = await ccpRun(["test", name], timeout: 150)
        testing.remove(name)
        var lines: [String] = []
        for part in (r.stdout + "\n" + r.stderr).split(separator: "\n") {
            let l = String(part).trimmingCharacters(in: .whitespaces)
            if l.isEmpty || l.hasPrefix("ccp: testing") { continue }
            lines.append(l.hasPrefix("ccp: ") ? String(l.dropFirst(5)) : l)
        }
        testResults[name] = TestResult(ok: r.ok,
                                       message: lines.joined(separator: "\n"),
                                       seconds: Date().timeIntervalSince(start),
                                       date: Date())
    }

    func resolve(_ name: String) async -> ResolvedSettings {
        let r = await ccpRun(["show", name], timeout: 30)
        var summary = name
        var vars: [Variable] = []
        var warnings: [String] = []
        for part in r.stderr.split(separator: "\n") {
            let l = String(part)
            if l.hasPrefix("ccp: warning: ") { warnings.append(String(l.dropFirst(14))) }
            else if !r.ok && !l.isEmpty { warnings.append(l.hasPrefix("ccp: ") ? String(l.dropFirst(5)) : l) }
        }
        var first = true
        for part in r.stdout.split(separator: "\n") {
            let l = String(part)
            if first && l.hasPrefix("ccp: ") {
                summary = String(l.dropFirst(5))
                first = false
                continue
            }
            first = false
            if let eq = l.firstIndex(of: "=") {
                vars.append(Variable(name: String(l[l.startIndex..<eq]), value: String(l[l.index(after: eq)...])))
            }
        }
        return ResolvedSettings(summary: summary, variables: vars, warnings: warnings)
    }

    func doctor() async -> [DoctorSection] {
        let r = await ccpRun(["doctor"], timeout: 60)
        var sections: [DoctorSection] = []
        for part in r.stdout.split(separator: "\n") {
            let line = String(part)
            if line.hasPrefix("  [") {
                if sections.isEmpty { continue }
                var level = DoctorItem.Level.ok
                var text = line.trimmingCharacters(in: .whitespaces)
                if text.hasPrefix("[ok]") {
                    text = String(text.dropFirst(4))
                } else if text.hasPrefix("[warn]") {
                    level = .warn
                    text = String(text.dropFirst(6))
                } else if text.hasPrefix("[FAIL]") {
                    level = .fail
                    text = String(text.dropFirst(6))
                }
                text = text.trimmingCharacters(in: .whitespaces)
                sections[sections.count - 1].items.append(DoctorItem(level: level, text: text))
            } else {
                sections.append(DoctorSection(title: Store.doctorTitle(line), items: []))
            }
        }
        return sections
    }

    private static func doctorTitle(_ s: String) -> String {
        if s.hasPrefix("claude") { return "Claude Code" }
        if s.hasPrefix("providers") { return "Providers" }
        if s.hasPrefix("things that could override") { return "Things that could override your choice" }
        return s
    }

    // MARK: - Launching

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose the project folder to open Claude Code in"
        panel.directoryURL = URL(fileURLWithPath: folder)
        if panel.runModal() == .OK, let url = panel.url {
            folder = url.path
        }
    }

    private func remember(_ path: String) {
        var list = recents.filter { $0 != path }
        list.insert(path, at: 0)
        recents = Array(list.prefix(8))
    }

    /// Opens Terminal in the chosen folder running `ccp PROVIDER`. Returns an error message on failure.
    @discardableResult
    func launch(_ providerName: String) -> String? {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder, isDirectory: &isDir), isDir.boolValue else {
            let msg = "That project folder doesn't exist anymore."
            show(msg)
            return msg
        }
        var parts = [Shell.quote(ccp), Shell.quote(providerName)]
        if continueSession { parts.append("--continue") }
        for a in Shell.splitArguments(extraArgs) { parts.append(Shell.quote(a)) }
        let inner = parts.joined(separator: " ") + "; exec \"$SHELL\" -l"

        let tmp = NSTemporaryDirectory() + "switchboard-\(UUID().uuidString)"
        let file = tmp + "/Claude Code.command"
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let lines = [
            "#!/bin/bash",
            "rm -rf " + Shell.quote(tmp),
            "cd " + Shell.quote(folder) + " || exit 1",
            "clear",
            "exec " + Shell.quote(shell) + " -l -i -c " + Shell.quote(inner)
        ]
        do {
            try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
            try (lines.joined(separator: "\n") + "\n").write(toFile: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file)
        } catch {
            let msg = "Couldn't prepare the launch: \(error.localizedDescription)"
            show(msg)
            return msg
        }
        let app = terminal.installed ? terminal : TerminalApp.terminal
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([URL(fileURLWithPath: file)], withApplicationAt: app.url, configuration: config) { _, error in
            if let error = error {
                Task { @MainActor in self.show("Couldn't open \(app.rawValue): \(error.localizedDescription)") }
            }
        }
        remember(folder)
        show("Opened \(providerName) in \((folder as NSString).lastPathComponent)")
        return nil
    }
}
