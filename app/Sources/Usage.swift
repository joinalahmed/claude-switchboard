import Foundation

// MARK: - Models

enum UsageRange: String, CaseIterable, Identifiable {
    case week, month, quarter, all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: return "Last 7 days"
        case .month: return "Last 30 days"
        case .quarter: return "Last 90 days"
        case .all: return "All time"
        }
    }

    var since: Date? {
        let days: Int
        switch self {
        case .week: days = 7
        case .month: days = 30
        case .quarter: days = 90
        case .all: return nil
        }
        let start = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: -(days - 1), to: start)
    }
}

struct ProviderUsage: Identifiable {
    var provider: String
    var requests: Int = 0
    var sessions: Int = 0
    var input: Int = 0      // new input tokens, including cache writes
    var output: Int = 0
    var cached: Int = 0     // tokens read back from the prompt cache
    var lastUsed: Date? = nil
    var id: String { provider }
    var isUnattributed: Bool { provider == UsageScanner.other }
}

struct DailyUsage: Identifiable {
    var day: Date
    var provider: String
    var requests: Int = 0
    var input: Int = 0
    var output: Int = 0
    var id: String { "\(day.timeIntervalSince1970)|\(provider)" }
}

struct ModelUsage: Identifiable {
    var provider: String
    var model: String
    var requests: Int = 0
    var input: Int = 0
    var output: Int = 0
    var id: String { provider + "|" + model }
}

struct UsageReport {
    var providers: [ProviderUsage] = []
    var daily: [DailyUsage] = []
    var models: [ModelUsage] = []
    var filesScanned = 0
    var runsLogged = 0
    var sourceFound = false
    var generated = Date()

    var totalRequests: Int { providers.reduce(0) { $0 + $1.requests } }
    var totalInput: Int { providers.reduce(0) { $0 + $1.input } }
    var totalOutput: Int { providers.reduce(0) { $0 + $1.output } }
    var totalCached: Int { providers.reduce(0) { $0 + $1.cached } }

    func usage(for provider: String) -> ProviderUsage? {
        return providers.first(where: { $0.provider == provider })
    }
}

struct RunRecord {
    var start: Double
    var end: Double?
    var pid: Int32
    var provider: String
    var cwd: String
    var alive: Bool
}

// MARK: - Scanner

/// Reads Claude Code's own session files (~/.claude/projects/**/*.jsonl) and credits each assistant
/// message to the provider ccp launched Claude Code with at that moment (from usage/runs.log).
enum UsageScanner {
    static let other = "Not via ccp"

    private static func normalize(_ path: String) -> String {
        if path.isEmpty { return path }
        return URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }

    static func loadRuns(dir: String) -> [RunRecord] {
        guard let text = try? String(contentsOfFile: dir + "/usage/runs.log", encoding: .utf8) else { return [] }
        var runs: [RunRecord] = []
        var open: [Int32: Int] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map { String($0) }
            guard f.count >= 3, let ts = Double(f[1]), let pid = Int32(f[2]) else { continue }
            if f[0] == "S", f.count >= 5 {
                let cwd = normalize(f[4].trimmingCharacters(in: .whitespacesAndNewlines))
                runs.append(RunRecord(start: ts, end: nil, pid: pid, provider: f[3], cwd: cwd, alive: false))
                open[pid] = runs.count - 1
            } else if f[0] == "E", let i = open[pid] {
                runs[i].end = ts
                open[pid] = nil
            }
        }
        let now = Date().timeIntervalSince1970
        for (pid, i) in open where now - runs[i].start < 86_400 {
            if kill(pid, 0) == 0 { runs[i].alive = true }
        }
        runs.sort { $0.start < $1.start }
        return runs
    }

    /// The provider whose run covers this moment. Prefers a run in the same folder; otherwise
    /// accepts a lone candidate; otherwise the message is not attributed.
    static func attribute(ts: Double, cwd: String, runs: [RunRecord], now: Double) -> String {
        var lo = 0
        var hi = runs.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if runs[mid].start <= ts + 2 { lo = mid + 1 } else { hi = mid }
        }
        var candidates = Set<String>()
        var i = lo - 1
        while i >= 0 {
            let r = runs[i]
            let end = r.end ?? (r.alive ? now : r.start + 6 * 3600)
            if ts <= end + 5 {
                if !cwd.isEmpty && (r.cwd == cwd || cwd.hasPrefix(r.cwd + "/")) { return r.provider }
                candidates.insert(r.provider)
            }
            i -= 1
        }
        if candidates.count == 1, let only = candidates.first { return only }
        return other
    }

    private static func transcriptRoots() -> [String] {
        let env = ProcessInfo.processInfo.environment
        var roots: [String] = []
        if let c = env["CLAUDE_CONFIG_DIR"], !c.isEmpty { roots.append(c + "/projects") }
        roots.append(NSHomeDirectory() + "/.claude/projects")
        roots.append(NSHomeDirectory() + "/.config/claude/projects")
        var seen = Set<String>()
        return roots.filter { FileManager.default.fileExists(atPath: $0) && seen.insert($0).inserted }
    }

    private static func forEachMatchingLine(_ data: Data, needle: [UInt8], _ body: (Data) -> Void) {
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            let n = raw.count
            var pos = 0
            needle.withUnsafeBufferPointer { nb in
                while pos < n {
                    let p = base.advanced(by: pos)
                    let rest = n - pos
                    var len = rest
                    var next = n
                    if let nl = memchr(p, 10, rest) {
                        len = p.distance(to: UnsafeRawPointer(nl))
                        next = pos + len + 1
                    }
                    if len > 20, memmem(p, len, nb.baseAddress, nb.count) != nil {
                        body(Data(bytes: p, count: len))
                    }
                    pos = next
                }
            }
        }
    }

    static func scan(dir: String, since: Date?) -> UsageReport {
        let runs = loadRuns(dir: dir)
        let now = Date().timeIntervalSince1970
        let sinceTs = since?.timeIntervalSince1970
        let roots = transcriptRoots()

        var report = UsageReport()
        report.runsLogged = runs.count
        report.sourceFound = !roots.isEmpty

        var totals: [String: ProviderUsage] = [:]
        var sessions: [String: Set<String>] = [:]
        var daily: [String: DailyUsage] = [:]
        var models: [String: ModelUsage] = [:]
        var seen = Set<String>()
        var normalized: [String: String] = [:]
        var attributed: [String: String] = [:]

        let isoFraction = ISO8601DateFormatter()
        isoFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        let cal = Calendar.current
        let needle = Array("\"output_tokens\"".utf8)

        var files: [URL] = []
        for root in roots {
            let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
            guard let en = FileManager.default.enumerator(at: URL(fileURLWithPath: root),
                                                          includingPropertiesForKeys: keys,
                                                          options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in en where url.pathExtension == "jsonl" {
                if let s = since,
                   let m = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                   m < s.addingTimeInterval(-86_400) { continue }
                files.append(url)
            }
        }
        report.filesScanned = files.count

        for url in files {
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { continue }
            forEachMatchingLine(data, needle: needle) { line in
                guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
                      (obj["type"] as? String) == "assistant",
                      let msg = obj["message"] as? [String: Any],
                      let usage = msg["usage"] as? [String: Any],
                      let stamp = obj["timestamp"] as? String,
                      let date = isoFraction.date(from: stamp) ?? isoPlain.date(from: stamp) else { return }
                let model = (msg["model"] as? String) ?? "unknown"
                if model.hasPrefix("<") { return }
                let ts = date.timeIntervalSince1970
                if let s = sinceTs, ts < s { return }

                let mid = (msg["id"] as? String) ?? ""
                if !mid.isEmpty {
                    let key = mid + ":" + ((obj["requestId"] as? String) ?? "")
                    if !seen.insert(key).inserted { return }
                }

                func num(_ k: String) -> Int { return (usage[k] as? NSNumber)?.intValue ?? 0 }
                let input = num("input_tokens") + num("cache_creation_input_tokens")
                let output = num("output_tokens")
                let cached = num("cache_read_input_tokens")

                let rawCwd = (obj["cwd"] as? String) ?? ""
                let cwd: String
                if let c = normalized[rawCwd] { cwd = c } else { cwd = normalize(rawCwd); normalized[rawCwd] = cwd }
                let sid = (obj["sessionId"] as? String) ?? url.deletingPathExtension().lastPathComponent
                // Attribute per (session, minute) so a message doesn't need a lookup of its own every time.
                let bucket = Int(ts / 60)
                let akey = sid + "|" + String(bucket)
                let provider: String
                if let p = attributed[akey] { provider = p } else {
                    provider = attribute(ts: ts, cwd: cwd, runs: runs, now: now)
                    attributed[akey] = provider
                }

                var t = totals[provider] ?? ProviderUsage(provider: provider)
                t.requests += 1
                t.input += input
                t.output += output
                t.cached += cached
                if t.lastUsed == nil || date > t.lastUsed! { t.lastUsed = date }
                totals[provider] = t
                sessions[provider, default: []].insert(sid)

                let day = cal.startOfDay(for: date)
                let dkey = "\(day.timeIntervalSince1970)|\(provider)"
                var d = daily[dkey] ?? DailyUsage(day: day, provider: provider)
                d.requests += 1
                d.input += input
                d.output += output
                daily[dkey] = d

                let mkey = provider + "|" + model
                var m = models[mkey] ?? ModelUsage(provider: provider, model: model)
                m.requests += 1
                m.input += input
                m.output += output
                models[mkey] = m
            }
        }

        var list = totals.values.map { u -> ProviderUsage in
            var x = u
            x.sessions = sessions[u.provider]?.count ?? 0
            return x
        }
        list.sort { a, b in
            if a.isUnattributed != b.isUnattributed { return !a.isUnattributed }
            return a.requests > b.requests
        }
        report.providers = list
        report.daily = daily.values.sorted { $0.day < $1.day }
        report.models = models.values.sorted { $0.requests > $1.requests }
        report.generated = Date()
        return report
    }
}
