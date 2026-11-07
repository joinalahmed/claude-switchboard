import SwiftUI

@MainActor
struct HealthView: View {
    @EnvironmentObject var store: Store
    @State private var sections: [DoctorSection] = []
    @State private var running = false
    @State private var ranOnce = false

    private func run() async {
        running = true
        sections = await store.doctor()
        running = false
        ranOnce = true
    }

    private var items: [DoctorItem] {
        return sections.flatMap { $0.items }
    }

    private var fails: Int { items.filter { $0.level == .fail }.count }
    private var warns: Int { items.filter { $0.level == .warn }.count }
    private var oks: Int { items.filter { $0.level == .ok }.count }

    private var bannerAccent: Accent {
        if fails > 0 { return Palette.danger }
        if warns > 0 { return Palette.warning }
        return Palette.good
    }

    private var bannerSymbol: String {
        if fails > 0 { return "xmark.octagon.fill" }
        if warns > 0 { return "exclamationmark.triangle.fill" }
        return "checkmark.seal.fill"
    }

    private var bannerTitle: String {
        if fails > 0 { return fails == 1 ? "1 problem to fix" : "\(fails) problems to fix" }
        if warns > 0 { return warns == 1 ? "1 thing to look at" : "\(warns) things to look at" }
        return "All clear"
    }

    private var bannerText: String {
        if fails > 0 || warns > 0 { return "Something here could stop Claude Code from using the provider you picked." }
        return "Nothing is in the way of the provider you picked."
    }

    private func level(of s: DoctorSection) -> DoctorItem.Level {
        if s.items.contains(where: { $0.level == .fail }) { return .fail }
        if s.items.contains(where: { $0.level == .warn }) { return .warn }
        return .ok
    }

    private var banner: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return ZStack {
            shape.fill(bannerAccent.gradient)
            CableDecoration()
            HStack(spacing: 16) {
                Image(systemName: bannerSymbol)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
                VStack(alignment: .leading, spacing: 5) {
                    Text(bannerTitle)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                    Text(bannerText)
                        .foregroundStyle(Color.white.opacity(0.92))
                    HStack(spacing: 8) {
                        HeroChip(text: "\(oks) ok", symbol: "checkmark")
                        if warns > 0 { HeroChip(text: "\(warns) to look at", symbol: "exclamationmark") }
                        if fails > 0 { HeroChip(text: "\(fails) failing", symbol: "xmark") }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(22)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        .shadow(color: bannerAccent.a.opacity(0.35), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
    }

    var body: some View {
        List {
            if running && sections.isEmpty {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Checking your setup…").foregroundStyle(.secondary)
                }
            }
            if !sections.isEmpty {
                banner
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(sections) { s in
                Section {
                    ForEach(s.items) { item in
                        Label {
                            Text(item.text)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: item.level.symbol)
                                .foregroundStyle(item.level.color)
                        }
                    }
                } header: {
                    SectionTitle(text: s.title, symbol: level(of: s).symbol, color: level(of: s).color)
                }
            }
            if ranOnce && sections.isEmpty && !running {
                Text("Nothing to report.")
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Backdrop(accent: Palette.health))
        .tint(Palette.health.a)
        .navigationTitle("Health check")
        .navigationSubtitle("What could stop Claude Code from using the provider you pick")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await run() }
                } label: {
                    Label("Run again", systemImage: "arrow.clockwise")
                }
                .disabled(running)
            }
        }
        .task { await run() }
    }
}
