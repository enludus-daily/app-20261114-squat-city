import SwiftUI

// 見た目の決まり（app-quality-bar の look.md）。色・書体・角丸・余白・影はここだけで決める。
// トーンは StudyReel：淡いラベンダーの 1 系統、細い線、セリフの見出しと数字。
// 窓の明かり（バター色）と夕方の空（ピーチ）は、題材（街の明かり・空）に理由がある所だけ。
enum Theme {
    // 地と文字
    static let paper = Color(hex: 0xF6F5FA)
    static let ink = Color(hex: 0x2F2E44)
    static let sub = Color(hex: 0x8C8AA3)
    static let line = Color(hex: 0xE3E0EE)

    // 主な色（ラベンダー）の 5 段階
    static let accent = Color(hex: 0xC4BAE6)
    static let soft = Color(hex: 0xECE8F7)
    static let deep = Color(hex: 0x7468AE)
    static let card = Color(hex: 0xFBFAFD)
    static let tape = Color(hex: 0xF3D3C6)

    // 題材の色：窓の明かり・夕方の空・街路樹
    static let window = Color(hex: 0xF2DC94)
    static let dusk = Color(hex: 0xF4C5B2)
    static let skyTop = Color(hex: 0xDCE4F2)
    static let leaf = Color(hex: 0xBFD3AE)

    // 夜景・雪（Pro のテーマ）
    static let nightTop = Color(hex: 0x2A2B47)
    static let nightBottom = Color(hex: 0x4B4870)
    static let nightBuilding = Color(hex: 0x3A3A5E)
    static let nightLine = Color(hex: 0x8C86C2)
    static let snow = Color(hex: 0xFDFDFF)

    // 書体：見出しと数字はセリフ、本文はサンセリフ
    /// 日本語は明朝（ヒラギノ明朝）、英語は New York。システムのセリフは日本語に明朝を当てないため、言語で分ける
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if Lang.isJapanese {
            return .custom(weight == .regular ? "HiraMinProN-W3" : "HiraMinProN-W6", size: size)
        }
        return .system(size: size, weight: weight, design: .serif)
    }
    static func label(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .medium) }

    // 角丸の段階
    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 14
    static let radiusL: CGFloat = 20

    // 線
    static let hairline: CGFloat = 0.8
}

/// ブロックの出来ごとの色（頑丈＝濃い線と淡い塗り、ふつう＝白、ぐらぐら＝点線）
extension BlockQuality {
    var fill: Color {
        switch self {
        case .sturdy: Theme.soft
        case .normal: Theme.card
        case .wobbly: Theme.card
        }
    }

    var stroke: Color {
        switch self {
        case .sturdy: Theme.deep
        case .normal: Theme.accent
        case .wobbly: Theme.sub
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// 小さなラベル（字間を開ける）
struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(10.5))
            .kerning(0.8)
            .foregroundStyle(Theme.sub)
    }
}

/// 細い線の札（カードの代わりに、図面の枠のような細い線で囲む）
struct Plate<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card.opacity(0.85), in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.line, lineWidth: Theme.hairline))
    }
}

/// 主なボタン：白文字は濃い色の上だけ。グラデーションは使わない
struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(enabled ? Theme.deep : Theme.sub.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.deep)
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .background(Theme.soft.opacity(configuration.isPressed ? 1 : 0.7), in: Capsule())
            .overlay(Capsule().stroke(Theme.accent.opacity(0.6), lineWidth: Theme.hairline))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

/// 図面の方眼（細い線）。画面の地に、薄く敷く
struct Blueprint: View {
    var spacing: CGFloat = 22
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x: CGFloat = 0
            while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
            var y: CGFloat = 0
            while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
            ctx.stroke(path, with: .color(Theme.accent.opacity(0.16)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
