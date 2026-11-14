import Foundation

/// 屋上の飾り（その日の注文を済ませると置かれる）
enum Ornament: String, Codable, Sendable, CaseIterable {
    case garden, antenna, tank, flag, solar, dome, heliport, bell, windmill, dish

    var name: String {
        switch self {
        case .garden: tr("屋上の庭", "Roof garden")
        case .antenna: tr("アンテナ", "Antenna")
        case .tank: tr("給水塔", "Water tank")
        case .flag: tr("旗", "Flag")
        case .solar: tr("太陽の板", "Solar panels")
        case .dome: tr("丸屋根", "Dome")
        case .heliport: tr("ヘリポート", "Helipad")
        case .bell: tr("鐘", "Bell")
        case .windmill: tr("風車", "Wind vane")
        case .dish: tr("パラボラ", "Dish")
        }
    }
}

/// 今日の注文（日替わり。手で用意した 60 本）
struct Commission: Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        /// 合わせて N 回
        case total(Int)
        /// 頑丈なブロック N 個（2 秒かけて下ろす）
        case sturdy(Int)
        /// 空気椅子 N 秒
        case hold(Int)
    }

    let id: Int
    let kind: Kind
    let ornament: Ornament
    let ja: String
    let en: String

    var title: String { tr(ja, en) }

    var requirement: String {
        switch kind {
        case .total(let n): trf("合わせて %d 回", "%d reps in total", n)
        case .sturdy(let n): trf("頑丈なブロック %d 個（2 秒かけて下ろす）", "%d solid blocks (lower for 2 sec)", n)
        case .hold(let n): trf("空気椅子 %d 秒", "Hold a sit for %d sec", n)
        }
    }

    /// 進み具合（0〜1）
    func progress(_ build: DayBuild) -> Double {
        switch kind {
        case .total(let n): min(1, Double(build.height) / Double(n))
        case .sturdy(let n): min(1, Double(build.sturdyCount) / Double(n))
        case .hold(let n): min(1, Double(build.foundationSeconds) / Double(n))
        }
    }

    func isDone(_ build: DayBuild) -> Bool { progress(build) >= 1 }

    /// その日の注文（年の何日目で決まる。同じ日はいつも同じ）
    static func of(_ date: Date, calendar: Calendar) -> Commission {
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return catalog[(day - 1) % catalog.count]
    }

    static let catalog: [Commission] = {
        let raw: [(Kind, Ornament, String, String)] = [
            (.total(10), .garden, "屋上に小さな庭を", "A small garden on the roof"),
            (.sturdy(5), .antenna, "電波の届くアンテナを", "An antenna that reaches far"),
            (.hold(30), .tank, "給水塔の重さに耐える土台", "A base strong enough for a water tank"),
            (.total(15), .flag, "開店の旗を立てる", "Raise the opening-day flag"),
            (.sturdy(8), .solar, "太陽の板をまっすぐ並べる", "Line up the solar panels straight"),
            (.total(20), .dome, "天文台の丸屋根", "An observatory dome"),
            (.hold(45), .heliport, "ヘリが降りられる屋上", "A roof a helicopter can land on"),
            (.sturdy(6), .bell, "朝を知らせる鐘", "A bell to ring in the morning"),
            (.total(12), .windmill, "風向きを見る風車", "A vane to read the wind"),
            (.sturdy(10), .dish, "遠くの星を聞くパラボラ", "A dish to listen to far stars"),
            (.total(8), .garden, "ハーブの鉢を三つ", "Three pots of herbs"),
            (.hold(20), .tank, "雨水をためる樽", "A barrel for rainwater"),
            (.sturdy(4), .flag, "町内会の旗", "The neighborhood flag"),
            (.total(25), .antenna, "ラジオ局の鉄塔", "A radio mast"),
            (.sturdy(7), .dome, "プラネタリウムの屋根", "A planetarium roof"),
            (.total(18), .solar, "パン屋の屋根に太陽の板", "Solar panels for the bakery"),
            (.hold(60), .heliport, "救急ヘリの発着場", "An air-ambulance pad"),
            (.total(14), .bell, "学校のチャイム", "A school chime"),
            (.sturdy(9), .windmill, "丘の上の風見どり", "A weathercock on the hill"),
            (.total(30), .dish, "テレビ局のパラボラ", "A TV station dish"),
            (.sturdy(3), .garden, "ベンチのある屋上", "A rooftop with a bench"),
            (.total(16), .tank, "銭湯の給水塔", "A bathhouse water tower"),
            (.hold(40), .flag, "港の信号旗", "Harbor signal flags"),
            (.sturdy(12), .antenna, "灯台守の無線", "A lighthouse keeper's radio"),
            (.total(22), .dome, "植物園の温室", "A botanical glasshouse"),
            (.sturdy(5), .solar, "図書館の屋根", "The library roof"),
            (.total(10), .heliport, "屋上の展望台", "A rooftop lookout"),
            (.hold(35), .bell, "時計台の鐘を吊る梁", "A beam to hang the clock bell"),
            (.total(20), .windmill, "風で回る看板", "A wind-spun sign"),
            (.sturdy(6), .dish, "天気を読むレーダー", "A weather radar"),
            (.total(12), .garden, "屋上の小さな畑", "A tiny rooftop farm"),
            (.sturdy(8), .tank, "消防の水槽", "A fire-brigade tank"),
            (.hold(25), .flag, "運動会の万国旗", "Sports-day bunting"),
            (.total(28), .antenna, "アマチュア無線の塔", "A ham radio tower"),
            (.sturdy(10), .dome, "モスクのような丸屋根", "A tall round cupola"),
            (.total(15), .solar, "駅の屋根に太陽の板", "Solar panels on the station"),
            (.hold(50), .heliport, "屋上のテニスコート", "A rooftop tennis court"),
            (.sturdy(4), .bell, "教会の小さな鐘", "A small chapel bell"),
            (.total(24), .windmill, "発電の風車", "A power windmill"),
            (.sturdy(7), .dish, "衛星を追うアンテナ", "A satellite tracker"),
            (.total(9), .garden, "ひなたぼっこの芝生", "A sunny patch of lawn"),
            (.hold(30), .tank, "酒蔵の水の塔", "A brewery water tower"),
            (.total(17), .flag, "商店街ののぼり", "Shopping-street banners"),
            (.sturdy(11), .antenna, "山の上の中継局", "A relay on the ridge"),
            (.total(26), .dome, "科学館の丸屋根", "A science museum dome"),
            (.sturdy(6), .solar, "カフェのテラスの屋根", "A café terrace roof"),
            (.hold(55), .heliport, "屋上の映画館", "A rooftop cinema"),
            (.total(13), .bell, "市場の始まりの鐘", "The market's opening bell"),
            (.sturdy(9), .windmill, "灯台の風向計", "A lighthouse wind gauge"),
            (.total(32), .dish, "電波望遠鏡", "A radio telescope"),
            (.sturdy(5), .garden, "屋上のバラ園", "A rooftop rose garden"),
            (.total(19), .tank, "ホテルの給水塔", "A hotel water tower"),
            (.hold(45), .flag, "ヨットクラブの旗", "Yacht club pennants"),
            (.total(21), .antenna, "空港の管制アンテナ", "An airport control mast"),
            (.sturdy(12), .dome, "聖堂の大きな丸屋根", "A grand cathedral dome"),
            (.total(11), .solar, "保育園の屋根", "The nursery school roof"),
            (.hold(65), .heliport, "空中庭園の広場", "A sky-garden plaza"),
            (.sturdy(8), .bell, "港の霧笛の鐘", "A harbor fog bell"),
            (.total(27), .windmill, "丘の上の三枚羽根", "Three blades on the hill"),
            (.sturdy(10), .dish, "深い宇宙の受信機", "A deep-space receiver"),
        ]
        return raw.enumerated().map { Commission(id: $0.offset, kind: $0.element.0, ornament: $0.element.1, ja: $0.element.2, en: $0.element.3) }
    }()
}

/// 通算のブロックで街に置かれる物（手で用意した 40 種）
struct Landmark: Identifiable, Sendable {
    enum Shape: String, Sendable { case tree, lamp, bench, fountain, busStop, bridge, wheel, station, park, tower }

    let threshold: Int
    let shape: Shape
    let ja: String
    let en: String
    var id: Int { threshold }
    var name: String { tr(ja, en) }

    static let catalog: [Landmark] = [
        Landmark(threshold: 5, shape: .tree, ja: "最初の街路樹", en: "The first street tree"),
        Landmark(threshold: 10, shape: .lamp, ja: "街灯", en: "A street lamp"),
        Landmark(threshold: 20, shape: .bench, ja: "バス停のベンチ", en: "A bench by the stop"),
        Landmark(threshold: 30, shape: .tree, ja: "並木", en: "A row of trees"),
        Landmark(threshold: 45, shape: .busStop, ja: "バス停", en: "A bus stop"),
        Landmark(threshold: 60, shape: .lamp, ja: "ガス灯の通り", en: "A gaslit lane"),
        Landmark(threshold: 80, shape: .fountain, ja: "広場の噴水", en: "A plaza fountain"),
        Landmark(threshold: 100, shape: .park, ja: "小さな公園", en: "A pocket park"),
        Landmark(threshold: 125, shape: .bench, ja: "読書のベンチ", en: "A reading bench"),
        Landmark(threshold: 150, shape: .bridge, ja: "川の小さな橋", en: "A small river bridge"),
        Landmark(threshold: 180, shape: .tree, ja: "桜並木", en: "Cherry-lined street"),
        Landmark(threshold: 210, shape: .station, ja: "路面電車の停留所", en: "A tram stop"),
        Landmark(threshold: 250, shape: .fountain, ja: "水遊びの広場", en: "A splash plaza"),
        Landmark(threshold: 300, shape: .wheel, ja: "小さな観覧車", en: "A little Ferris wheel"),
        Landmark(threshold: 350, shape: .lamp, ja: "港の灯り", en: "Harbor lights"),
        Landmark(threshold: 400, shape: .park, ja: "芝生の丘", en: "A grassy knoll"),
        Landmark(threshold: 460, shape: .busStop, ja: "夜行バスの乗り場", en: "A night-bus stop"),
        Landmark(threshold: 520, shape: .bridge, ja: "歩道橋", en: "A footbridge"),
        Landmark(threshold: 600, shape: .station, ja: "駅舎", en: "A station house"),
        Landmark(threshold: 700, shape: .tower, ja: "見晴らしの塔", en: "A lookout tower"),
        Landmark(threshold: 800, shape: .tree, ja: "銀杏の並木", en: "Ginkgo avenue"),
        Landmark(threshold: 900, shape: .fountain, ja: "音楽の噴水", en: "A musical fountain"),
        Landmark(threshold: 1000, shape: .wheel, ja: "大観覧車", en: "The big wheel"),
        Landmark(threshold: 1150, shape: .park, ja: "植物園", en: "Botanical gardens"),
        Landmark(threshold: 1300, shape: .bridge, ja: "アーチの橋", en: "An arched bridge"),
        Landmark(threshold: 1500, shape: .station, ja: "中央駅", en: "Central station"),
        Landmark(threshold: 1700, shape: .tower, ja: "電波塔", en: "A broadcast tower"),
        Landmark(threshold: 1900, shape: .bench, ja: "夕日の見えるベンチ", en: "A sunset bench"),
        Landmark(threshold: 2100, shape: .lamp, ja: "光の並木", en: "Avenue of lights"),
        Landmark(threshold: 2400, shape: .busStop, ja: "空港バスの乗り場", en: "Airport shuttle stop"),
        Landmark(threshold: 2700, shape: .fountain, ja: "噴水のある大広場", en: "A grand fountain square"),
        Landmark(threshold: 3000, shape: .wheel, ja: "海辺の観覧車", en: "A seaside wheel"),
        Landmark(threshold: 3400, shape: .bridge, ja: "吊り橋", en: "A suspension bridge"),
        Landmark(threshold: 3800, shape: .park, ja: "森の公園", en: "A forest park"),
        Landmark(threshold: 4200, shape: .station, ja: "高架の駅", en: "An elevated station"),
        Landmark(threshold: 4700, shape: .tower, ja: "天文台の塔", en: "An observatory tower"),
        Landmark(threshold: 5200, shape: .tree, ja: "百年の大木", en: "A hundred-year tree"),
        Landmark(threshold: 6000, shape: .bridge, ja: "湾をまたぐ橋", en: "A bridge across the bay"),
        Landmark(threshold: 7000, shape: .wheel, ja: "星空の観覧車", en: "A starlit wheel"),
        Landmark(threshold: 8000, shape: .tower, ja: "街のシンボルタワー", en: "The city's landmark tower"),
    ]
}

/// 街の見た目のテーマ（夜景・雪は Pro）
enum CityTheme: String, Codable, Sendable, CaseIterable, Identifiable {
    case day, dusk, night, snow
    var id: String { rawValue }
    var isPro: Bool { self == .night || self == .snow }
    var name: String {
        switch self {
        case .day: tr("昼", "Day")
        case .dusk: tr("夕方", "Dusk")
        case .night: tr("夜景", "Night")
        case .snow: tr("雪", "Snow")
        }
    }
}
