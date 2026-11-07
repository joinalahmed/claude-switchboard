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
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            DetailRouter()
        }
        .sheet(isPresented: $store.showAdd) {
            AddProviderSheet()
                .environmentObject(store)
        }
        .overlay(alignment: .bottom) {
            if let message = store.toast {
                Text(message)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 6, y: 2)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.toast)
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
        case .some(.terminal):
            TerminalView()
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

    var body: some View {
        if store.loaded && store.providers.isEmpty {
            ContentUnavailableView {
                Label("No providers yet", systemImage: "terminal")
            } description: {
                Text("A provider tells Claude Code where to send requests: Anthropic, Vertex AI, Bedrock, or your own gateway.")
            } actions: {
                Button("Add a provider") { store.showAdd = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ContentUnavailableView("Choose a provider", systemImage: "sidebar.left",
                                   description: Text("Pick one from the sidebar to launch Claude Code with it."))
        }
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
                Label("Terminal", systemImage: "terminal")
                    .tag(SidebarItem.terminal)
                Label("Usage", systemImage: "chart.bar.xaxis")
                    .tag(SidebarItem.usage)
                Label("Health check", systemImage: "stethoscope")
                    .tag(SidebarItem.health)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    store.showAdd = true
                } label: {
                    Label("Add provider", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                Spacer()
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: store.dir))
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("Show the providers folder in Finder")
                .accessibilityLabel("Show providers folder")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
}

@MainActor
struct ProviderRow: View {
    let provider: Provider

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: provider.status.symbol)
                .foregroundStyle(provider.status.color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(provider.name)
                Text(provider.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if provider.isDefault {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .help("Default provider")
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(provider.name), \(provider.status.label)\(provider.isDefault ? ", default" : "")")
    }
}

@MainActor
struct MenuBarContent: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Launch in \((store.folder as NSString).abbreviatingWithTildeInPath)")
        ForEach(store.providers) { p in
            Button(p.isDefault ? "\(p.name) (default)" : p.name) {
                store.launch(p.name)
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
