import SwiftUI

// 見た目の決まり（app-quality-bar の look.md）。色・書体・角丸・余白・影はここだけで決める。
// 世界：夕暮れの工事現場と、その向こうの街。
// 地はアスファルトの夜の色、主な色は安全色の黄（と黒の縞）、窓の灯りは琥珀、数字は工事看板のような太い詰めた書体。
enum Theme {
    // 地と文字（アスファルトと、看板の白ペンキ）
    static let paper = Color(hex: 0x15171F)
    static let paperTop = Color(hex: 0x1D1A2B)
    static let ink = Color(hex: 0xF3EFE4)
    static let sub = Color(hex: 0x8F95A7)
    static let line = Color(hex: 0x2F3445)

    // 安全色の黄の段階
    static let accent = Color(hex: 0xFFC72C)   // 安全色の黄（主役）
    static let deep = Color(hex: 0xFFC72C)     // 文字・印に使う黄（暗い地の上で読める）
    static let amber = Color(hex: 0xE39A1F)    // 黄の一段濃いところ（進み具合の途中）
    static let soft = Color(hex: 0x2A2F3E)     // 鉄板の明るい面（選んだ物・進み具合の溝）
    static let card = Color(hex: 0x20242F)     // 鉄板（看板・札）
    static let hazardBlack = Color(hex: 0x111216)
    static let cone = Color(hex: 0xFF7A1A)     // カラーコーンの橙（ぐらぐら・旗）

    // 題材の色：窓の灯り・夕焼け・街路樹
    static let window = Color(hex: 0xFFC765)
    static let dusk = Color(hex: 0xF2884B)
    static let leaf = Color(hex: 0x6E9C5A)
    static let concrete = Color(hex: 0x495063)
    static let snow = Color(hex: 0xE7ECF3)

    // 書体：見出しと数字は工事看板のような太く詰めた書体、本文はふつうのゴシック
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.condensed)
    }
    /// 数字（大きな回数・秒）。さらに詰めた幅で、桁をそろえる
    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.compressed).monospacedDigit()
    }
    static func label(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .bold).width(.expanded) }

    // 角丸の段階（鉄板と看板なので、角はほとんど丸めない）
    static let radiusS: CGFloat = 3
    static let radiusM: CGFloat = 6
    static let radiusL: CGFloat = 10

    // 線
    static let hairline: CGFloat = 1
}

/// ブロックの出来ごとの色（頑丈＝黄の縁のコンクリート、ふつう＝灰の縁、ぐらぐら＝橙の点線）
extension BlockQuality {
    var fill: Color {
        switch self {
        case .sturdy: Theme.concrete
        case .normal: Theme.concrete.opacity(0.75)
        case .wobbly: Theme.card
        }
    }

    var stroke: Color {
        switch self {
        case .sturdy: Theme.accent
        case .normal: Color(hex: 0x8A91A5)
        case .wobbly: Theme.cone
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

/// 黄と黒の縞（工事の柵・看板の帯）
struct HazardStripe: View {
    var stripe: CGFloat = 9
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.hazardBlack))
            var path = Path()
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height + stripe, y: 0))
                path.addLine(to: CGPoint(x: x + stripe, y: size.height))
                path.closeSubpath()
                x += stripe * 2
            }
            ctx.fill(path, with: .color(Theme.accent))
        }
        .accessibilityHidden(true)
    }
}

/// 小さなラベル（看板の字のように、横に広げて字間を開ける）
struct Eyebrow: View {
    let text: String
    var color: Color = Theme.sub
    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(10.5))
            .kerning(1.2)
            .foregroundStyle(color)
    }
}

/// 鉄板の看板（四隅にボルト。stripe で上に黄と黒の帯）
struct Plate<Content: View>: View {
    var padding: CGFloat = 14
    var stripe = false
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .padding(.top, stripe ? 6 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .overlay(alignment: .top) {
                if stripe { HazardStripe(stripe: 7).frame(height: 6) }
            }
            .overlay { Bolts() }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.line, lineWidth: Theme.hairline))
    }
}

/// 看板の四隅のボルト
struct Bolts: View {
    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 6
            ForEach(0..<4, id: \.self) { k in
                Circle()
                    .fill(Theme.line)
                    .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 0.5))
                    .frame(width: 4, height: 4)
                    .position(x: k % 2 == 0 ? inset : geo.size.width - inset,
                              y: k < 2 ? inset + 6 : geo.size.height - inset)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 主なボタン：安全色の黄に黒い字。押すと重い鉄のボタンのように沈む
struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: 17, weight: .heavy))
            .foregroundStyle(enabled ? Theme.hazardBlack : Theme.sub)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(enabled ? Theme.accent : Theme.soft, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .overlay(alignment: .leading) {
                if enabled { HazardStripe(stripe: 5).frame(width: 10).clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.radiusM, bottomLeadingRadius: Theme.radiusM)) }
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                    .fill(enabled ? Theme.amber.opacity(0.55) : Color.black.opacity(0.4))
                    .offset(y: pressed ? 0 : 4)
            )
            .offset(y: pressed ? 3 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pressed)
    }
}

/// 控えめなボタン：鉄板に黄の縁
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Theme.accent)
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .background(configuration.isPressed ? Theme.soft : Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.accent.opacity(0.7), lineWidth: 1.2))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

/// 画面の地：夕暮れの空の名残りと、端に組んだ足場（鉄パイプと筋交い）
struct SiteBackdrop: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [Theme.paperTop, Theme.paper]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.45)))
            // 足場：左右の端だけに（文字の下には敷かない）
            let bay: CGFloat = 46
            let lift: CGFloat = 70
            for edge in [CGFloat(0), size.width - bay] {
                var pipe = Path()
                for x in [edge, edge + bay] {
                    pipe.move(to: CGPoint(x: x, y: 0)); pipe.addLine(to: CGPoint(x: x, y: size.height))
                }
                var y: CGFloat = 0
                var flip = false
                while y < size.height {
                    pipe.move(to: CGPoint(x: edge, y: y)); pipe.addLine(to: CGPoint(x: edge + bay, y: y))
                    pipe.move(to: CGPoint(x: flip ? edge : edge + bay, y: y)); pipe.addLine(to: CGPoint(x: flip ? edge + bay : edge, y: y + lift))
                    flip.toggle()
                    y += lift
                }
                ctx.stroke(pipe, with: .color(Theme.line.opacity(0.55)), lineWidth: 1.2)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
