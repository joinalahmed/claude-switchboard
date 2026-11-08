import SwiftUI

/// The switch itself: pick the provider every new Claude Code session uses.
@MainActor
struct SwitchView: View {
    @EnvironmentObject var store: Store
    @State private var confirmRemove = false
    @State private var confirmRelease = false
    @State private var askImportName = false
    @State private var importName = ""
    @State private var importError: String? = nil

    private var status: SwitchStatus? { store.status }

    private var active: Provider? {
        guard let name = status?.active, !name.isEmpty else { return nil }
        return store.provider(named: name)
    }

    private var inEffect: Bool { status?.inEffect ?? false }

    private var activeSymbol: String {
        return store.templates.first(where: { $0.name == active?.templateName })?.symbol ?? active?.kind?.symbol ?? "terminal"
    }

    private var hookBinding: Binding<Bool> {
        return Binding(
            get: { status?.hookInstalled ?? false },
            set: { on in Task { await store.setHook(on) } }
        )
    }

    private var columns: [GridItem] {
        return [GridItem(.adaptive(minimum: 215, maximum: 320), spacing: 12)]
    }

    var body: some View {
        Form {
            Section {
                FlowCard(active: inEffect,
                         providerName: active?.name ?? (status?.active.isEmpty == false ? status!.active : "no provider"),
                         symbol: activeSymbol,
                         kind: active?.kind,
                         accent: active?.accent ?? Palette.other)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 2, trailing: 0))
                    .listRowBackground(Color.clear)
                StatusLine(status: status, provider: active)
                    .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section {
                if store.providers.isEmpty {
                    HStack {
                        Text("No providers yet.").foregroundStyle(.secondary)
                        Button("Add one") { store.showAdd = true }
                            .buttonStyle(GradientButtonStyle(accent: Palette.brand))
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.providers) { p in
                            ProviderPick(provider: p,
                                         symbol: store.templates.first(where: { $0.name == p.templateName })?.symbol ?? "terminal",
                                         selected: p.isActive,
                                         switching: store.switching == p.name,
                                         disabled: store.switching != nil || store.switchBusy) {
                                Task { await store.activate(p.name) }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            } header: {
                SectionTitle(text: "Choose the provider for claude", symbol: "arrow.triangle.swap", color: Palette.terminal.a)
            } footer: {
                Text("Click a provider to switch. Switchboard writes its variables into Claude Code's own settings file, so Terminal, iTerm, VS Code and other editors all follow it. Keys stay in your Keychain; Claude Code asks ccp for them when it needs one.")
            }

            if let s = status, s.state == .foreign || s.state == .drift || (s.state == .stale && !s.keys.isEmpty) {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.settingsName)
                            .font(.headline)
                        Text(s.keys.joined(separator: "\n"))
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                    HStack(spacing: 10) {
                        Label(s.state == .drift
                              ? "These changed after you switched. They override your choice."
                              : "These were set by hand. They decide what claude uses until you switch.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        if s.state != .drift {
                            Button("Keep as a provider…") {
                                importName = suggestedImportName()
                                importError = nil
                                askImportName = true
                            }
                            .buttonStyle(GradientButtonStyle(accent: Palette.warning))
                        } else {
                            Button("Re-apply \(s.active)") { Task { await store.reapply() } }
                                .buttonStyle(GradientButtonStyle(accent: Palette.warning))
                        }
                        Button("Remove them…") { confirmRemove = true }
                    }
                    .disabled(store.switchBusy || store.switching != nil)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.12)))
                } header: {
                    SectionTitle(text: "Settings that get in the way", symbol: "exclamationmark.shield.fill", color: Color.orange)
                } footer: {
                    Text("Only the variable names are shown. Switching to a provider replaces these; a copy of the file is kept next to it as settings.json.ccp-backup.")
                }
            }

            Section {
                Toggle("Count plain claude launches in Usage", isOn: hookBinding)
                    .disabled(status == nil || store.switchBusy)
                if let s = status, !s.active.isEmpty {
                    HStack {
                        Text("Stop managing Claude Code's provider")
                        Spacer()
                        Button("Hand back…") { confirmRelease = true }
                            .disabled(store.switchBusy || store.switching != nil)
                    }
                }
            } header: {
                SectionTitle(text: "More", symbol: "ellipsis.circle.fill", color: Palette.terminal.a)
            } footer: {
                Text("The Usage switch adds a small claude function to your shell profile so each launch is recorded. Switching providers never needs it. Handing back removes everything Switchboard wrote from Claude Code's settings.")
            }

            Section {
                Label("Sessions that are already open keep the provider they started with. Start a new one to switch.",
                      systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Label("One session with another provider, without switching: ccp NAME in Terminal, or Launch on its page.",
                      systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } header: {
                SectionTitle(text: "Good to know", symbol: "lightbulb.fill", color: Palette.gold.a)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Backdrop(accent: active?.accent ?? Palette.terminal))
        .tint(Palette.terminal.a)
        .navigationTitle("Switch")
        .navigationSubtitle("Which provider claude uses")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.refreshSwitch() }
                } label: {
                    Label("Check again", systemImage: "arrow.clockwise")
                }
                .disabled(store.switchBusy)
            }
        }
        .task { await store.refreshSwitch() }
        .confirmationDialog("Remove these variables from Claude Code's settings?",
                            isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { Task { await store.removeOverrides() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your other settings stay as they are. A copy of the file is kept next to it.")
        }
        .confirmationDialog("Hand Claude Code's provider back?",
                            isPresented: $confirmRelease, titleVisibility: .visible) {
            Button("Hand back", role: .destructive) { Task { await store.release() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Everything Switchboard wrote is removed from Claude Code's settings. Your providers stay; nothing is active until you pick one again.")
        }
        .alert("Keep these settings as a provider", isPresented: $askImportName) {
            TextField("Name", text: $importName)
            Button("Save") {
                let n = importName
                Task {
                    if let err = await store.importCurrent(as: n) {
                        importError = err
                        askImportName = true
                    }
                }
            }
            .disabled(importName.isEmpty)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(importError ?? "The variables now in \(status?.settingsName ?? "settings.json") become a provider you can switch to and from. Keys move to your Keychain.")
        }
    }

    private func suggestedImportName() -> String {
        var base = "current"
        for k in status?.keys ?? [] {
            if k == "CLAUDE_CODE_USE_BEDROCK" { base = "bedrock" }
            else if k == "CLAUDE_CODE_USE_VERTEX" { base = "vertex" }
            else if k == "CLAUDE_CODE_USE_FOUNDRY" { base = "foundry" }
            else if k == "ANTHROPIC_BASE_URL" && base == "current" { base = "gateway" }
        }
        if store.provider(named: base) == nil { return base }
        var n = 2
        while store.provider(named: "\(base)-\(n)") != nil { n += 1 }
        return "\(base)-\(n)"
    }
}

/// One line under the flow card that says, in words, what claude will do right now.
@MainActor
private struct StatusLine: View {
    let status: SwitchStatus?
    let provider: Provider?

    private var symbol: String {
        guard let s = status else { return "circle.dotted" }
        switch s.state {
        case .synced: return s.active.isEmpty ? "circle" : "checkmark.circle.fill"
        case .drift, .stale: return "exclamationmark.triangle.fill"
        case .foreign: return "hand.raised.fill"
        case .unset: return "circle"
        }
    }

    private var color: Color {
        guard let s = status else { return .secondary }
        switch s.state {
        case .synced: return s.active.isEmpty ? .secondary : .green
        case .drift, .stale: return .orange
        case .foreign: return .orange
        case .unset: return .secondary
        }
    }

    private var text: String {
        guard let s = status else { return "Checking what Claude Code is set to…" }
        switch s.state {
        case .synced:
            if s.active.isEmpty { return "No provider is active. Claude Code uses its own sign-in." }
            if provider == nil { return "Claude Code is set to \(s.active), but that provider no longer exists. Pick another." }
            return "Claude Code is set to \(s.active). Every new session uses it, wherever you start one."
        case .drift:
            return "\(s.settingsName) changed after you switched to \(s.active). Re-apply it, or remove the changes below."
        case .stale:
            return "\(s.active) is chosen but hasn't been applied to Claude Code yet. Click it below to apply."
        case .foreign:
            return "No provider is active. \(s.settingsName) sets one by hand; keep it as a provider or switch to another below."
        case .unset:
            return "No provider is active. Claude Code uses its own sign-in. Pick one below."
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if status == nil {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: symbol).foregroundStyle(color)
            }
            Text(text)
                .foregroundStyle(status == nil ? Color.secondary : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }
}

/// A provider as a card you click to make it the active one.
@MainActor
struct ProviderPick: View {
    let provider: Provider
    let symbol: String
    let selected: Bool
    let switching: Bool
    let disabled: Bool
    let action: () -> Void
    @State private var hovering = false

    private var ready: Bool { provider.status == .ready }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let accent = provider.accent
        return Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                GradientTile(symbol: symbol, accent: accent, size: 42, kind: provider.kind)
                VStack(alignment: .leading, spacing: 3) {
                    Text(provider.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let k = provider.kind {
                        Text(k.vendor)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent.a)
                            .lineLimit(1)
                    }
                    Text(provider.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !ready {
                        Label(provider.status.label, systemImage: provider.status.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(provider.status.color)
                    }
                }
                Spacer(minLength: 0)
                ZStack {
                    if switching {
                        ProgressView().controlSize(.small)
                    } else if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.white, accent.a)
                            .shadow(color: accent.a.opacity(0.5), radius: 5)
                    } else {
                        Circle()
                            .strokeBorder(Color.secondary.opacity(hovering ? 0.6 : 0.3), lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                    }
                }
                .frame(width: 24, height: 24)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
            .background(
                ZStack {
                    shape.fill(Color(nsColor: .controlBackgroundColor))
                    shape.fill(LinearGradient(colors: [accent.a.opacity(selected ? 0.26 : (hovering ? 0.18 : 0.08)),
                                                       accent.b.opacity(selected ? 0.12 : 0.02)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            )
            .overlay(shape.strokeBorder(selected ? AnyShapeStyle(accent.gradient) : AnyShapeStyle(accent.a.opacity(hovering ? 0.6 : 0.22)),
                                        lineWidth: selected ? 2 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(disabled || selected || !ready)
        .opacity(ready ? 1.0 : 0.65)
        .hoverLift(accent.a)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selected)
        .help(ready ? (selected ? "\(provider.name) is what claude uses now" : "Switch claude to \(provider.name)")
                    : "Finish setting up \(provider.name) on its page first")
        .accessibilityLabel("\(provider.name), \(provider.status.label)\(selected ? ", active" : "")")
    }
}

/// Shows what happens when you type claude: with a provider active, the cable runs to it.
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
        return HStack(spacing: 0) {
            node(title: "claude", subtitle: "Terminal, editors", symbol: "chevron.right.square.fill",
                 accent: Palette.terminal, dim: false, kind: nil)
            HorizontalLine()
                .stroke(line, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 10], dashPhase: phase))
                .frame(height: 4)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .offset(y: -14)
            node(title: providerName, subtitle: active ? "where requests go" : "not connected", symbol: symbol,
                 accent: active ? accent : Palette.other, dim: !active, kind: kind)
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
        .onChange(of: providerName) { _, _ in start() }
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
        .frame(width: 140)
    }
}
