import SwiftUI

enum SidebarItem: Hashable {
    case provider(String)
    case switcher
    case usage
    case health
}

struct Field: Identifiable, Hashable {
    enum Kind { case plain, secret }
    var kind: Kind
    var name: String
    var prompt: String
    var defaultValue: String
    var required: Bool
    var id: String { name }

    /// Short label: the prompt up to the first ":" or " (".
    var title: String { split.0 }
    /// Longer explanation, shown as the placeholder inside the field.
    var hint: String { split.1 }
    /// What the empty field shows.
    var placeholder: String {
        if !hint.isEmpty { return hint }
        return required ? "Required" : "Optional"
    }

    private var split: (String, String) {
        let p = prompt
        var cut: String.Index? = nil
        var dropParen = false
        if let r = p.range(of: ": ") { cut = r.lowerBound }
        if let r = p.range(of: " ("), cut == nil || r.lowerBound < cut! {
            cut = r.lowerBound
            dropParen = true
        }
        guard let c = cut else { return (p, "") }
        let title = String(p[p.startIndex..<c]).trimmingCharacters(in: .whitespaces)
        var rest = String(p[c...]).trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespaces))
        if dropParen {
            rest = rest.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        }
        return (title.isEmpty ? p : title, rest)
    }
}

struct Template: Identifiable, Hashable {
    var name: String
    var summary: String
    var fields: [Field]
    var id: String { name }

    var symbol: String {
        switch name {
        case "anthropic": return "key"
        case "anthropic-login": return "person.crop.circle"
        case "vertex": return "cloud"
        case "bedrock": return "square.stack.3d.up"
        case "foundry": return "building.2"
        case "litellm": return "arrow.triangle.branch"
        case "gateway": return "network"
        case "custom": return "slider.horizontal.3"
        default: return "puzzlepiece"
        }
    }
}

struct SecretRef: Hashable {
    var variable: String
    var service: String
    var present: Bool
}

enum ProviderStatus {
    case ready
    case needsSetup
    case keyMissing

    var symbol: String {
        switch self {
        case .ready: return "checkmark.circle.fill"
        case .needsSetup: return "exclamationmark.triangle.fill"
        case .keyMissing: return "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .ready: return .green
        case .needsSetup: return .orange
        case .keyMissing: return .red
        }
    }

    var label: String {
        switch self {
        case .ready: return "Ready"
        case .needsSetup: return "Needs setup"
        case .keyMissing: return "Key missing"
        }
    }
}

struct Provider: Identifiable, Hashable {
    var name: String
    var summary: String
    var templateName: String?
    var needsSetup: Bool
    var secrets: [SecretRef]
    var values: [String: String]
    var raw: String
    var kindHint: String?
    var isActive: Bool
    var id: String { name }

    var status: ProviderStatus {
        if needsSetup { return .needsSetup }
        if secrets.contains(where: { !$0.present }) { return .keyMissing }
        return .ready
    }
}

struct TestResult {
    var ok: Bool
    var message: String
    var seconds: Double
    var date: Date
}

struct Variable: Identifiable {
    var name: String
    var value: String
    var id: String { name }
}

struct ResolvedSettings {
    var summary: String
    var variables: [Variable]
    var warnings: [String]
}

struct DoctorItem: Identifiable {
    enum Level {
        case ok, warn, fail

        var symbol: String {
            switch self {
            case .ok: return "checkmark.circle.fill"
            case .warn: return "exclamationmark.triangle.fill"
            case .fail: return "xmark.octagon.fill"
            }
        }

        var color: Color {
            switch self {
            case .ok: return .green
            case .warn: return .orange
            case .fail: return .red
            }
        }
    }

    let id = UUID()
    var level: Level
    var text: String
}

struct DoctorSection: Identifiable {
    let id = UUID()
    var title: String
    var items: [DoctorItem]
}

enum TerminalApp: String, CaseIterable, Identifiable {
    case terminal = "Terminal"
    case iterm = "iTerm"

    var id: String { rawValue }

    var url: URL {
        switch self {
        case .terminal: return URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        case .iterm: return URL(fileURLWithPath: "/Applications/iTerm.app")
        }
    }

    var installed: Bool { FileManager.default.fileExists(atPath: url.path) }
}

/// Reads the files in ~/.claude-providers. Everything that changes them goes through `ccp`.
enum Catalog {
    static let reserved: Set<String> = [
        "help", "list", "ls", "templates", "template", "template-vars", "secrets", "add", "new",
        "edit", "remove", "rm", "key", "show", "test", "doctor", "default", "use", "status", "import", "auth",
        "run", "shell", "overrides", "usage", "none", "off"
    ]

    static func read(_ path: String) -> String? {
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    /// The provider `ccp use` chose. Empty when none is active.
    static func activeName(dir: String) -> String {
        guard let text = read(dir + "/default") else { return "" }
        let first = text.split(separator: "\n").first.map(String.init) ?? ""
        return first.trimmingCharacters(in: .whitespaces)
    }

    static func headers(_ text: String, _ key: String) -> [String] {
        let prefix = "# \(key):"
        var found: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix(prefix) {
                found.append(line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces))
            }
        }
        return found
    }

    static func header(_ text: String, _ key: String) -> String? {
        return headers(text, key).first
    }

    static func keychainHas(_ service: String) -> Bool {
        let r = Shell.exec("/usr/bin/security",
                           ["find-generic-password", "-a", NSUserName(), "-s", service],
                           env: ProcessInfo.processInfo.environment, cwd: nil, timeout: 10)
        return r.ok
    }

    static func loadTemplates(dir: String) -> [Template] {
        let tdir = dir + "/templates"
        let all = (try? FileManager.default.contentsOfDirectory(atPath: tdir)) ?? []
        let files = all.filter { $0.hasSuffix(".tpl") }.sorted()
        var result: [Template] = []
        for f in files {
            guard let text = read(tdir + "/" + f) else { continue }
            let name = String(f.dropLast(4))
            var fields: [Field] = []
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let l = String(line)
                var kind: Field.Kind? = nil
                var rest = ""
                if l.hasPrefix("# var:") {
                    kind = .plain
                    rest = String(l.dropFirst(6))
                } else if l.hasPrefix("# secret:") {
                    kind = .secret
                    rest = String(l.dropFirst(9))
                }
                guard let k = kind else { continue }
                let parts = rest.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                guard let varName = parts.first, !varName.isEmpty else { continue }
                let prompt = parts.count > 1 ? parts[1] : varName
                let def = parts.count > 2 ? parts[2] : ""
                let req = parts.count > 3 && parts[3] == "required"
                fields.append(Field(kind: k, name: varName, prompt: prompt, defaultValue: def, required: req))
            }
            let summary = header(text, "description") ?? name
            result.append(Template(name: name, summary: summary, fields: fields))
        }
        return result
    }

    static func loadProviders(dir: String, activeName: String) -> [Provider] {
        let all = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        let files = all.filter { $0.hasSuffix(".env") }.sorted()
        var out: [Provider] = []
        for f in files {
            let name = String(f.dropLast(4))
            guard let text = read(dir + "/" + f) else { continue }
            let prefix = "ccp-\(name)-"
            var secrets: [SecretRef] = []
            for svc in headers(text, "secret-service") {
                let variable = svc.hasPrefix(prefix) ? String(svc.dropFirst(prefix.count)) : svc
                secrets.append(SecretRef(variable: variable, service: svc, present: keychainHas(svc)))
            }
            var needs = false
            for line in text.split(separator: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                if !t.hasPrefix("#") && t.contains("CHANGE_ME") { needs = true }
            }
            out.append(Provider(
                name: name,
                summary: header(text, "description") ?? "",
                templateName: header(text, "template"),
                needsSetup: needs,
                secrets: secrets,
                values: parseValues(text),
                raw: text,
                kindHint: header(text, "kind"),
                isActive: !activeName.isEmpty && name == activeName
            ))
        }
        return out
    }

    /// `export NAME=value` lines (secrets that live in the Keychain are skipped).
    static func parseValues(_ text: String) -> [String: String] {
        var values: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let l = line.trimmingCharacters(in: .whitespaces)
            guard l.hasPrefix("export ") else { continue }
            let body = l.dropFirst(7)
            guard let eq = body.firstIndex(of: "=") else { continue }
            let key = String(body[body.startIndex..<eq])
            let raw = String(body[body.index(after: eq)...])
            if raw.contains("ccp_secret") { continue }
            values[key] = shellUnquote(raw)
        }
        return values
    }

    static func shellUnquote(_ s: String) -> String {
        var out = ""
        var inSingle = false
        var inDouble = false
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            let hasNext = s.index(after: i) < s.endIndex
            if inSingle {
                if c == "'" { inSingle = false } else { out.append(c) }
            } else if inDouble {
                if c == "\"" {
                    inDouble = false
                } else if c == "\\" && hasNext {
                    i = s.index(after: i)
                    out.append(s[i])
                } else {
                    out.append(c)
                }
            } else {
                if c == "'" {
                    inSingle = true
                } else if c == "\"" {
                    inDouble = true
                } else if c == "\\" && hasNext {
                    i = s.index(after: i)
                    out.append(s[i])
                } else if c == " " || c == "\t" {
                    break
                } else {
                    out.append(c)
                }
            }
            i = s.index(after: i)
        }
        return out
    }
}

/// What `ccp status` reports: which provider is active and whether Claude Code's settings file still matches it.
struct SwitchStatus: Equatable {
    enum State: String {
        case synced, drift, stale, foreign, unset
    }

    var active: String
    var state: State
    var settingsPath: String
    var keys: [String]
    var helperOn: Bool
    var hookInstalled: Bool
    var claudePath: String

    var settingsName: String { (settingsPath as NSString).abbreviatingWithTildeInPath }

    /// True when every new `claude` session follows the active provider.
    var inEffect: Bool { state == .synced && !active.isEmpty }

    static func parse(_ text: String) -> SwitchStatus {
        var s = SwitchStatus(active: "", state: .unset, settingsPath: "~/.claude/settings.json",
                             keys: [], helperOn: false, hookInstalled: false, claudePath: "")
        for part in text.split(separator: "\n") {
            let f = part.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard f.count == 2 else { continue }
            let v = String(f[1])
            switch f[0] {
            case "active": s.active = v
            case "state": s.state = State(rawValue: v) ?? .unset
            case "settings": s.settingsPath = v
            case "key": s.keys.append(v)
            case "helper": s.helperOn = v == "on"
            case "hook": s.hookInstalled = v == "installed"
            case "claude": s.claudePath = v
            default: break
            }
        }
        return s
    }
}
