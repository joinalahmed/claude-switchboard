import SwiftUI
import AppKit

// MARK: - Switching: what Claude Code is set to, and the optional shell hook

extension Store {
    /// Asks ccp which provider is active and whether Claude Code's settings file still matches it.
    func refreshSwitch() async {
        let r = await ccpRun(["status", "--plain"], timeout: 20)
        if r.ok {
            status = SwitchStatus.parse(r.stdout)
        } else if status == nil {
            status = SwitchStatus(active: "", state: .unset, settingsPath: dir, keys: [],
                                  helperOn: false, hookInstalled: false, claudePath: "")
        }
    }

    /// Writes the active provider into Claude Code's settings again, after someone edited the file.
    func reapply() async {
        guard let name = status?.active, !name.isEmpty else { return }
        await activate(name)
    }

    /// Takes ccp's variables out of Claude Code's settings. Claude Code goes back to its own sign-in.
    func release() async {
        switchBusy = true
        let r = await ccpRun(["use", "none"], timeout: 30)
        await refresh()
        await refreshSwitch()
        switchBusy = false
        show(r.ok ? "Claude Code is back to its own sign-in." : Store.summarize(r), error: !r.ok)
    }

    /// Turns the provider variables someone typed into settings.json into a provider of their own.
    /// Returns an error message on failure.
    func importCurrent(as name: String) async -> String? {
        switchBusy = true
        let r = await ccpRun(["import", name], timeout: 30)
        await refresh()
        await refreshSwitch()
        switchBusy = false
        if r.ok {
            selection = .provider(name)
            show("Saved as \(name). Switch to it when you're ready.")
            return nil
        }
        return Store.summarize(r)
    }

    /// Removes provider variables that ccp didn't write from Claude Code's settings.
    func removeOverrides() async {
        switchBusy = true
        let r = await ccpRun(["overrides", "--fix"], timeout: 30)
        await refreshSwitch()
        switchBusy = false
        show(r.ok ? "Removed. A copy of the file was kept next to it." : Store.summarize(r), error: !r.ok)
    }

    func setHook(_ on: Bool) async {
        switchBusy = true
        let r = await ccpRun(["shell", on ? "install" : "remove"], timeout: 20)
        await refreshSwitch()
        switchBusy = false
        if r.ok {
            show(on ? "Done. From the next Terminal window on, claude launches show up in Usage."
                    : "Removed. Plain claude runs without ccp again.")
        } else {
            show(Store.summarize(r), error: true)
        }
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
