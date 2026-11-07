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

    var body: some View {
        List {
            if running && sections.isEmpty {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Checking your setup…").foregroundStyle(.secondary)
                }
            }
            ForEach(sections) { s in
                Section(s.title) {
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
                }
            }
            if ranOnce && sections.isEmpty && !running {
                Text("Nothing to report.")
                    .foregroundStyle(.secondary)
            }
        }
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
