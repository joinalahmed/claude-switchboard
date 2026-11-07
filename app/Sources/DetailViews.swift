import SwiftUI
import AppKit

@MainActor
struct ProviderDetailView: View {
    @EnvironmentObject var store: Store
    let provider: Provider

    var body: some View {
        Form {
            HeroSection(provider: provider)
            LaunchSection(provider: provider)
            ConnectionSection(provider: provider)
            UsageSection(provider: provider)
            SettingsSection(provider: provider)
            EnvironmentSection(provider: provider)
            ManageSection(provider: provider)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Backdrop(accent: provider.accent))
        .tint(provider.accent.a)
        .navigationTitle(provider.name)
        .navigationSubtitle(provider.summary)
    }
}

// MARK: - Hero

@MainActor
struct HeroSection: View {
    @EnvironmentObject var store: Store
    let provider: Provider

    private var accent: Accent { provider.accent }

    private var symbol: String {
        let t = store.templates.first(where: { $0.name == provider.templateName })
        return t?.symbol ?? "terminal"
    }

    private var testing: Bool { store.testing.contains(provider.name) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return Section {
            ZStack {
                shape.fill(accent.gradient)
                CableDecoration()
                shape.fill(LinearGradient(colors: [Color.clear, Color.black.opacity(0.2)],
                                          startPoint: .top, endPoint: .bottom))
                content
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            .shadow(color: accent.a.opacity(0.35), radius: 18, y: 9)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
        }
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.22))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                Image(systemName: symbol)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
            }
            .frame(width: 78, height: 78)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text(provider.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Text(provider.summary)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    HeroChip(text: provider.status.label, symbol: provider.status.symbol)
                    if provider.isDefault {
                        HeroChip(text: "Default for claude", symbol: "star.fill")
                    }
                }
                hint
            }
            Spacer(minLength: 8)
            VStack(spacing: 9) {
                Button {
                    store.launch(provider.name)
                } label: {
                    Label("Launch", systemImage: "play.fill")
                }
                .buttonStyle(HeroButtonStyle(filled: true, tint: accent.b))
                .disabled(provider.needsSetup)
                .help("Open Claude Code in Terminal with \(provider.name)")

                Button {
                    Task { await store.test(provider.name) }
                } label: {
                    Label(testing ? "Testing…" : "Test", systemImage: "bolt.horizontal.fill")
                }
                .buttonStyle(HeroButtonStyle(filled: false, tint: accent.b))
                .disabled(testing || provider.needsSetup)
                .help("Send one real request through \(provider.name)")
            }
        }
        .padding(22)
    }

    @ViewBuilder
    private var hint: some View {
        if provider.needsSetup {
            Text("Still has placeholder values. Fill them in under Settings.")
                .font(.callout)
                .foregroundStyle(Color.white.opacity(0.92))
        } else if provider.status == .keyMissing {
            Text("A key in your Keychain is missing. Enter it again under Settings.")
                .font(.callout)
                .foregroundStyle(Color.white.opacity(0.92))
        }
    }
}

// MARK: - Launch

@MainActor
struct LaunchSection: View {
    @EnvironmentObject var store: Store
    let provider: Provider

    private var folderExists: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: store.folder, isDirectory: &isDir) && isDir.boolValue
    }

    private var installedTerminals: [TerminalApp] {
        return TerminalApp.allCases.filter { $0.installed }
    }

    var body: some View {
        Section {
            LabeledContent("Project folder") {
                HStack(spacing: 8) {
                    Text((store.folder as NSString).abbreviatingWithTildeInPath)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .foregroundStyle(folderExists ? Color.primary : Color.red)
                        .textSelection(.enabled)
                    Menu {
                        ForEach(store.recents, id: \.self) { path in
                            Button((path as NSString).abbreviatingWithTildeInPath) { store.folder = path }
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .disabled(store.recents.isEmpty)
                    .help("Recent folders")
                    .accessibilityLabel("Recent folders")
                    Button("Choose…") { store.chooseFolder() }
                }
            }
            if !folderExists {
                Label("This folder no longer exists. Choose another one.", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            Toggle("Continue the last conversation in this folder", isOn: $store.continueSession)
            TextField("Extra options", text: $store.extraArgs, prompt: Text("For example: --model sonnet"))
            if installedTerminals.count > 1 {
                Picker("Open in", selection: $store.terminal) {
                    ForEach(installedTerminals) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
            }
            HStack {
                Spacer()
                Button {
                    store.launch(provider.name)
                } label: {
                    Label("Launch Claude Code", systemImage: "play.fill")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(GradientButtonStyle(accent: provider.accent))
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!folderExists || provider.needsSetup)
            }
        } header: {
            SectionTitle(text: "Launch", symbol: "play.circle.fill", color: provider.accent.a)
        }
    }
}

// MARK: - Connection test

@MainActor
struct ConnectionSection: View {
    @EnvironmentObject var store: Store
    let provider: Provider

    var body: some View {
        Section {
            HStack {
                Button {
                    Task { await store.test(provider.name) }
                } label: {
                    Label("Test connection", systemImage: "bolt.horizontal.fill")
                }
                .buttonStyle(SoftButtonStyle(color: provider.accent.a))
                .disabled(store.testing.contains(provider.name) || provider.needsSetup)
                if store.testing.contains(provider.name) {
                    ProgressView().controlSize(.small)
                    Text("Asking Claude for one word…")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            VStack {
                if let r = store.testResults[provider.name] {
                    result(r)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75),
                       value: store.testResults[provider.name]?.date)
        } header: {
            SectionTitle(text: "Connection", symbol: "bolt.horizontal.circle.fill", color: provider.accent.a)
        }
    }

    private func result(_ r: TestResult) -> some View {
        let color: Color = r.ok ? Color.green : Color.red
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: r.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.title2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(r.ok ? "Working" : "Failed")
                    .font(.headline)
                Text(r.message)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("Took \(String(format: "%.1f", r.seconds)) s")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(color.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Usage

@MainActor
struct UsageSection: View {
    @EnvironmentObject var store: Store
    let provider: Provider

    var body: some View {
        Section {
            if let report = store.usage {
                if let u = report.usage(for: provider.name) {
                    LabeledContent(store.usageRange.label) {
                        Text("\(u.requests.formatted()) requests · \(compactCount(u.input + u.output)) tokens")
                            .monospacedDigit()
                    }
                    if report.totalRequests > 0 {
                        let share = Double(u.requests) / Double(report.totalRequests)
                        VStack(alignment: .leading, spacing: 4) {
                            ShareBar(fraction: share, accent: provider.accent)
                            Text("\(Int((share * 100).rounded()))% of all requests")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    LabeledContent(store.usageRange.label) {
                        Text("No requests yet").foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading usage…").foregroundStyle(.secondary)
                }
            }
            HStack {
                Spacer()
                Button("See all usage") { store.selection = .usage }
                    .buttonStyle(.link)
            }
        } header: {
            SectionTitle(text: "Usage", symbol: "chart.bar.fill", color: provider.accent.a)
        }
    }
}

// MARK: - Settings

@MainActor
struct SettingsSection: View {
    @EnvironmentObject var store: Store
    let provider: Provider

    @State private var values: [String: String] = [:]
    @State private var secrets: [String: String] = [:]
    @State private var raw: String = ""
    @State private var showRaw = false
    @State private var saving = false
    @State private var message: String? = nil

    private var template: Template? {
        return store.templates.first(where: { $0.name == provider.templateName })
    }

    private var plainFields: [Field] {
        return (template?.fields ?? []).filter { $0.kind == .plain }
    }

    private func isStored(_ f: Field) -> Bool {
        return provider.secrets.first(where: { $0.variable == f.name })?.present ?? false
    }

    private var isValid: Bool {
        guard let t = template else { return false }
        for f in t.fields where f.required {
            if f.kind == .plain {
                if (values[f.name] ?? "").trimmingCharacters(in: .whitespaces).isEmpty { return false }
            } else {
                let typed = !(secrets[f.name] ?? "").isEmpty
                if !typed && !isStored(f) { return false }
            }
        }
        return true
    }

    private var isDirty: Bool {
        for f in plainFields {
            if (values[f.name] ?? "") != (provider.values[f.name] ?? "") { return true }
        }
        for (_, v) in secrets where !v.isEmpty { return true }
        return false
    }

    private func valueBinding(_ name: String) -> Binding<String> {
        return Binding(get: { values[name] ?? "" }, set: { values[name] = $0 })
    }

    private func secretBinding(_ name: String) -> Binding<String> {
        return Binding(get: { secrets[name] ?? "" }, set: { secrets[name] = $0 })
    }

    private func load() {
        var v: [String: String] = [:]
        for f in plainFields { v[f.name] = provider.values[f.name] ?? "" }
        values = v
        secrets = [:]
        raw = provider.raw
        message = nil
    }

    private func save() {
        guard let t = template else { return }
        saving = true
        message = nil
        let vals = values
        let secs = secrets
        Task {
            let err = await store.saveProvider(name: provider.name, template: t.name, values: vals,
                                               secrets: secs, makeDefault: false, replace: true)
            saving = false
            if let err = err {
                message = err
            } else {
                store.show("Saved \(provider.name)")
            }
        }
    }

    var body: some View {
        Section {
            if let t = template, !t.fields.isEmpty {
                ForEach(t.fields) { f in
                    if f.kind == .secret {
                        SecureField(f.title, text: secretBinding(f.name),
                                    prompt: Text(isStored(f) ? "Stored in Keychain. Leave blank to keep it." : f.placeholder))
                    } else {
                        TextField(f.title, text: valueBinding(f.name),
                                  prompt: Text(f.placeholder))
                    }
                }
                if let m = message {
                    Label(m, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                        .textSelection(.enabled)
                }
                HStack {
                    Spacer()
                    if saving { ProgressView().controlSize(.small) }
                    Button("Revert") { load() }
                        .disabled(!isDirty || saving)
                    Button("Save changes") { save() }
                        .buttonStyle(GradientButtonStyle(accent: provider.accent))
                        .disabled(!isDirty || !isValid || saving)
                }
            } else if provider.templateName == nil {
                Text("This provider was written by hand, so it's edited as a file.")
                    .foregroundStyle(.secondary)
            } else {
                Text("This provider has no settings to fill in. Edit the file for anything else.")
                    .foregroundStyle(.secondary)
            }
            DisclosureGroup("Edit file", isExpanded: $showRaw) {
                TextEditor(text: $raw)
                    .font(.system(.callout, design: .monospaced))
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
                    .accessibilityLabel("Provider file")
                HStack {
                    Spacer()
                    Button("Revert") { raw = provider.raw }
                        .disabled(raw == provider.raw)
                    Button("Save file") {
                        Task {
                            let err = await store.saveRaw(provider.name, text: raw)
                            if let err = err { message = err } else { store.show("Saved \(provider.name).env") }
                        }
                    }
                    .disabled(raw == provider.raw)
                }
            }
        } header: {
            SectionTitle(text: "Settings", symbol: "slider.horizontal.3", color: provider.accent.a)
        }
        .onAppear {
            load()
            if provider.templateName == nil || provider.needsSetup && template == nil { showRaw = true }
        }
        .onChange(of: provider) { _, _ in load() }
    }
}

// MARK: - Resolved environment

@MainActor
struct EnvironmentSection: View {
    @EnvironmentObject var store: Store
    let provider: Provider

    @State private var expanded = false
    @State private var resolved: ResolvedSettings? = nil
    @State private var loading = false

    private func load() async {
        loading = true
        resolved = await store.resolve(provider.name)
        loading = false
    }

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $expanded) {
                if loading {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Reading settings…").foregroundStyle(.secondary)
                    }
                } else if let r = resolved {
                    Text(r.summary)
                        .foregroundStyle(.secondary)
                    ForEach(r.warnings, id: \.self) { w in
                        Label(w, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    ForEach(r.variables) { v in
                        LabeledContent(v.name) {
                            Text(v.value)
                                .font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    if r.variables.isEmpty {
                        Text("No overrides. Claude Code uses its own sign-in.")
                            .foregroundStyle(.secondary)
                    }
                }
            } label: {
                SectionTitle(text: "What Claude Code will see", symbol: "eye.fill", color: provider.accent.a)
            }
        }
        .onChange(of: expanded) { _, now in
            if now { Task { await load() } }
        }
        .onChange(of: provider) { _, _ in
            resolved = nil
            if expanded { Task { await load() } }
        }
    }
}

// MARK: - Manage

@MainActor
struct ManageSection: View {
    @EnvironmentObject var store: Store
    let provider: Provider
    @State private var confirmDelete = false

    var body: some View {
        Section {
            HStack {
                Button {
                    Task { await store.setDefault(provider.name) }
                } label: {
                    Label(provider.isDefault ? "Default for claude" : "Make default",
                          systemImage: provider.isDefault ? "star.fill" : "star")
                }
                .buttonStyle(SoftButtonStyle(color: Color.orange))
                .disabled(provider.isDefault)
                Spacer()
                Button("Delete…", role: .destructive) { confirmDelete = true }
            }
        }
        .confirmationDialog("Delete \(provider.name)?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                Task { await store.delete(provider.name) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the provider and its keys from your Keychain. You can't undo it.")
        }
    }
}
