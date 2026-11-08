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

    /// One color per provider. Two providers of the same type would look alike, so the second gets its own hue.
    private func colors(for names: [String]) -> [String: Accent] {
        var result: [String: Accent] = [:]
        var seen: Set<String> = []
        for n in names {
            if n == UsageScanner.other {
                result[n] = Palette.other
                continue
            }
            let p = store.provider(named: n)
            let key = p?.templateName ?? n
            if seen.contains(key) {
                result[n] = Palette.hashed(n)
            } else {
                seen.insert(key)
                result[n] = Palette.accent(template: p?.templateName, name: n)
            }
        }
        return result
    }

    private func value(_ d: DailyUsage) -> Int {
        switch metric {
        case .requests: return d.requests
        case .output: return d.output
        case .input: return d.input
        }
    }

    private func value(_ p: ProviderUsage) -> Int {
        switch metric {
        case .requests: return p.requests
        case .output: return p.output
        case .input: return p.input
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
        .background(Backdrop(accent: Palette.usage))
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
        VStack(spacing: 14) {
            GradientTile(symbol: "chart.bar.xaxis", accent: Palette.usage, size: 64)
            Text("No usage in this period")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            if !report.sourceFound {
                Text("Claude Code's session files weren't found in ~/.claude/projects yet.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Nothing recorded for \(store.usageRange.label.lowercased()). Pick a longer period, or run Claude Code and come back.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func content(_ report: UsageReport) -> some View {
        let names = report.providers.map { $0.provider }
        let colorMap = colors(for: names)
        return Form {
            Section {
                tiles(report)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section {
                Picker("Show", selection: $metric) {
                    ForEach(UsageMetric.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                shareRow(report, names: names, colorMap: colorMap)
            } header: {
                SectionTitle(text: "Share by provider", symbol: "chart.pie.fill", color: Palette.usage.a)
            }

            Section {
                dailyChart(report, names: names, colorMap: colorMap)
            } header: {
                SectionTitle(text: "Per day", symbol: "calendar", color: Palette.usage.b)
            }

            Section {
                ForEach(report.providers) { p in
                    providerRow(p, total: report.totalRequests, accent: colorMap[p.provider] ?? Palette.other)
                }
            } header: {
                SectionTitle(text: "By provider", symbol: "square.stack.3d.up.fill", color: Palette.usage.a)
            }

            if !report.models.isEmpty {
                Section {
                    ForEach(report.models.prefix(12)) { m in
                        HStack {
                            Circle()
                                .fill((colorMap[m.provider] ?? Palette.other).gradient)
                                .frame(width: 10, height: 10)
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
                } header: {
                    SectionTitle(text: "By model", symbol: "cpu.fill", color: Palette.usage.b)
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
        .scrollContentBackground(.hidden)
        .tint(Palette.usage.a)
    }

    private func tiles(_ report: UsageReport) -> some View {
        HStack(spacing: 12) {
            StatTile(title: "Requests", value: report.totalRequests.formatted(),
                     symbol: "arrow.up.arrow.down", accent: Palette.sky)
            StatTile(title: "Input tokens", value: compactCount(report.totalInput),
                     symbol: "arrow.down.to.line", accent: Palette.violet)
            StatTile(title: "Output tokens", value: compactCount(report.totalOutput),
                     symbol: "arrow.up.to.line", accent: Palette.usage)
            StatTile(title: "Read from cache", value: compactCount(report.totalCached),
                     symbol: "memorychip", accent: Palette.health)
        }
    }

    private func shareRow(_ report: UsageReport, names: [String], colorMap: [String: Accent]) -> some View {
        let total = report.providers.reduce(0) { $0 + value($1) }
        return HStack(alignment: .center, spacing: 22) {
            Chart(report.providers) { p in
                SectorMark(angle: .value("Share", value(p)),
                           innerRadius: .ratio(0.62),
                           angularInset: 2)
                    .cornerRadius(5)
                    .foregroundStyle(by: .value("Provider", p.provider))
            }
            .chartForegroundStyleScale(domain: names, range: names.map { (colorMap[$0] ?? Palette.other).a })
            .chartLegend(.hidden)
            .frame(width: 150, height: 150)
            .overlay {
                VStack(spacing: 0) {
                    Text(compactCount(total))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(metric.rawValue.lowercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(report.providers) { p in
                    HStack(spacing: 8) {
                        Circle()
                            .fill((colorMap[p.provider] ?? Palette.other).gradient)
                            .frame(width: 10, height: 10)
                        Text(p.provider)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(percent(value(p), of: total))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
    }

    private func percent(_ n: Int, of total: Int) -> String {
        if total <= 0 { return "0%" }
        return "\(Int((Double(n) / Double(total) * 100).rounded()))%"
    }

    private func dailyChart(_ report: UsageReport, names: [String], colorMap: [String: Accent]) -> some View {
        Chart(report.daily) { d in
            BarMark(x: .value("Day", d.day, unit: .day),
                    y: .value(metric.rawValue, value(d)))
                .cornerRadius(4)
                .foregroundStyle(by: .value("Provider", d.provider))
        }
        .chartForegroundStyleScale(domain: names, range: names.map { (colorMap[$0] ?? Palette.other).a })
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 220)
        .padding(.vertical, 4)
    }

    private func providerRow(_ p: ProviderUsage, total: Int, accent: Accent) -> some View {
        let share = total > 0 ? Double(p.requests) / Double(total) : 0
        return HStack(alignment: .top, spacing: 12) {
            GradientTile(symbol: symbol(for: p.provider), accent: accent, size: 34,
                         kind: store.provider(named: p.provider)?.kind)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(p.provider).font(.headline)
                    Spacer()
                    Text("\(p.requests.formatted()) requests").monospacedDigit()
                }
                ShareBar(fraction: share, accent: accent)
                HStack {
                    Text("Input \(compactCount(p.input))  ·  Output \(compactCount(p.output))  ·  Cached \(compactCount(p.cached))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(p.sessions.formatted()) \(p.sessions == 1 ? "session" : "sessions")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let d = p.lastUsed {
                    Text("Last used \(d.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func symbol(for provider: String) -> String {
        if provider == UsageScanner.other { return "questionmark" }
        let p = store.provider(named: provider)
        return store.templates.first(where: { $0.name == p?.templateName })?.symbol ?? "terminal"
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
