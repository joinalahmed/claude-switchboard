import SwiftUI
import Charts

enum UsageMetric: String, CaseIterable, Identifiable {
    case requests = "Requests"
    case output = "Output tokens"
    case input = "Input tokens"
    var id: String { rawValue }
}

func compactCount(_ n: Int) -> String {
    return n.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
}

@MainActor
struct UsageView: View {
    @EnvironmentObject var store: Store
    @State private var metric: UsageMetric = .requests

    private let palette: [Color] = [.blue, .orange, .green, .purple, .pink, .teal, .yellow, .indigo]

    private func color(for provider: String) -> Color {
        if provider == UsageScanner.other { return .gray }
        if let i = store.providers.firstIndex(where: { $0.name == provider }) {
            return palette[i % palette.count]
        }
        return palette[abs(provider.hashValue) % palette.count]
    }

    private func value(_ d: DailyUsage) -> Int {
        switch metric {
        case .requests: return d.requests
        case .output: return d.output
        case .input: return d.input
        }
    }

    var body: some View {
        Group {
            if let report = store.usage {
                if report.providers.isEmpty {
                    empty(report)
                } else {
                    content(report)
                }
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Reading Claude Code's session files…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Usage")
        .navigationSubtitle("What each provider has been used for")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("Period", selection: $store.usageRange) {
                    ForEach(UsageRange.allCases) { r in
                        Text(r.label).tag(r)
                    }
                }
                .pickerStyle(.menu)
                Button {
                    Task { await store.loadUsage() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.usageLoading)
            }
        }
        .task { await store.loadUsage() }
        .onChange(of: store.usageRange) { _, _ in
            Task { await store.loadUsage() }
        }
    }

    @ViewBuilder
    private func empty(_ report: UsageReport) -> some View {
        ContentUnavailableView {
            Label("No usage in this period", systemImage: "chart.bar.xaxis")
        } description: {
            if !report.sourceFound {
                Text("Claude Code's session files weren't found in ~/.claude/projects yet.")
            } else {
                Text("Nothing recorded for \(store.usageRange.label.lowercased()). Pick a longer period, or run Claude Code and come back.")
            }
        }
    }

    private func content(_ report: UsageReport) -> some View {
        let names = report.providers.map { $0.provider }
        return Form {
            Section("Summary") {
                LabeledContent("Requests", value: report.totalRequests.formatted())
                LabeledContent("Input tokens", value: compactCount(report.totalInput))
                LabeledContent("Output tokens", value: compactCount(report.totalOutput))
                LabeledContent("Read from cache", value: compactCount(report.totalCached))
            }

            Section {
                Picker("Show", selection: $metric) {
                    ForEach(UsageMetric.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                Chart(report.daily) { d in
                    BarMark(x: .value("Day", d.day, unit: .day),
                            y: .value(metric.rawValue, value(d)))
                        .foregroundStyle(by: .value("Provider", d.provider))
                }
                .chartForegroundStyleScale(domain: names, range: names.map { color(for: $0) })
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 210)
                .padding(.vertical, 4)
            } header: {
                Text("Per day")
            }

            Section("By provider") {
                ForEach(report.providers) { p in
                    providerRow(p)
                }
            }

            if !report.models.isEmpty {
                Section("By model") {
                    ForEach(report.models.prefix(12)) { m in
                        HStack {
                            Circle().fill(color(for: m.provider)).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.model).lineLimit(1).truncationMode(.middle)
                                Text(m.provider).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(m.requests.formatted()) requests")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }

            Section {
                Label {
                    Text(footnote(report))
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func providerRow(_ p: ProviderUsage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(color(for: p.provider)).frame(width: 10, height: 10).padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(p.provider).font(.headline)
                Text("Input \(compactCount(p.input))  ·  Output \(compactCount(p.output))  ·  Cached \(compactCount(p.cached))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let d = p.lastUsed {
                    Text("Last used \(d.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(p.requests.formatted()) requests").monospacedDigit()
                Text("\(p.sessions.formatted()) \(p.sessions == 1 ? "session" : "sessions")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func footnote(_ report: UsageReport) -> String {
        var s = "Counts come from Claude Code's own session files. Cost isn't estimated, because prices differ by provider and model."
        if report.runsLogged == 0 {
            s += " Nothing has been launched through ccp yet, so everything shows as \"\(UsageScanner.other)\". Sessions started from this app, or from Terminal with the claude hook on, are credited to their provider."
        } else if report.providers.contains(where: { $0.isUnattributed }) {
            s += " \"\(UsageScanner.other)\" is usage from sessions that weren't started through ccp."
        }
        return s
    }
}
