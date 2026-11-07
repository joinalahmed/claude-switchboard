import SwiftUI
import AppKit

@MainActor
struct ProviderDetailView: View {
    @EnvironmentObject var store: Store
    let provider: Provider

    var body: some View {
        Form {
            HeaderSection(provider: provider)
            LaunchSection(provider: provider)
            ConnectionSection(provider: provider)
            UsageSection(provider: provider)
            SettingsSection(provider: provider)
            EnvironmentSection(provider: provider)
            ManageSection(provider: provider)
        }
        .formStyle(.grouped)
        .navigationTitle(provider.name)
        .navigationSubtitle(provider.summary)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await store.test(provider.name) }
                } label: {
                    Label("Test", systemImage: "bolt.horizontal")
                }
                .help("Send one real request through \(provider.name)")
                .disabled(store.testing.contains(provider.name))

                Button {
                    store.launch(provider.name)
                } label: {
                    Label("Launch", systemImage: "play.fill")
                }
                .help("Open Claude Code in Terminal with \(provider.name)")
            }
        }
    }
}

// MARK: - Header

@MainActor
struct HeaderSection: View {
    @EnvironmentObject var store: Store
    let provider: Provider

    private var symbol: String {
        let t = store.templates.first(where: { $0.name == provider.templateName })
        return t?.symbol ?? "terminal"
    }

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(provider.name)
                        .font(.title2.weight(.semibold))
                    Text(provider.summary)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Label(provider.status.label, systemImage: provider.status.symbol)
                            .foregroundStyle(provider.status.color)
                        if provider.isDefault {
                            Label("Default", systemImage: "star.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                    .font(.callout)
                    statusHint
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var statusHint: some View {
        if provider.needsSetup {
            Text("This provider still has placeholder values. Fill them in under Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else if provider.status == .keyMissing {
            Text("A key stored in your Keychain is missing. Enter it again under Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
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
        Section("Launch") {
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
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!folderExists || provider.needsSetup)
            }
        }
    }
}

// MARK: - Connection test

@MainActor
struct ConnectionSection: View {
    @EnvironmentObject var store: Store
    let provider: Provider

    var body: some View {
        Section("Connection") {
            HStack {
                Button {
                    Task { await store.test(provider.name) }
                } label: {
                    Text("Test connection")
                }
                .disabled(store.testing.contains(provider.name) || provider.needsSetup)
                if store.testing.contains(provider.name) {
                    ProgressView().controlSize(.small)
                    Text("Asking Claude for one word…")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if let r = store.testResults[provider.name] {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: r.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(r.ok ? Color.green : Color.red)
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
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Usage

@MainActor
struct UsageSection: View {
    @EnvironmentObject var store: Store
    let provider: Provider

    var body: some View {
        Section("Usage") {
            if let report = store.usage {
                if let u = report.usage(for: provider.name) {
                    LabeledContent(store.usageRange.label) {
                        Text("\(u.requests.formatted()) requests · \(compactCount(u.input + u.output)) tokens")
                            .monospacedDigit()
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
        Section("Settings") {
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
                        .buttonStyle(.borderedProminent)
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
            DisclosureGroup("What Claude Code will see", isExpanded: $expanded) {
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
                Button("Make default") {
                    Task { await store.setDefault(provider.name) }
                }
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
