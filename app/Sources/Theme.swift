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

    static let coral = Accent(a: Color(hex: 0xE8825E), b: Color(hex: 0xB9482B))
    static let rose = Accent(a: Color(hex: 0xFF6FA5), b: Color(hex: 0xB8338C))
    static let sky = Accent(a: Color(hex: 0x4285F4), b: Color(hex: 0x1FA2E8))
    static let amber = Accent(a: Color(hex: 0xFF9900), b: Color(hex: 0xC2410C))
    static let teal = Accent(a: Color(hex: 0x0078D4), b: Color(hex: 0x2BC6D8))
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
        if let k = ProviderKind(template: template, name: name) { return k.accent }
        return hashed(name)
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
        return kind?.accent ?? Palette.hashed(name)
    }

    /// A "# kind:" header (written by `ccp import`) wins over the template and the name.
    var kind: ProviderKind? {
        if let h = kindHint, let k = ProviderKind(templateName: h) { return k }
        return ProviderKind(template: templateName, name: name)
    }
}

extension Template {
    var accent: Accent {
        return Palette.accent(template: name, name: name)
    }

    var kind: ProviderKind? {
        return ProviderKind(template: name, name: name)
    }
}

// MARK: - Provider looks

/// The kinds of provider that get their own mark, colors and background pattern.
enum ProviderKind: String {
    case anthropic, login, vertex, bedrock, foundry, gateway, litellm, custom

    init?(template: String?, name: String) {
        if let t = template, let k = ProviderKind(templateName: t) {
            self = k
            return
        }
        if let k = ProviderKind(word: name) {
            self = k
            return
        }
        return nil
    }

    init?(templateName t: String) {
        switch t {
        case "anthropic": self = .anthropic
        case "anthropic-login": self = .login
        case "vertex": self = .vertex
        case "bedrock": self = .bedrock
        case "foundry": self = .foundry
        case "gateway": self = .gateway
        case "litellm": self = .litellm
        case "custom": self = .custom
        default: return nil
        }
    }

    init?(word name: String) {
        let n = name.lowercased()
        if n.contains("login") || n.contains("subscription") { self = .login }
        else if n.contains("vertex") || n.contains("gcp") || n.contains("google") { self = .vertex }
        else if n.contains("bedrock") || n.contains("aws") { self = .bedrock }
        else if n.contains("foundry") || n.contains("azure") { self = .foundry }
        else if n.contains("litellm") { self = .litellm }
        else if n.contains("gateway") || n.contains("proxy") { self = .gateway }
        else if n.contains("anthropic") || n.contains("api") { self = .anthropic }
        else { return nil }
    }

    var accent: Accent {
        switch self {
        case .anthropic: return Palette.coral
        case .login: return Palette.rose
        case .vertex: return Palette.sky
        case .bedrock: return Palette.amber
        case .foundry: return Palette.teal
        case .gateway: return Palette.violet
        case .litellm: return Palette.lime
        case .custom: return Palette.slate
        }
    }

    /// Who runs it, in plain words.
    var vendor: String {
        switch self {
        case .anthropic: return "Anthropic API"
        case .login: return "Claude subscription"
        case .vertex: return "Google Cloud"
        case .bedrock: return "Amazon Web Services"
        case .foundry: return "Microsoft Azure"
        case .gateway: return "Your gateway"
        case .litellm: return "LiteLLM proxy"
        case .custom: return "Custom setup"
        }
    }

    /// A symbol for kinds that have no drawn mark.
    var symbol: String? {
        switch self {
        case .anthropic: return "key.fill"
        case .login: return "person.crop.circle.fill"
        case .custom: return "slider.horizontal.3"
        default: return nil
        }
    }
}

/// Simple marks drawn by hand. They are original shapes in each provider's colors, not the companies' logos.
struct VertexMarkShape: Shape {
    func path(in r: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y) }
        let top = pt(0.5, 0.1), left = pt(0.1, 0.82), right = pt(0.9, 0.82), mid = pt(0.5, 0.58)
        var p = Path()
        for a in [top, left, right] {
            p.move(to: mid)
            p.addLine(to: a)
        }
        p.move(to: left)
        p.addLine(to: right)
        let rad = r.width * 0.11
        for c in [top, left, right] {
            p.addEllipse(in: CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2))
        }
        let small = r.width * 0.07
        p.addEllipse(in: CGRect(x: mid.x - small, y: mid.y - small, width: small * 2, height: small * 2))
        return p
    }
}

struct BedrockMarkShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let rows: [(CGFloat, CGFloat)] = [(0.28, 0.44), (0.16, 0.68), (0.04, 0.92)]
        for (i, row) in rows.enumerated() {
            let y = r.minY + r.height * (0.08 + 0.31 * CGFloat(i))
            let box = CGRect(x: r.minX + r.width * row.0, y: y, width: r.width * row.1, height: r.height * 0.2)
            p.addRoundedRect(in: box, cornerSize: CGSize(width: r.width * 0.06, height: r.width * 0.06))
        }
        return p
    }
}

struct FoundryMarkShape: Shape {
    func path(in r: CGRect) -> Path {
        func hex(_ radius: CGFloat) -> Path {
            var h = Path()
            let c = CGPoint(x: r.midX, y: r.midY)
            for i in 0..<6 {
                let ang = CGFloat(i) * .pi / 3 - .pi / 2
                let q = CGPoint(x: c.x + radius * cos(ang), y: c.y + radius * sin(ang))
                if i == 0 { h.move(to: q) } else { h.addLine(to: q) }
            }
            h.closeSubpath()
            return h
        }
        var p = hex(r.width * 0.46)
        p.addPath(hex(r.width * 0.2))
        return p
    }
}

struct RouterMarkShape: Shape {
    func path(in r: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y) }
        var p = Path()
        p.move(to: pt(0.06, 0.5))
        p.addLine(to: pt(0.4, 0.5))
        for y in [CGFloat(0.14), 0.5, 0.86] {
            p.move(to: pt(0.4, 0.5))
            p.addCurve(to: pt(0.82, y), control1: pt(0.6, 0.5), control2: pt(0.62, y))
            let c = pt(0.88, y)
            p.addEllipse(in: CGRect(x: c.x - r.width * 0.06, y: c.y - r.width * 0.06, width: r.width * 0.12, height: r.width * 0.12))
        }
        return p
    }
}

struct GatewayMarkShape: Shape {
    func path(in r: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y) }
        var p = Path()
        p.move(to: pt(0.18, 0.9))
        p.addLine(to: pt(0.18, 0.45))
        p.addCurve(to: pt(0.82, 0.45), control1: pt(0.18, 0.0), control2: pt(0.82, 0.0))
        p.addLine(to: pt(0.82, 0.9))
        p.move(to: pt(0.05, 0.9))
        p.addLine(to: pt(0.95, 0.9))
        p.move(to: pt(0.5, 0.9))
        p.addLine(to: pt(0.5, 0.5))
        return p
    }
}

/// The glyph in a provider's tile.
struct ProviderMark: View {
    let kind: ProviderKind?
    let fallback: String
    let size: CGFloat

    var body: some View {
        let lw = max(1.6, size * 0.075)
        let style = StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
        return Group {
            switch kind {
            case .some(.vertex):
                VertexMarkShape().stroke(Color.white, style: style)
            case .some(.bedrock):
                BedrockMarkShape().fill(Color.white)
            case .some(.foundry):
                FoundryMarkShape().stroke(Color.white, style: style)
            case .some(.litellm):
                RouterMarkShape().stroke(Color.white, style: style)
            case .some(.gateway):
                GatewayMarkShape().stroke(Color.white, style: style)
            default:
                Image(systemName: kind?.symbol ?? fallback)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: size * 0.54, height: size * 0.54)
        .shadow(color: Color.black.opacity(0.22), radius: 1, y: 1)
    }
}

/// A faint pattern on a provider's banner that fits what the provider is.
struct ProviderMotif: View {
    let kind: ProviderKind?

    var body: some View {
        switch kind {
        case .some(let k):
            Canvas { ctx, size in
                draw(k, ctx: &ctx, size: size)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        case .none:
            CableDecoration()
        }
    }

    private func line(_ ctx: inout GraphicsContext, _ path: Path, _ opacity: Double, _ width: CGFloat) {
        ctx.stroke(path, with: .color(Color.white.opacity(opacity)), lineWidth: width)
    }

    private func dot(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat, _ opacity: Double) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Color.white.opacity(opacity)))
    }

    private func draw(_ k: ProviderKind, ctx: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        switch k {
        case .vertex:
            let pts: [CGPoint] = [CGPoint(x: w * 0.56, y: h * 0.22), CGPoint(x: w * 0.7, y: h * 0.62), CGPoint(x: w * 0.82, y: h * 0.2),
                                  CGPoint(x: w * 0.93, y: h * 0.55), CGPoint(x: w * 0.62, y: h * 0.92), CGPoint(x: w * 0.88, y: h * 0.9)]
            let edges: [(Int, Int)] = [(0, 1), (1, 2), (0, 2), (2, 3), (1, 3), (1, 4), (3, 5), (4, 5)]
            var p = Path()
            for e in edges {
                p.move(to: pts[e.0])
                p.addLine(to: pts[e.1])
            }
            line(&ctx, p, 0.2, 1.5)
            for c in pts { dot(&ctx, c, 5, 0.32) }
        case .bedrock:
            for i in 0..<6 {
                let y = h * (0.02 + 0.17 * CGFloat(i))
                var p = Path()
                p.move(to: CGPoint(x: w * 0.38, y: y + h * 0.24))
                p.addLine(to: CGPoint(x: w * 1.05, y: y))
                p.addLine(to: CGPoint(x: w * 1.05, y: y + h * 0.1))
                p.addLine(to: CGPoint(x: w * 0.38, y: y + h * 0.34))
                p.closeSubpath()
                ctx.fill(p, with: .color(Color.white.opacity(0.05 + 0.02 * Double(i))))
            }
        case .foundry:
            let r: CGFloat = 26
            let dx = r * 1.732, dy = r * 1.5
            var p = Path()
            for row in 0..<7 {
                for col in 0..<7 {
                    let cx = w * 0.55 + CGFloat(col) * dx + (row % 2 == 0 ? 0 : dx / 2)
                    let cy = -r + CGFloat(row) * dy
                    for i in 0..<6 {
                        let a = CGFloat(i) * .pi / 3 - .pi / 2
                        let q = CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
                        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                    }
                    p.closeSubpath()
                }
            }
            line(&ctx, p, 0.15, 1.4)
        case .litellm:
            var p = Path()
            let origin = CGPoint(x: w * 0.5, y: h * 0.5)
            for i in 0..<5 {
                let y = h * (0.08 + 0.21 * CGFloat(i))
                let end = CGPoint(x: w * 0.97, y: y)
                p.move(to: origin)
                p.addCurve(to: end, control1: CGPoint(x: w * 0.7, y: origin.y), control2: CGPoint(x: w * 0.76, y: y))
                dot(&ctx, end, 5, 0.32)
            }
            line(&ctx, p, 0.22, 2.2)
            dot(&ctx, origin, 7, 0.4)
        case .gateway:
            let c = CGPoint(x: w * 0.95, y: h * 0.5)
            for i in 1...5 {
                let r = CGFloat(i) * 38
                line(&ctx, Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), 0.2 - 0.025 * Double(i), 2)
            }
        case .anthropic:
            let c = CGPoint(x: w * 0.88, y: h * 0.45)
            for i in 1...4 {
                let r = CGFloat(i) * 34
                line(&ctx, Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), 0.2 - 0.03 * Double(i), 1.6)
            }
            for i in 0..<14 {
                let a = CGFloat(i) / 14 * 2 * .pi
                dot(&ctx, CGPoint(x: c.x + 150 * cos(a), y: c.y + 150 * sin(a)), 2.5, 0.25)
            }
        case .login:
            dot(&ctx, CGPoint(x: w * 0.86, y: h * 0.32), 40, 0.14)
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.7, y: h * 0.62, width: 190, height: 190)), with: .color(Color.white.opacity(0.12)))
            dot(&ctx, CGPoint(x: w * 0.62, y: h * 0.2), 10, 0.2)
        case .custom:
            for i in 0..<4 {
                let y = h * (0.2 + 0.2 * CGFloat(i))
                var p = Path()
                p.move(to: CGPoint(x: w * 0.5, y: y))
                p.addLine(to: CGPoint(x: w * 0.97, y: y))
                line(&ctx, p, 0.2, 2.5)
                dot(&ctx, CGPoint(x: w * (0.58 + 0.09 * CGFloat((i * 3) % 4)), y: y), 7, 0.38)
            }
        }
    }
}

// MARK: - Building blocks

/// A rounded square with a gradient, a soft highlight and a glow in its own color.
struct GradientTile: View {
    let symbol: String
    let accent: Accent
    var size: CGFloat = 32
    var kind: ProviderKind? = nil

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
                ProviderMark(kind: kind, fallback: symbol, size: size)
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
