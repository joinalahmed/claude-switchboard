import SwiftUI

@MainActor
struct TerminalView: View {
    @EnvironmentObject var store: Store
    @State private var confirmRemove = false

    private var defaultName: String {
        return store.providers.first(where: { $0.isDefault })?.name ?? ""
    }

    private var hookOn: Bool { store.hook?.installed ?? false }

    private var defaultBinding: Binding<String> {
        return Binding(
            get: { defaultName },
            set: { name in Task { await store.setDefault(name) } }
        )
    }

    private var hookBinding: Binding<Bool> {
        return Binding(
            get: { hookOn },
            set: { on in Task { await store.setHook(on) } }
        )
    }

    private var hookFile: String {
        let f = store.hook?.files.first ?? "~/.zshrc"
        return (f as NSString).abbreviatingWithTildeInPath
    }

    var body: some View {
        Form {
            Section {
                if store.providers.isEmpty {
                    Text("Add a provider first.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Provider for claude", selection: defaultBinding) {
                        ForEach(store.providers) { p in
                            Text(p.name).tag(p.name)
                        }
                    }
                }
                Toggle("Use it whenever I type claude in Terminal", isOn: hookBinding)
                    .disabled(store.hook == nil || store.terminalBusy)
                status
            } header: {
                Text("Plain claude")
            } footer: {
                Text("Turning this on adds a small claude function to \(hookFile). It runs your default provider through ccp. Turn it off here to remove it again.")
            }

            Section {
                if store.overrides.isEmpty {
                    Label("None found. Nothing in Claude Code's own settings overrides your choice.",
                          systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    ForEach(store.overrides) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text((entry.file as NSString).abbreviatingWithTildeInPath)
                                .font(.headline)
                            Text(entry.keys.joined(separator: "\n"))
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 2)
                    }
                    HStack {
                        Label("Claude Code applies these over whichever provider you pick.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Remove them…") { confirmRemove = true }
                            .disabled(store.terminalBusy)
                    }
                }
            } header: {
                Text("Settings that override this")
            } footer: {
                Text("Looks in Claude Code's user settings for provider variables such as ANTHROPIC_BASE_URL or CLOUD_ML_REGION. Only the variable names are shown.")
            }

            Section {
                Label("Editors and apps that start Claude Code without your shell, such as IDE extensions, keep their own settings.",
                      systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Label("For one command only: CLAUDE_PROVIDER=vertex claude. To skip ccp once: command claude.",
                      systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } header: {
                Text("Good to know")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Terminal")
        .navigationSubtitle("Which provider the claude command uses")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.refreshTerminal() }
                } label: {
                    Label("Check again", systemImage: "arrow.clockwise")
                }
                .disabled(store.terminalBusy)
            }
        }
        .task { await store.refreshTerminal() }
        .confirmationDialog("Remove provider settings from Claude Code's settings?",
                            isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                Task { await store.removeOverrides() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your other settings stay as they are. A backup of each file is saved next to it.")
        }
    }

    @ViewBuilder
    private var status: some View {
        if store.hook == nil {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            }
        } else if hookOn {
            Label(defaultName.isEmpty ? "On." : "On. New Terminal windows run claude with \(defaultName).",
                  systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Label("Off. Plain claude ignores this app and uses your shell's own settings.",
                  systemImage: "circle")
                .foregroundStyle(.secondary)
        }
    }
}
