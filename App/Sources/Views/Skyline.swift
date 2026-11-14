import SwiftUI

/// 街の色（テーマごと）
struct CityPalette {
    var skyTop: Color
    var skyBottom: Color
    var fill: Color
    var line: Color
    var window: Color
    var ground: Color
    var snowCaps: Bool
    var litWindows: Bool

    static func of(_ theme: CityTheme) -> CityPalette {
        switch theme {
        case .day:
            CityPalette(skyTop: Theme.skyTop, skyBottom: Theme.paper, fill: Theme.card, line: Theme.deep, window: Theme.window, ground: Theme.accent, snowCaps: false, litWindows: false)
        case .dusk:
            CityPalette(skyTop: Theme.soft, skyBottom: Theme.dusk.opacity(0.75), fill: Theme.card, line: Theme.deep, window: Theme.window, ground: Theme.accent, snowCaps: false, litWindows: true)
        case .night:
            CityPalette(skyTop: Theme.nightTop, skyBottom: Theme.nightBottom, fill: Theme.nightBuilding, line: Theme.nightLine, window: Theme.window, ground: Theme.nightLine, snowCaps: false, litWindows: true)
        case .snow:
            CityPalette(skyTop: Theme.line, skyBottom: Theme.snow, fill: Theme.card, line: Theme.deep, window: Theme.window, ground: Theme.sub, snowCaps: true, litWindows: false)
        }
    }

    var isDark: Bool { litWindows && fill == Theme.nightBuilding }
}

/// 建物の描き方（月の通りと、建てる画面の 1 棟で同じものを使う）
enum CityDraw {
    /// 1 棟を描く。base は敷地の下の真ん中
    /// - drop：いちばん上のブロックが落ちてくる途中（0 = 上、1 = 置いた）
    static func building(_ ctx: inout GraphicsContext, _ build: DayBuild, base: CGPoint, slot: CGFloat,
                         blockHeight bh: CGFloat, palette p: CityPalette, drop: Double = 1, detail: Bool) {
        let width = slot * (0.42 + 0.12 * CGFloat(build.lotWidth - 2))
        let lw: CGFloat = detail ? 1.1 : 0.7
        var y = base.y
        // 土台（空気椅子の秒）
        if build.foundationSeconds > 0 {
            let fw = min(slot * 0.96, width * 1.25)
            let slab = CGRect(x: base.x - fw / 2, y: y - bh * 0.4, width: fw, height: bh * 0.4)
            ctx.fill(Path(slab), with: .color(p.line.opacity(0.18)))
            ctx.stroke(Path(slab), with: .color(p.line.opacity(0.7)), lineWidth: lw)
            y -= bh * 0.4
        }
        let lean = tan(build.leanDegrees * .pi / 180)
        var lastRect = CGRect(x: base.x - width / 2, y: y, width: width, height: 0)
        for (i, block) in build.blocks.enumerated() {
            let isLast = i == build.blocks.count - 1
            let lift = isLast ? (1 - drop) * Double(bh) * 3 : 0
            let shift = lean * CGFloat(i) * bh
            let rect = CGRect(x: base.x - width / 2 + shift, y: y - CGFloat(i + 1) * bh - CGFloat(lift), width: width, height: bh)
            let path = Path(rect.insetBy(dx: 0.3, dy: 0.3))
            let fill: Color = p.isDark ? p.fill : block.quality.fill
            ctx.fill(path, with: .color(fill))
            let style = block.quality == .wobbly ? StrokeStyle(lineWidth: lw, dash: [2.5, 2]) : StrokeStyle(lineWidth: block.quality == .sturdy ? lw * 1.3 : lw)
            ctx.stroke(path, with: .color(p.isDark ? p.line : block.quality.stroke.opacity(block.quality == .normal ? 1 : 0.9)), style: style)
            if detail || bh >= 7 { windows(&ctx, rect, seed: i + (Int(build.day.suffix(2)) ?? 0), palette: p, move: block.move) }
            lastRect = rect
        }
        guard let top = build.blocks.last else { return }
        roof(&ctx, top.move, on: lastRect, bh: bh, palette: p, lw: lw)
        if p.snowCaps {
            let cap = Path(roundedRect: CGRect(x: lastRect.minX - 1, y: lastRect.minY - 2.5, width: lastRect.width + 2, height: 3.5), cornerRadius: 1.5)
            ctx.fill(cap, with: .color(Theme.snow))
            ctx.stroke(cap, with: .color(p.line.opacity(0.3)), lineWidth: 0.5)
        }
        if let ornament = build.ornament {
            self.ornament(&ctx, ornament, on: lastRect, bh: bh, palette: p, lw: lw, roofMove: top.move)
        }
    }

    private static func windows(_ ctx: inout GraphicsContext, _ rect: CGRect, seed: Int, palette p: CityPalette, move: Move) {
        let columns = max(1, Int(rect.width / 9))
        let w = rect.width / CGFloat(columns)
        for c in 0..<columns {
            // 決まった並びで、明かりの点く窓を選ぶ（毎回同じ）
            let lit = ((seed &* 31 &+ c &* 17) % 5) < (p.litWindows ? 3 : 1)
            let win = CGRect(x: rect.minX + CGFloat(c) * w + w * 0.3, y: rect.minY + rect.height * 0.28, width: w * 0.4, height: rect.height * 0.44)
            if move == .wide {
                // 倉庫：横長の窓 1 つ
                if c == 0 {
                    let band = CGRect(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.35, width: rect.width * 0.7, height: rect.height * 0.3)
                    ctx.fill(Path(band), with: .color(p.window.opacity(p.litWindows ? 0.9 : 0.45)))
                }
                continue
            }
            ctx.fill(Path(win), with: .color(lit ? p.window : p.line.opacity(0.14)))
        }
    }

    private static func roof(_ ctx: inout GraphicsContext, _ move: Move, on r: CGRect, bh: CGFloat, palette p: CityPalette, lw: CGFloat) {
        var path = Path()
        switch move {
        case .squat, .chair:
            // マンション：屋上の手すり
            path.addRect(CGRect(x: r.minX + r.width * 0.1, y: r.minY - bh * 0.22, width: r.width * 0.8, height: bh * 0.22))
            ctx.stroke(path, with: .color(p.line.opacity(0.7)), lineWidth: lw * 0.8)
        case .wide:
            // 倉庫：のこぎり屋根
            let teeth = 3
            let tw = r.width / CGFloat(teeth)
            path.move(to: CGPoint(x: r.minX, y: r.minY))
            for t in 0..<teeth {
                path.addLine(to: CGPoint(x: r.minX + CGFloat(t) * tw, y: r.minY - bh * 0.6))
                path.addLine(to: CGPoint(x: r.minX + CGFloat(t + 1) * tw, y: r.minY))
            }
            ctx.fill(path, with: .color(p.fill))
            ctx.stroke(path, with: .color(p.line), lineWidth: lw)
        case .bulgarian:
            // 塔：細い尖塔
            path.move(to: CGPoint(x: r.minX + r.width * 0.15, y: r.minY))
            path.addLine(to: CGPoint(x: r.midX, y: r.minY - bh * 2.2))
            path.addLine(to: CGPoint(x: r.maxX - r.width * 0.15, y: r.minY))
            path.closeSubpath()
            ctx.fill(path, with: .color(p.fill))
            ctx.stroke(path, with: .color(p.line), lineWidth: lw)
        case .jump:
            // 灯台：丸屋根と灯り
            let d = r.width * 0.7
            let dome = Path(ellipseIn: CGRect(x: r.midX - d / 2, y: r.minY - d / 2, width: d, height: d))
            ctx.fill(Path(CGRect(x: r.midX - d / 2, y: r.minY - d * 0.5, width: d, height: d * 0.5)), with: .color(p.window.opacity(0.9)))
            ctx.stroke(dome, with: .color(p.line), lineWidth: lw)
            ctx.fill(Path(ellipseIn: CGRect(x: r.midX - 2, y: r.minY - d * 0.75 - 2, width: 4, height: 4)), with: .color(p.window))
        case .lunge:
            // 時計塔：三角屋根と時計
            path.move(to: CGPoint(x: r.minX, y: r.minY))
            path.addLine(to: CGPoint(x: r.midX, y: r.minY - bh * 1.1))
            path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            path.closeSubpath()
            ctx.fill(path, with: .color(p.fill))
            ctx.stroke(path, with: .color(p.line), lineWidth: lw)
            let c = min(r.width * 0.5, bh * 0.8)
            let clock = CGRect(x: r.midX - c / 2, y: r.midY - c / 2, width: c, height: c)
            ctx.fill(Path(ellipseIn: clock), with: .color(p.fill))
            ctx.stroke(Path(ellipseIn: clock), with: .color(p.line), lineWidth: lw * 0.8)
            var hands = Path()
            hands.move(to: CGPoint(x: clock.midX, y: clock.midY)); hands.addLine(to: CGPoint(x: clock.midX, y: clock.minY + c * 0.18))
            hands.move(to: CGPoint(x: clock.midX, y: clock.midY)); hands.addLine(to: CGPoint(x: clock.maxX - c * 0.25, y: clock.midY))
            ctx.stroke(hands, with: .color(p.line), lineWidth: lw * 0.7)
        }
    }

    private static func ornament(_ ctx: inout GraphicsContext, _ o: Ornament, on r: CGRect, bh: CGFloat, palette p: CityPalette, lw: CGFloat, roofMove: Move) {
        let top = r.minY - (roofMove == .squat || roofMove == .chair ? bh * 0.22 : roofMove == .bulgarian ? bh * 2.2 : bh * 0.6)
        let s = max(5, min(bh * 1.1, r.width * 0.5))
        let x = roofMove == .bulgarian ? r.midX : r.minX + r.width * 0.7
        var path = Path()
        switch o {
        case .garden:
            for k in 0..<3 {
                ctx.fill(Path(ellipseIn: CGRect(x: r.minX + r.width * (0.15 + 0.25 * CGFloat(k)), y: top - s * 0.45, width: s * 0.45, height: s * 0.45)), with: .color(Theme.leaf))
            }
        case .antenna:
            path.move(to: CGPoint(x: x, y: top)); path.addLine(to: CGPoint(x: x, y: top - s * 1.4))
            ctx.stroke(path, with: .color(p.line), lineWidth: lw * 0.8)
            ctx.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: top - s * 1.4 - 1.5, width: 3, height: 3)), with: .color(Theme.tape))
        case .tank:
            path.addRect(CGRect(x: x - s * 0.3, y: top - s * 0.9, width: s * 0.6, height: s * 0.5))
            path.move(to: CGPoint(x: x - s * 0.25, y: top - s * 0.4)); path.addLine(to: CGPoint(x: x - s * 0.3, y: top))
            path.move(to: CGPoint(x: x + s * 0.25, y: top - s * 0.4)); path.addLine(to: CGPoint(x: x + s * 0.3, y: top))
            ctx.stroke(path, with: .color(p.line), lineWidth: lw * 0.8)
        case .flag:
            path.move(to: CGPoint(x: x, y: top)); path.addLine(to: CGPoint(x: x, y: top - s * 1.3))
            ctx.stroke(path, with: .color(p.line), lineWidth: lw * 0.8)
            var flag = Path()
            flag.move(to: CGPoint(x: x, y: top - s * 1.3)); flag.addLine(to: CGPoint(x: x + s * 0.7, y: top - s * 1.1)); flag.addLine(to: CGPoint(x: x, y: top - s * 0.9))
            ctx.fill(flag, with: .color(Theme.tape))
        case .solar:
            for k in 0..<2 {
                var panel = Path()
                let px = r.minX + r.width * (0.2 + 0.35 * CGFloat(k))
                panel.move(to: CGPoint(x: px, y: top)); panel.addLine(to: CGPoint(x: px + s * 0.5, y: top - s * 0.4))
                ctx.stroke(panel, with: .color(p.line.opacity(0.8)), lineWidth: lw * 1.6)
            }
        case .dome:
            path.addArc(center: CGPoint(x: r.midX, y: top), radius: s * 0.45, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            ctx.fill(path, with: .color(Theme.soft))
            ctx.stroke(path, with: .color(p.line), lineWidth: lw * 0.8)
        case .heliport:
            let pad = CGRect(x: r.midX - s * 0.45, y: top - s * 0.3, width: s * 0.9, height: s * 0.3)
            ctx.stroke(Path(ellipseIn: pad), with: .color(p.line), lineWidth: lw * 0.8)
        case .bell:
            path.addArc(center: CGPoint(x: x, y: top - s * 0.2), radius: s * 0.3, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            path.closeSubpath()
            ctx.fill(path, with: .color(p.window))
            ctx.stroke(path, with: .color(p.line), lineWidth: lw * 0.7)
        case .windmill:
            let c = CGPoint(x: x, y: top - s * 0.9)
            path.move(to: CGPoint(x: x, y: top)); path.addLine(to: c)
            for a in stride(from: 45.0, to: 405, by: 90) {
                path.move(to: c); path.addLine(to: CGPoint(x: c.x + cos(a * .pi / 180) * s * 0.5, y: c.y + sin(a * .pi / 180) * s * 0.5))
            }
            ctx.stroke(path, with: .color(p.line), lineWidth: lw * 0.8)
        case .dish:
            path.addArc(center: CGPoint(x: x, y: top - s * 0.6), radius: s * 0.4, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            path.move(to: CGPoint(x: x, y: top - s * 0.25)); path.addLine(to: CGPoint(x: x, y: top))
            ctx.stroke(path, with: .color(p.line), lineWidth: lw * 0.9)
        }
    }

    /// 街に置かれた物（地面の手前に、細い線で）
    static func landmark(_ ctx: inout GraphicsContext, _ shape: Landmark.Shape, at b: CGPoint, size s: CGFloat, palette p: CityPalette) {
        var path = Path()
        let line = p.line.opacity(0.75)
        switch shape {
        case .tree:
            path.move(to: b); path.addLine(to: CGPoint(x: b.x, y: b.y - s * 0.5))
            ctx.stroke(path, with: .color(line), lineWidth: 0.8)
            ctx.fill(Path(ellipseIn: CGRect(x: b.x - s * 0.32, y: b.y - s, width: s * 0.64, height: s * 0.64)), with: .color(Theme.leaf))
        case .lamp:
            path.move(to: b); path.addLine(to: CGPoint(x: b.x, y: b.y - s)); path.addLine(to: CGPoint(x: b.x + s * 0.25, y: b.y - s))
            ctx.stroke(path, with: .color(line), lineWidth: 0.8)
            ctx.fill(Path(ellipseIn: CGRect(x: b.x + s * 0.18, y: b.y - s * 0.95, width: s * 0.22, height: s * 0.22)), with: .color(p.window))
        case .bench:
            path.move(to: CGPoint(x: b.x - s * 0.4, y: b.y - s * 0.3)); path.addLine(to: CGPoint(x: b.x + s * 0.4, y: b.y - s * 0.3))
            path.move(to: CGPoint(x: b.x - s * 0.3, y: b.y - s * 0.3)); path.addLine(to: CGPoint(x: b.x - s * 0.3, y: b.y))
            path.move(to: CGPoint(x: b.x + s * 0.3, y: b.y - s * 0.3)); path.addLine(to: CGPoint(x: b.x + s * 0.3, y: b.y))
            path.move(to: CGPoint(x: b.x - s * 0.4, y: b.y - s * 0.55)); path.addLine(to: CGPoint(x: b.x + s * 0.4, y: b.y - s * 0.55))
            ctx.stroke(path, with: .color(line), lineWidth: 0.8)
        case .fountain:
            path.addArc(center: CGPoint(x: b.x, y: b.y), radius: s * 0.4, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            path.move(to: CGPoint(x: b.x, y: b.y)); path.addQuadCurve(to: CGPoint(x: b.x - s * 0.35, y: b.y - s * 0.2), control: CGPoint(x: b.x - s * 0.1, y: b.y - s * 0.9))
            path.move(to: CGPoint(x: b.x, y: b.y)); path.addQuadCurve(to: CGPoint(x: b.x + s * 0.35, y: b.y - s * 0.2), control: CGPoint(x: b.x + s * 0.1, y: b.y - s * 0.9))
            ctx.stroke(path, with: .color(Theme.accent), lineWidth: 0.9)
        case .busStop:
            path.move(to: b); path.addLine(to: CGPoint(x: b.x, y: b.y - s * 0.8))
            ctx.stroke(path, with: .color(line), lineWidth: 0.8)
            ctx.stroke(Path(ellipseIn: CGRect(x: b.x - s * 0.18, y: b.y - s * 1.05, width: s * 0.36, height: s * 0.36)), with: .color(line), lineWidth: 0.8)
        case .bridge:
            path.move(to: CGPoint(x: b.x - s * 0.6, y: b.y - s * 0.25)); path.addLine(to: CGPoint(x: b.x + s * 0.6, y: b.y - s * 0.25))
            path.move(to: CGPoint(x: b.x - s * 0.5, y: b.y)); path.addQuadCurve(to: CGPoint(x: b.x + s * 0.5, y: b.y), control: CGPoint(x: b.x, y: b.y - s * 0.6))
            ctx.stroke(path, with: .color(line), lineWidth: 0.8)
        case .wheel:
            let c = CGPoint(x: b.x, y: b.y - s * 0.6)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - s * 0.5, y: c.y - s * 0.5, width: s, height: s)), with: .color(line), lineWidth: 0.8)
            for a in stride(from: 0.0, to: 180, by: 45) {
                path.move(to: CGPoint(x: c.x - cos(a * .pi / 180) * s * 0.5, y: c.y - sin(a * .pi / 180) * s * 0.5))
                path.addLine(to: CGPoint(x: c.x + cos(a * .pi / 180) * s * 0.5, y: c.y + sin(a * .pi / 180) * s * 0.5))
            }
            path.move(to: c); path.addLine(to: CGPoint(x: b.x - s * 0.3, y: b.y)); path.move(to: c); path.addLine(to: CGPoint(x: b.x + s * 0.3, y: b.y))
            ctx.stroke(path, with: .color(line.opacity(0.7)), lineWidth: 0.6)
        case .station:
            path.addRect(CGRect(x: b.x - s * 0.5, y: b.y - s * 0.5, width: s, height: s * 0.5))
            path.move(to: CGPoint(x: b.x - s * 0.6, y: b.y - s * 0.5)); path.addLine(to: CGPoint(x: b.x, y: b.y - s * 0.85)); path.addLine(to: CGPoint(x: b.x + s * 0.6, y: b.y - s * 0.5))
            ctx.stroke(path, with: .color(line), lineWidth: 0.8)
        case .park:
            for dx in [-0.3, 0.25] {
                ctx.fill(Path(ellipseIn: CGRect(x: b.x + s * dx - s * 0.25, y: b.y - s * 0.6, width: s * 0.5, height: s * 0.5)), with: .color(Theme.leaf))
            }
        case .tower:
            path.move(to: CGPoint(x: b.x - s * 0.25, y: b.y)); path.addLine(to: CGPoint(x: b.x, y: b.y - s * 1.5)); path.addLine(to: CGPoint(x: b.x + s * 0.25, y: b.y))
            path.move(to: CGPoint(x: b.x - s * 0.14, y: b.y - s * 0.6)); path.addLine(to: CGPoint(x: b.x + s * 0.14, y: b.y - s * 0.6))
            ctx.stroke(path, with: .color(line), lineWidth: 0.8)
        }
    }
}

/// 月の通りのスカイライン（1 日 1 棟）
struct SkylineView: View {
    let builds: [DayBuild]
    var todayIndex: Int?
    var theme: CityTheme = .day
    var landmarks: [Landmark] = []
    /// 何日目まで見せるか（タイムラプス用。nil は全部）
    var revealDays: Int?

    var body: some View {
        let p = CityPalette.of(theme)
        Canvas { ctx, size in
            let groundY = size.height - 22
            // 空（題材に理由があるので、ここだけグラデーション）
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [p.skyTop, p.skyBottom]), startPoint: .zero, endPoint: CGPoint(x: 0, y: groundY)))
            if p.isDark {
                for k in 0..<24 {
                    let x = CGFloat((k * 73) % 997) / 997 * size.width
                    let y = CGFloat((k * 151) % 613) / 613 * groundY * 0.55
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)), with: .color(.white.opacity(0.6)))
                }
            }
            let n = max(builds.count, 1)
            let slot = size.width / CGFloat(n)
            let maxHeight = max(12, builds.map(\.height).max() ?? 0)
            let bh = min(10, (groundY - 34) / CGFloat(maxHeight + 3))
            // 地面
            var ground = Path()
            ground.move(to: CGPoint(x: 0, y: groundY)); ground.addLine(to: CGPoint(x: size.width, y: groundY))
            ctx.stroke(ground, with: .color(p.ground), lineWidth: 1)
            if p.snowCaps { ctx.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: 22)), with: .color(Theme.snow)) }
            for (i, build) in builds.enumerated() {
                let x = slot * (CGFloat(i) + 0.5)
                if let reveal = revealDays, i >= reveal { continue }
                if build.isEmpty {
                    // 空き地：小さな草
                    var tuft = Path()
                    tuft.move(to: CGPoint(x: x - 2, y: groundY)); tuft.addLine(to: CGPoint(x: x - 1, y: groundY - 3))
                    tuft.move(to: CGPoint(x: x + 1.5, y: groundY)); tuft.addLine(to: CGPoint(x: x + 2, y: groundY - 2.5))
                    ctx.stroke(tuft, with: .color(Theme.leaf), lineWidth: 0.8)
                } else {
                    CityDraw.building(&ctx, build, base: CGPoint(x: x, y: groundY), slot: slot, blockHeight: bh, palette: p, detail: false)
                }
                if i == todayIndex {
                    var mark = Path()
                    mark.move(to: CGPoint(x: x, y: groundY + 5)); mark.addLine(to: CGPoint(x: x - 3, y: groundY + 10)); mark.addLine(to: CGPoint(x: x + 3, y: groundY + 10)); mark.closeSubpath()
                    ctx.fill(mark, with: .color(Theme.deep))
                }
            }
            // 日付の目盛り（1・10・20・末日）
            for d in [1, 10, 20, builds.count] where d >= 1 && d <= builds.count {
                let x = slot * (CGFloat(d - 1) + 0.5)
                ctx.draw(Text("\(d)").font(.system(size: 8, weight: .medium)).foregroundStyle(p.isDark ? Theme.nightLine : Theme.sub), at: CGPoint(x: x, y: groundY + 16))
            }
            // 街に置かれた物（新しい 10 個）を、空き地の手前に
            let shown = Array(landmarks.suffix(10))
            for (k, mark) in shown.enumerated() {
                let x = size.width * (CGFloat(k) + 0.5) / CGFloat(max(shown.count, 1))
                CityDraw.landmark(&ctx, mark.shape, at: CGPoint(x: x + slot * 0.5, y: groundY), size: 9, palette: p)
            }
        }
    }
}

/// 建てる画面の 1 棟（大きく）
struct BuildingView: View, Animatable {
    let build: DayBuild
    /// 目標の回数（エンドレスは nil）。目標の高さに細い点線を引く
    var goal: Int?
    var theme: CityTheme = .day
    var drop: Double = 1

    /// いちばん上のブロックが落ちてくる動き（Canvas を毎フレーム描き直す）
    nonisolated var animatableData: Double {
        get { drop }
        set { drop = newValue }
    }

    var body: some View {
        let p = CityPalette.of(theme)
        Canvas { ctx, size in
            let groundY = size.height - 16
            let target = max(goal ?? 0, build.height + 2, 10)
            let bh = min(30, (groundY - 50) / CGFloat(target + 2))
            let slot = min(size.width * 0.8, bh * 7)
            var ground = Path()
            ground.move(to: CGPoint(x: size.width * 0.08, y: groundY)); ground.addLine(to: CGPoint(x: size.width * 0.92, y: groundY))
            ctx.stroke(ground, with: .color(p.ground), lineWidth: 1)
            if let goal, goal > 0 {
                // 目標の高さ
                let gy = groundY - CGFloat(goal) * bh - (build.foundationSeconds > 0 ? bh * 0.4 : 0)
                var guide = Path()
                guide.move(to: CGPoint(x: size.width * 0.12, y: gy)); guide.addLine(to: CGPoint(x: size.width * 0.88, y: gy))
                ctx.stroke(guide, with: .color(Theme.deep.opacity(0.45)), style: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
                ctx.draw(Text(trf("目標 %d", "Goal %d", goal)).font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.deep), at: CGPoint(x: size.width * 0.88, y: gy - 8), anchor: .trailing)
            }
            // 足場（クレーンの代わりの細い線）
            var scaffold = Path()
            let sx = size.width / 2 + slot * 0.62
            scaffold.move(to: CGPoint(x: sx, y: groundY)); scaffold.addLine(to: CGPoint(x: sx, y: max(8, groundY - CGFloat(build.height + 3) * bh)))
            ctx.stroke(scaffold, with: .color(Theme.accent.opacity(0.6)), style: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
            CityDraw.building(&ctx, build, base: CGPoint(x: size.width / 2, y: groundY), slot: slot, blockHeight: bh, palette: p, drop: drop, detail: true)
        }
    }
}
