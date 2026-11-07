import Foundation

/// Puts the ccp command and the provider templates in place from inside the app bundle, so a
/// downloaded copy of the app works without running install.sh.
enum ToolInstaller {
    static func installIfNeeded(ccpPath: String, providersDir: String) {
        guard let res = Bundle.main.resourcePath else { return }
        let fm = FileManager.default
        let bundled = res + "/bin/ccp"
        guard fm.fileExists(atPath: bundled) else { return }

        let binDir = (ccpPath as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: binDir, withIntermediateDirectories: true)

        // Install ccp when it is missing or older than the copy in the app. An older copy is kept as ccp.previous.
        if !fm.fileExists(atPath: ccpPath) {
            place(bundled, at: ccpPath, mode: 0o755)
        } else if version(of: bundled) > version(of: ccpPath) {
            let backup = ccpPath + ".previous"
            try? fm.removeItem(atPath: backup)
            try? fm.moveItem(atPath: ccpPath, toPath: backup)
            place(bundled, at: ccpPath, mode: 0o755)
        }

        // Templates are only added when missing, so your own edits to them are never overwritten.
        let tplDir = providersDir + "/templates"
        try? fm.createDirectory(atPath: tplDir, withIntermediateDirectories: true,
                                attributes: [.posixPermissions: 0o700])
        let source = res + "/templates"
        for name in (try? fm.contentsOfDirectory(atPath: source)) ?? [] where name.hasSuffix(".tpl") {
            let dest = tplDir + "/" + name
            if !fm.fileExists(atPath: dest) { place(source + "/" + name, at: dest, mode: 0o644) }
        }
    }

    private static func place(_ from: String, at to: String, mode: Int) {
        let fm = FileManager.default
        try? fm.copyItem(atPath: from, toPath: to)
        try? fm.setAttributes([.posixPermissions: mode], ofItemAtPath: to)
    }

    private static func version(of path: String) -> Int {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return 0 }
        for line in text.split(separator: "\n", maxSplits: 60, omittingEmptySubsequences: false).prefix(60) {
            if line.hasPrefix("CCP_VERSION=") {
                return Int(line.dropFirst("CCP_VERSION=".count).trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        return 0
    }
}
