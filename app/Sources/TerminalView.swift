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

    private var defaultProvider: Provider? {
        return store.providers.first(where: { $0.isDefault })
    }

    private var defaultSymbol: String {
        let p = defaultProvider
        return store.templates.first(where: { $0.name == p?.templateName })?.symbol ?? "terminal"
    }

    var body: some View {
        Form {
            Section {
                FlowCard(active: hookOn && defaultProvider != nil,
                         providerName: defaultProvider?.name ?? "no provider",
                         symbol: defaultSymbol,
                         kind: defaultProvider?.kind,
                         accent: defaultProvider?.accent ?? Palette.other)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
            }

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
                SectionTitle(text: "Plain claude", symbol: "terminal.fill", color: Palette.terminal.a)
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
                            .buttonStyle(GradientButtonStyle(accent: Palette.warning))
                            .disabled(store.terminalBusy)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.12)))
                }
            } header: {
                SectionTitle(text: "Settings that override this", symbol: "exclamationmark.shield.fill",
                             color: store.overrides.isEmpty ? Color.green : Color.orange)
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
                SectionTitle(text: "Good to know", symbol: "lightbulb.fill", color: Palette.gold.a)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Backdrop(accent: Palette.terminal))
        .tint(Palette.terminal.a)
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

/// Shows what happens when you type claude: with the hook on, the cable runs to the chosen provider.
@MainActor
struct FlowCard: View {
    let active: Bool
    let providerName: String
    let symbol: String
    let kind: ProviderKind?
    let accent: Accent

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func start() {
        withAnimation(.none) { phase = 0 }
        if active && !reduceMotion {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = -12
            }
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let line: AnyShapeStyle = active ? AnyShapeStyle(accent.gradient) : AnyShapeStyle(Color.gray.opacity(0.45))
        return VStack(spacing: 14) {
            HStack(spacing: 0) {
                node(title: "claude", subtitle: "what you type", symbol: "chevron.right.square.fill",
                     accent: Palette.terminal, dim: false, kind: nil)
                HorizontalLine()
                    .stroke(line, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 10], dashPhase: phase))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .offset(y: -14)
                node(title: providerName, subtitle: active ? "where it goes" : "not connected", symbol: symbol,
                     accent: active ? accent : Palette.other, dim: !active, kind: kind)
            }
            Text(active ? "Typing claude in Terminal runs Claude Code with \(providerName)."
                        : "Plain claude ignores this app and uses your shell's own settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(shape.fill(Color(nsColor: .controlBackgroundColor).opacity(0.7)))
        .overlay(shape.strokeBorder(
            LinearGradient(colors: [Palette.terminal.a.opacity(0.5), accent.b.opacity(active ? 0.5 : 0.15)],
                           startPoint: .leading, endPoint: .trailing),
            lineWidth: 1.5))
        .onAppear { start() }
        .onChange(of: active) { _, _ in start() }
        .accessibilityElement(children: .combine)
    }

    private func node(title: String, subtitle: String, symbol: String, accent: Accent, dim: Bool, kind: ProviderKind?) -> some View {
        VStack(spacing: 6) {
            GradientTile(symbol: symbol, accent: accent, size: 60, kind: kind)
                .opacity(dim ? 0.6 : 1.0)
            Text(title)
                .font(.system(.headline, design: .rounded))
                .lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 130)
    }
}
