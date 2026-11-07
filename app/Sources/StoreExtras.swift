import SwiftUI
import AppKit

struct HookStatus {
    var installed: Bool
    var files: [String]
}

struct OverrideEntry: Identifiable {
    var file: String
    var keys: [String]
    var id: String { file }
}

// MARK: - Plain `claude` in the terminal, and settings that fight it

extension Store {
    func refreshTerminal() async {
        let s = await ccpRun(["shell", "status"], timeout: 20)
        var installed = false
        var files: [String] = []
        for part in s.stdout.split(separator: "\n") {
            let f = part.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard f.count == 2 else { continue }
            files.append(String(f[1]))
            if f[0] == "installed" { installed = true }
        }
        hook = HookStatus(installed: installed, files: files)

        let o = await ccpRun(["overrides"], timeout: 20)
        var order: [String] = []
        var map: [String: [String]] = [:]
        for part in o.stdout.split(separator: "\n") {
            let f = part.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard f.count == 2 else { continue }
            let file = String(f[0])
            if map[file] == nil { order.append(file) }
            map[file, default: []].append(String(f[1]))
        }
        overrides = order.map { OverrideEntry(file: $0, keys: map[$0] ?? []) }
    }

    func setHook(_ on: Bool) async {
        terminalBusy = true
        let r = await ccpRun(["shell", on ? "install" : "remove"], timeout: 20)
        await refreshTerminal()
        terminalBusy = false
        if r.ok {
            show(on ? "Done. Open a new Terminal window and claude will use your default provider."
                    : "Removed. Plain claude uses your shell's own settings again.")
        } else {
            show(Store.summarize(r))
        }
    }

    func removeOverrides() async {
        terminalBusy = true
        let r = await ccpRun(["overrides", "--fix"], timeout: 30)
        await refreshTerminal()
        terminalBusy = false
        show(r.ok ? "Removed. A backup is saved next to each file." : Store.summarize(r))
    }

    // MARK: - Usage

    func loadUsage() async {
        usageLoading = true
        let d = dir
        let since = usageRange.since
        let report: UsageReport = await withCheckedContinuation { (cont: CheckedContinuation<UsageReport, Never>) in
            DispatchQueue.global(qos: .utility).async {
                cont.resume(returning: UsageScanner.scan(dir: d, since: since))
            }
        }
        usage = report
        usageLoading = false
    }
}
