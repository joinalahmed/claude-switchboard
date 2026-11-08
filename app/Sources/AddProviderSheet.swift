import SwiftUI

@MainActor
struct AddProviderSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var template: Template? = nil
    @State private var name = ""
    @State private var values: [String: String] = [:]
    @State private var secrets: [String: String] = [:]
    @State private var makeDefault = false
    @State private var busy = false
    @State private var error: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let t = template {
                formView(t)
            } else {
                pickerView
            }
        }
        .frame(width: 580, height: 580)
    }

    // MARK: Step 1: choose a type

    private var pickerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                GradientTile(symbol: "plus", accent: Palette.brand, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("New provider")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Where should Claude Code send its requests?")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
            .background(
                LinearGradient(colors: [Palette.brand.a.opacity(0.16), Palette.brand.b.opacity(0.06)],
                               startPoint: .leading, endPoint: .trailing)
            )
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                    ForEach(store.templates) { t in
                        Button {
                            choose(t)
                        } label: {
                            TemplateCard(template: t)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(14)
        }
    }

    private func choose(_ t: Template) {
        template = t
        name = suggestedName(for: t.name)
        var v: [String: String] = [:]
        for f in t.fields where f.kind == .plain { v[f.name] = f.defaultValue }
        values = v
        secrets = [:]
        error = nil
    }

    private func suggestedName(for base: String) -> String {
        if store.provider(named: base) == nil { return base }
        var n = 2
        while store.provider(named: "\(base)-\(n)") != nil { n += 1 }
        return "\(base)-\(n)"
    }

    // MARK: Step 2: fill in the details

    private var nameProblem: String? {
        if name.isEmpty { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        if name.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return "Use letters, numbers, - and _ only."
        }
        if name.hasPrefix("-") || name.hasPrefix("_") { return "Start with a letter or number." }
        if Catalog.reserved.contains(name) { return "\"\(name)\" is a command name. Pick another."}
        if store.provider(named: name) != nil { return "A provider named \(name) already exists." }
        return nil
    }

    private func isMissing(_ f: Field) -> Bool {
        if !f.required { return false }
        if f.kind == .plain { return (values[f.name] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
        return (secrets[f.name] ?? "").isEmpty
    }

    private func canCreate(_ t: Template) -> Bool {
        if name.isEmpty || nameProblem != nil || busy { return false }
        for f in t.fields where isMissing(f) { return false }
        return true
    }

    private func valueBinding(_ key: String) -> Binding<String> {
        return Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }

    private func secretBinding(_ key: String) -> Binding<String> {
        return Binding(get: { secrets[key] ?? "" }, set: { secrets[key] = $0 })
    }

    private func create(_ t: Template) {
        busy = true
        error = nil
        let n = name
        let vals = values
        let secs = secrets
        let def = makeDefault
        Task {
            let err = await store.saveProvider(name: n, template: t.name, values: vals,
                                               secrets: secs, makeDefault: def, replace: false)
            busy = false
            if let err = err {
                error = err
            } else {
                store.selection = .provider(n)
                store.show("Added \(n)")
                dismiss()
            }
        }
    }

    private func formView(_ t: Template) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                GradientTile(symbol: t.symbol, accent: t.accent, size: 46, kind: t.kind)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.name).font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(t.summary).foregroundStyle(.secondary).font(.callout)
                }
                Spacer()
            }
            .padding(20)
            .background(
                LinearGradient(colors: [t.accent.a.opacity(0.18), t.accent.b.opacity(0.06)],
                               startPoint: .leading, endPoint: .trailing)
            )

            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("Required"))
                    if let p = nameProblem {
                        Label(p, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
                if !t.fields.isEmpty {
                    Section("Details") {
                        ForEach(t.fields) { f in
                            if f.kind == .secret {
                                SecureField(f.title, text: secretBinding(f.name),
                                            prompt: Text(f.placeholder))
                            } else {
                                TextField(f.title, text: valueBinding(f.name),
                                          prompt: Text(f.placeholder))
                            }
                        }
                    }
                    if t.fields.contains(where: { $0.kind == .secret }) {
                        Section {
                            Label("Keys are saved in your macOS Keychain, never in the provider file.",
                                  systemImage: "lock.fill")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section {
                        Text("Nothing to fill in. The provider file is created ready to edit.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Toggle("Make this the default provider", isOn: $makeDefault)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .tint(t.accent.a)

            Divider()
            HStack {
                Button("Back") { template = nil; error = nil }
                    .disabled(busy)
                if let e = error {
                    Text(e)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create provider") { create(t) }
                    .buttonStyle(GradientButtonStyle(accent: t.accent))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate(t))
            }
            .padding(14)
        }
    }
}

@MainActor
struct TemplateCard: View {
    let template: Template
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let accent = template.accent
        return HStack(alignment: .top, spacing: 12) {
            GradientTile(symbol: template.symbol, accent: accent, size: 38, kind: template.kind)
            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(template.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .background(
            ZStack {
                shape.fill(Color(nsColor: .controlBackgroundColor))
                shape.fill(LinearGradient(colors: [accent.a.opacity(hovering ? 0.2 : 0.09), accent.b.opacity(hovering ? 0.08 : 0.02)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        )
        .overlay(shape.strokeBorder(accent.a.opacity(hovering ? 0.7 : 0.25), lineWidth: hovering ? 1.5 : 1))
        .contentShape(shape)
        .hoverLift(accent.a)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .accessibilityElement(children: .combine)
    }
}
