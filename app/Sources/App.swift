import SwiftUI
import AppKit

/// The app is started from a small launcher script, so it has to claim the foreground itself.
/// Without this the window stays inactive and SwiftUI buttons ignore clicks.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        bringForward()
        for delay in [0.3, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.bringForward()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if NSApp.keyWindow == nil { bringForward() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        bringForward()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func bringForward() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = NSApp.windows.first(where: { $0.canBecomeMain && $0.isVisible }) {
            w.makeKeyAndOrderFront(nil)
        }
    }
}

@main
@MainActor
struct SwitchboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup("Switchboard", id: "main") {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 860, minHeight: 560)
        }
        .defaultSize(width: 1040, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Provider…") { store.showAdd = true }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .toolbar) {
                Button("Refresh") { Task { await store.refresh() } }
                    .keyboardShortcut("r")
            }
        }

        MenuBarExtra("Switchboard", systemImage: "terminal") {
            MenuBarContent()
                .environmentObject(store)
        }
    }
}

@MainActor
struct RootView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 330)
        } detail: {
            DetailRouter()
        }
        .tint(Palette.brand.a)
        .sheet(isPresented: $store.showAdd) {
            AddProviderSheet()
                .environmentObject(store)
        }
        .overlay(alignment: .bottom) {
            if let message = store.toast {
                let accent = store.toastIsError ? Palette.danger : Palette.brand
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: store.toastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    Text(message)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .frame(maxWidth: 560)
                .background(Capsule().fill(accent.gradient))
                .shadow(color: accent.a.opacity(0.45), radius: 12, y: 5)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.toast)
    }
}

@MainActor
struct DetailRouter: View {
    @EnvironmentObject var store: Store

    var body: some View {
        switch store.selection {
        case .some(.provider(let name)):
            if let provider = store.provider(named: name) {
                ProviderDetailView(provider: provider)
                    .id(provider.name)
            } else {
                EmptyDetail()
            }
        case .some(.switcher):
            SwitchView()
        case .some(.usage):
            UsageView()
        case .some(.health):
            HealthView()
        case .none:
            EmptyDetail()
        }
    }
}

@MainActor
struct EmptyDetail: View {
    @EnvironmentObject var store: Store

    private let samples: [(String, String)] = [
        ("anthropic", "key"), ("vertex", "cloud"), ("bedrock", "square.stack.3d.up"), ("litellm", "arrow.triangle.branch")
    ]

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 14) {
                ForEach(Array(samples.enumerated()), id: \.offset) { i, item in
                    GradientTile(symbol: item.1, accent: Palette.accent(template: item.0, name: item.0), size: 58,
                                 kind: ProviderKind(templateName: item.0))
                        .rotationEffect(.degrees(i % 2 == 0 ? -6 : 6))
                        .offset(y: i % 2 == 0 ? 0 : 10)
                }
            }
            .padding(.bottom, 6)
            if store.loaded && store.providers.isEmpty {
                Text("Pick where Claude Code runs")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("A provider tells Claude Code where to send requests: Anthropic, Vertex AI, Bedrock, or your own gateway.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                Button {
                    store.showAdd = true
                } label: {
                    Label("Add a provider", systemImage: "plus")
                }
                .buttonStyle(GradientButtonStyle(accent: Palette.brand))
                .controlSize(.large)
            } else {
                Text("Choose a provider")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Pick one from the sidebar to launch Claude Code with it.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Backdrop(accent: Palette.brand))
    }
}

@MainActor
struct SidebarView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        List(selection: $store.selection) {
            Section("Providers") {
                ForEach(store.providers) { p in
                    ProviderRow(provider: p)
                        .tag(SidebarItem.provider(p.name))
                }
            }
            Section("Tools") {
                ToolRow(title: "Switch", subtitle: store.status?.active.isEmpty == false ? "claude uses \(store.status!.active)" : "Which provider claude uses",
                        symbol: "arrow.triangle.swap", accent: Palette.terminal)
                    .tag(SidebarItem.switcher)
                ToolRow(title: "Usage", subtitle: "Per provider", symbol: "chart.bar.xaxis", accent: Palette.usage)
                    .tag(SidebarItem.usage)
                ToolRow(title: "Health check", subtitle: "Find what gets in the way", symbol: "stethoscope", accent: Palette.health)
                    .tag(SidebarItem.health)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 10) {
                GradientTile(symbol: "bolt.horizontal.fill", accent: Palette.brand, size: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Switchboard")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Pick Claude Code's cloud")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    store.showAdd = true
                } label: {
                    Label("Add provider", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle(accent: Palette.brand))
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: store.dir))
                } label: {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Palette.brand.a)
                        .padding(8)
                        .background(Circle().fill(Palette.brand.a.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .help("Show the providers folder in Finder")
                .accessibilityLabel("Show providers folder")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

@MainActor
struct ToolRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Accent

    var body: some View {
        HStack(spacing: 10) {
            GradientTile(symbol: symbol, accent: accent, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

@MainActor
struct ProviderRow: View {
    @EnvironmentObject var store: Store
    let provider: Provider

    private var symbol: String {
        return store.templates.first(where: { $0.name == provider.templateName })?.symbol ?? "terminal"
    }

    var body: some View {
        HStack(spacing: 10) {
            GradientTile(symbol: symbol, accent: provider.accent, size: 30, kind: provider.kind)
                .overlay(alignment: .bottomTrailing) {
                    if provider.status != .ready {
                        Circle()
                            .fill(provider.status.color)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 2))
                            .offset(x: 3, y: 3)
                    }
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(provider.name)
                Text(provider.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if provider.isActive {
                HStack(spacing: 3) {
                    GlowDot(color: Color.green, size: 6)
                        .frame(width: 14, height: 14)
                    Text("active")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.green)
                }
                .help("claude uses this provider now")
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(provider.name), \(provider.status.label)\(provider.isActive ? ", active" : "")")
    }
}

@MainActor
struct MenuBarContent: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(store.status?.active.isEmpty == false ? "claude uses \(store.status!.active)" : "No provider is active")
        ForEach(store.providers) { p in
            Toggle(isOn: Binding(get: { p.isActive }, set: { on in if on { Task { await store.activate(p.name) } } })) {
                Text(p.name)
            }
            .disabled(p.status != .ready || store.switching != nil)
        }
        Divider()
        Menu("Launch in \((store.folder as NSString).abbreviatingWithTildeInPath)") {
            ForEach(store.providers) { p in
                Button(p.name) { store.launch(p.name) }
                    .disabled(p.needsSetup)
            }
        }
        Divider()
        Button("Open Switchboard") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        Divider()
        Button("Quit Switchboard") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
