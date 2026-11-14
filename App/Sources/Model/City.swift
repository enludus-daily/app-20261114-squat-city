import Foundation

/// やり方。やり方ごとに、建つ建物の種類が変わる
enum Move: String, Codable, Sendable, CaseIterable, Identifiable {
    case squat, chair, wide, bulgarian, jump, lunge
    var id: String { rawValue }

    var isPro: Bool { !(self == .squat || self == .chair) }
    /// 回数ではなく、保った秒を数える（土台）
    var isHold: Bool { self == .chair }

    var name: String {
        switch self {
        case .squat: tr("スクワット", "Squat")
        case .chair: tr("空気椅子", "Wall-less sit")
        case .wide: tr("ワイド", "Wide squat")
        case .bulgarian: tr("ブルガリアン", "Bulgarian split")
        case .jump: tr("ジャンプ", "Jump squat")
        case .lunge: tr("ランジ", "Lunge")
        }
    }

    var building: String {
        switch self {
        case .squat: tr("マンション", "Apartments")
        case .chair: tr("土台", "Foundation")
        case .wide: tr("倉庫", "Warehouse")
        case .bulgarian: tr("塔", "Tower")
        case .jump: tr("灯台", "Lighthouse")
        case .lunge: tr("時計塔", "Clock tower")
        }
    }

    /// 効く所（目的から選ぶ入口）
    var target: String {
        switch self {
        case .squat: tr("太もも・お尻", "Thighs & glutes")
        case .chair: tr("太もも前・体幹", "Quads & core")
        case .wide: tr("内もも", "Inner thighs")
        case .bulgarian: tr("お尻・片脚ずつ", "Glutes, one leg")
        case .jump: tr("ふくらはぎ・心拍", "Calves & cardio")
        case .lunge: tr("太もも裏・バランス", "Hamstrings & balance")
        }
    }

    var howTo: String {
        switch self {
        case .squat: tr("足は肩幅。2 秒かけて下ろし、1 秒で立つ", "Feet shoulder-width. Lower for 2 sec, stand in 1")
        case .chair: tr("太ももが床と平行に近い所で止まる。秒が土台の広さになる", "Hold with thighs near level. Seconds widen your lot")
        case .wide: tr("足を大きく開き、つま先は外。ひざもつま先の向きへ", "Wide stance, toes out, knees follow toes")
        case .bulgarian: tr("後ろの足を椅子に乗せ、前の脚でしゃがむ", "Rear foot on a chair, squat on the front leg")
        case .jump: tr("しゃがんで、軽く跳ぶ。着地はやわらかく", "Squat, then hop lightly. Land softly")
        case .lunge: tr("一歩前に出て腰を落とし、戻る。左右交互に", "Step forward, drop the hips, return. Alternate")
        }
    }
}

struct Block: Codable, Equatable, Sendable {
    var quality: BlockQuality
    var move: Move
}

/// 1 日 1 棟。その日のブロックが積み上がる
struct DayBuild: Codable, Equatable, Sendable {
    var day: String
    var blocks: [Block] = []
    /// 空気椅子で保った秒（土台の広さ）
    var foundationSeconds: Int = 0
    /// その日の注文を済ませて、屋上に置いた飾り
    var ornament: Ornament?

    var height: Int { blocks.count }
    var sturdyCount: Int { blocks.filter { $0.quality == .sturdy }.count }
    var wobblyCount: Int { blocks.filter { $0.quality == .wobbly }.count }

    /// 敷地の幅（マス）：2 マスから、土台 30 秒ごとに 1 マス、最大 5
    var lotWidth: Int { min(5, 2 + foundationSeconds / 30) }

    /// 傾き（度）：ぐらぐらのブロックが多いほど傾く。頑丈なブロックは傾きを打ち消す。最大 6 度
    var leanDegrees: Double {
        guard !blocks.isEmpty else { return 0 }
        let wobble = Double(wobblyCount) - Double(sturdyCount) * 0.5
        return min(6, max(0, wobble / Double(blocks.count) * 9))
    }

    var isEmpty: Bool { blocks.isEmpty && foundationSeconds == 0 }
}

/// 日付の鍵（端末の暦。yyyy-MM-dd）
enum DayKey {
    static func of(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(_ key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// 自分の街の台帳（画面から切り離してテストする）
struct CityLedger: Codable, Equatable, Sendable {
    var days: [String: DayBuild] = [:]

    func build(on key: String) -> DayBuild { days[key] ?? DayBuild(day: key) }

    mutating func add(_ block: Block, on key: String) {
        var b = build(on: key)
        b.blocks.append(block)
        days[key] = b
    }

    mutating func addFoundation(seconds: Int, on key: String) {
        guard seconds > 0 else { return }
        var b = build(on: key)
        b.foundationSeconds += seconds
        days[key] = b
    }

    mutating func setOrnament(_ ornament: Ornament, on key: String) {
        var b = build(on: key)
        b.ornament = ornament
        days[key] = b
    }

    var totalBlocks: Int { days.values.reduce(0) { $0 + $1.height } }
    var totalFoundation: Int { days.values.reduce(0) { $0 + $1.foundationSeconds } }
    var builtDays: Int { days.values.filter { !$0.isEmpty }.count }

    /// 続けた日数。今日まだ建てていなくても、昨日まで続いていれば数える（今日はこれから）
    func streak(today: Date, calendar: Calendar) -> Int {
        var day = today
        if build(on: DayKey.of(day, calendar: calendar)).isEmpty {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var n = 0
        while !build(on: DayKey.of(day, calendar: calendar)).isEmpty {
            n += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    /// その月の 1 日〜末日の建物（建てていない日は空き地）
    func month(containing date: Date, calendar: Calendar) -> [DayBuild] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return [] }
        return range.compactMap { d in
            calendar.date(byAdding: .day, value: d - 1, to: first).map { build(on: DayKey.of($0, calendar: calendar)) }
        }
    }

    func monthBlocks(containing date: Date, calendar: Calendar) -> Int {
        month(containing: date, calendar: calendar).reduce(0) { $0 + $1.height }
    }

    /// いちばん高いビルの日
    func tallest(in builds: [DayBuild]) -> DayBuild? {
        builds.filter { $0.height > 0 }.max { $0.height < $1.height }
    }

    /// 通算のブロックで、街に置かれた物
    var landmarks: [Landmark] { Landmark.catalog.filter { $0.threshold <= totalBlocks } }
    var nextLandmark: Landmark? { Landmark.catalog.first { $0.threshold > totalBlocks } }

    /// 建てた月（新しい順）
    func months(calendar: Calendar) -> [Date] {
        let starts = Set(days.values.filter { !$0.isEmpty }.compactMap { DayKey.date($0.day, calendar: calendar) }
            .compactMap { calendar.date(from: calendar.dateComponents([.year, .month], from: $0)) })
        return starts.sorted(by: >)
    }
}

/// 回数の目標。決まった配列にせず、自分で決める（うでたてビートでの本人の意見）
enum Goal: Codable, Equatable, Sendable {
    case reps(Int)
    case endless

    static let range = 3...200

    /// 終わったあとの次の目標の提案（勝手に変えない。1 タップで受け入れる）
    /// - 目標に届いて、半分以上が頑丈なら +2（頑丈が 8 割以上なら +3）
    /// - 届かなかったら、できた回数に合わせる
    static func suggestion(goal: Int, done: Int, sturdy: Int) -> Int? {
        guard done > 0 else { return nil }
        if done >= goal {
            let ratio = Double(sturdy) / Double(done)
            if ratio >= 0.8 { return min(range.upperBound, goal + 3) }
            if ratio >= 0.5 { return min(range.upperBound, goal + 2) }
            return nil
        }
        return max(range.lowerBound, done)
    }
}
