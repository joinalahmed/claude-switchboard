import SwiftUI
import AppKit

// MARK: - Colors

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue: Double(hex & 0xFF) / 255.0,
                  opacity: 1.0)
    }
}

/// Two colors that belong together. Every provider type, and every tool in the sidebar, has one.
struct Accent: Equatable {
    var a: Color
    var b: Color

    var gradient: LinearGradient {
        return LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum Palette {
    static let brand = Accent(a: Color(hex: 0x7C5CFF), b: Color(hex: 0xFF5C9D))

    static let coral = Accent(a: Color(hex: 0xFF8A5B), b: Color(hex: 0xE5484D))
    static let rose = Accent(a: Color(hex: 0xFF6FA5), b: Color(hex: 0xB8338C))
    static let sky = Accent(a: Color(hex: 0x3B82F6), b: Color(hex: 0x06B6D4))
    static let amber = Accent(a: Color(hex: 0xF59E0B), b: Color(hex: 0xEA580C))
    static let teal = Accent(a: Color(hex: 0x0D9488), b: Color(hex: 0x2DD4BF))
    static let violet = Accent(a: Color(hex: 0x8B5CF6), b: Color(hex: 0xD946EF))
    static let lime = Accent(a: Color(hex: 0x16A34A), b: Color(hex: 0x84CC16))
    static let slate = Accent(a: Color(hex: 0x6366F1), b: Color(hex: 0x64748B))

    static let terminal = Accent(a: Color(hex: 0x4F46E5), b: Color(hex: 0x0EA5E9))
    static let usage = Accent(a: Color(hex: 0xEC4899), b: Color(hex: 0xF97316))
    static let health = Accent(a: Color(hex: 0x10B981), b: Color(hex: 0x06B6D4))
    static let gold = Accent(a: Color(hex: 0xFBBF24), b: Color(hex: 0xF59E0B))
    static let other = Accent(a: Color(hex: 0x94A3B8), b: Color(hex: 0x64748B))

    static let good = Accent(a: Color(hex: 0x10B981), b: Color(hex: 0x14B8A6))
    static let warning = Accent(a: Color(hex: 0xF59E0B), b: Color(hex: 0xF97316))
    static let danger = Accent(a: Color(hex: 0xF43F5E), b: Color(hex: 0xDC2626))

    /// The color of a provider: by its type, then by words in its name, then a stable hue made from the name.
    static func accent(template: String?, name: String) -> Accent {
        if let t = template, let hit = byTemplate(t) { return hit }
        if let hit = byWord(name) { return hit }
        return hashed(name)
    }

    private static func byTemplate(_ t: String) -> Accent? {
        switch t {
        case "anthropic": return coral
        case "anthropic-login": return rose
        case "vertex": return sky
        case "bedrock": return amber
        case "foundry": return teal
        case "gateway": return violet
        case "litellm": return lime
        case "custom": return slate
        default: return nil
        }
    }

    private static func byWord(_ name: String) -> Accent? {
        let n = name.lowercased()
        if n.contains("login") || n.contains("subscription") { return rose }
        if n.contains("vertex") || n.contains("gcp") || n.contains("google") { return sky }
        if n.contains("bedrock") || n.contains("aws") { return amber }
        if n.contains("foundry") || n.contains("azure") { return teal }
        if n.contains("litellm") { return lime }
        if n.contains("gateway") || n.contains("proxy") { return violet }
        if n.contains("anthropic") || n.contains("api") { return coral }
        return nil
    }

    /// Swift's own hashValue changes on every launch, so the hue is built from the characters instead.
    static func hashed(_ name: String) -> Accent {
        var sum = 0
        for u in name.unicodeScalars { sum = (sum &* 31 &+ Int(u.value)) % 360 }
        let h = Double(sum) / 360.0
        let h2 = (h + 0.09).truncatingRemainder(dividingBy: 1.0)
        return Accent(a: Color(hue: h, saturation: 0.65, brightness: 0.95),
                      b: Color(hue: h2, saturation: 0.78, brightness: 0.78))
    }
}

extension Provider {
    var accent: Accent {
        return Palette.accent(template: templateName, name: name)
    }
}

extension Template {
    var accent: Accent {
        return Palette.accent(template: name, name: name)
    }
}

// MARK: - Building blocks

/// A rounded square with a gradient, a soft highlight and a glow in its own color.
struct GradientTile: View {
    let symbol: String
    let accent: Accent
    var size: CGFloat = 32

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        return shape
            .fill(accent.gradient)
            .frame(width: size, height: size)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.02)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
            )
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.22), radius: 1, y: 1)
            )
            .shadow(color: accent.a.opacity(0.4), radius: size * 0.2, y: size * 0.08)
            .accessibilityHidden(true)
    }
}

/// A small pill of text with an optional icon.
struct Chip: View {
    let text: String
    var symbol: String? = nil
    var color: Color

    var body: some View {
        HStack(spacing: 4) {
            if let s = symbol {
                Image(systemName: s)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.15)))
    }
}

/// A pill that sits on a colored banner.
struct HeroChip: View {
    let text: String
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let s = symbol {
                Image(systemName: s)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.22)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
    }
}

/// A dot with a ring that keeps spreading out, for things that are live.
struct GlowDot: View {
    var color: Color
    var size: CGFloat = 8
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.4))
                .frame(width: size * 2.4, height: size * 2.4)
                .scaleEffect(pulse ? 1.0 : 0.4)
                .opacity(pulse ? 0.0 : 0.9)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .frame(width: size * 2.4, height: size * 2.4)
        .onAppear {
            if reduceMotion { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}

/// A header for a group of settings: a colored icon and a title.
struct SectionTitle: View {
    let text: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(text)
        }
        .font(.headline)
        .textCase(nil)
    }
}

/// A thin bar that shows a share of the whole.
struct ShareBar: View {
    let fraction: Double
    let accent: Accent

    var body: some View {
        GeometryReader { geo in
            let f = min(1.0, max(0.0, fraction))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.16))
                Capsule()
                    .fill(accent.gradient)
                    .frame(width: f > 0 ? max(5, geo.size.width * CGFloat(f)) : 0)
            }
        }
        .frame(height: 6)
    }
}

/// A big number on a colored card.
struct StatTile: View {
    let title: String
    let value: String
    let symbol: String
    let accent: Accent

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Color.white)
            Text(title)
                .font(.callout)
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(
            ZStack(alignment: .topTrailing) {
                shape.fill(accent.gradient)
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 90, height: 90)
                    .offset(x: 28, y: -34)
            }
            .clipShape(shape)
        )
        .shadow(color: accent.a.opacity(0.32), radius: 10, y: 5)
        .accessibilityElement(children: .combine)
    }
}

/// A white-on-color cable that loops across a banner. It is the app's one decorative flourish.
struct CableShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX - 10, y: rect.maxY * 0.82))
        p.addCurve(to: CGPoint(x: rect.maxX + 10, y: rect.maxY * 0.22),
                   control1: CGPoint(x: rect.width * 0.38, y: rect.maxY * 1.15),
                   control2: CGPoint(x: rect.width * 0.62, y: -rect.maxY * 0.1))
        return p
    }
}

struct CableDecoration: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                CableShape()
                    .stroke(Color.white.opacity(0.13), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                CableShape()
                    .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 9]))
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 130, height: 130)
                    .position(x: geo.size.width * 0.9, y: geo.size.height * 0.1)
                Circle()
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 2)
                    .frame(width: 70, height: 70)
                    .position(x: geo.size.width * 0.62, y: geo.size.height * 0.95)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A horizontal line, used for dashed connections.
struct HorizontalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// A soft wash of the page's color behind a screen.
struct Backdrop: View {
    let accent: Accent

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(colors: [accent.a.opacity(0.14), accent.b.opacity(0.05), Color.clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(accent.b.opacity(0.16))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: 280, y: -240)
            Circle()
                .fill(accent.a.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: -260, y: 320)
        }
        .clipped()
        .ignoresSafeArea()
    }
}

// MARK: - Buttons

/// The main button on a screen: a gradient pill that glows.
struct GradientButtonStyle: ButtonStyle {
    var accent: Accent

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        GradientButtonBody(configuration: configuration, accent: accent)
    }
}

private struct GradientButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let accent: Accent
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        let fill: AnyShapeStyle = enabled ? AnyShapeStyle(accent.gradient) : AnyShapeStyle(Color.gray.opacity(0.35))
        let glow: Color = enabled ? accent.a.opacity(configuration.isPressed ? 0.2 : 0.45) : Color.clear
        return configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(Color.white.opacity(enabled ? 0.3 : 0.0), lineWidth: 1))
            .shadow(color: glow, radius: configuration.isPressed ? 3 : 9, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A quieter button: tinted text on a tinted pill.
struct SoftButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        SoftButtonBody(configuration: configuration, color: color)
    }
}

private struct SoftButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let color: Color
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(enabled ? color : Color.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill((enabled ? color : Color.gray).opacity(configuration.isPressed ? 0.26 : 0.14)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A button that sits on a colored banner. `filled` makes it white.
struct HeroButtonStyle: ButtonStyle {
    var filled: Bool
    var tint: Color

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        HeroButtonBody(configuration: configuration, filled: filled, tint: tint)
    }
}

private struct HeroButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let filled: Bool
    let tint: Color
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(filled ? tint : Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(minWidth: 112)
            .background(Capsule().fill(filled ? Color.white : Color.white.opacity(0.2)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(filled ? 0.0 : 0.45), lineWidth: 1))
            .shadow(color: Color.black.opacity(filled ? 0.18 : 0.0), radius: 6, y: 3)
            .opacity(enabled ? 1.0 : 0.55)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Hover

struct HoverLift: ViewModifier {
    var color: Color
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? 1.018 : 1.0)
            .shadow(color: color.opacity(hovering ? 0.35 : 0.0), radius: hovering ? 12 : 0, y: 5)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverLift(_ color: Color) -> some View {
        modifier(HoverLift(color: color))
    }
}
