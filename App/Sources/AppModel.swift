import AVFoundation
import Foundation
import Observation
import SwiftUI

enum Cover: String, Identifiable { case session, result; var id: String { rawValue } }

enum PaywallReason: Equatable, Hashable { case thirdBuilding, move(Move), theme(CityTheme), timelapse, pastMonths, settings }

enum ActiveSheet: Identifiable, Equatable {
    case settings, paywall(PaywallReason), share, moves, town
    var id: String {
        switch self {
        case .settings: "settings"
        case .paywall: "paywall"
        case .share: "share"
        case .moves: "moves"
        case .town: "town"
        }
    }
}

/// いま建てている回
struct Session {
    var move: Move
    var goal: Goal
    var day: String
    var blocks: [Block] = []
    var counter: RepCounter
    var hold = HoldTracker()
    var sensorLive: Bool
    /// センサーがないとき、指で始めた空気椅子の時計
    var manualHoldRunning = false
    var lastRep: Rep?
    var reachedGoal = false

    var goalCount: Int? { if case .reps(let n) = goal { n } else { nil } }
}

/// 終わったときのまとめ
struct SessionResult: Equatable {
    var move: Move
    var blocks: Int
    var sturdy: Int
    var wobbly: Int
    var foundationSeconds: Int
    var commissionDone: Bool
    var ornament: Ornament?
    var newLandmarks: [String]
    var suggestion: Int?
    var buildHeight: Int
}

@MainActor
@Observable
final class AppModel {
    // MARK: 街
    var ledger: CityLedger { didSet { save() } }
    var now: Date
    let calendar: Calendar
    let persists: Bool

    // MARK: 設定
    var onboarded: Bool { didSet { store(onboarded, "onboarded") } }
    var sensitivity: Sensitivity { didSet { store(sensitivity.rawValue, "sensitivity") } }
    var voiceOn: Bool { didSet { store(voiceOn, "voice") } }
    var hapticsOn: Bool { didSet { store(hapticsOn, "haptics") } }
    var theme: CityTheme { didSet { store(theme.rawValue, "theme") } }
    var goalCount: Int { didSet { store(goalCount, "goalCount") } }
    var endless: Bool { didSet { store(endless, "endless") } }
    var move: Move { didSet { store(move.rawValue, "move") } }
    var timelapseTried: Bool { didSet { store(timelapseTried, "timelapseTried") } }
    var paywallOffered: Bool { didSet { store(paywallOffered, "paywallOffered") } }

    // MARK: 課金
    let purchases: PurchaseStore
    var proOverride = false
    var isPro: Bool { proOverride || purchases.entitlements.isPro }

    // MARK: 画面
    var cover: Cover?
    var activeSheet: ActiveSheet?
    var session: Session?
    var result: SessionResult?
    /// 撮影・デモでは時計を進めない
    var frozen = false
    /// 撮影で、しゃがみの深さの目盛りを決まった値で見せる
    var depthOverride: Double?

    // MARK: 手応え（値が変わると振動する）
    var pressTick = 0
    var blockTick = 0
    var sturdyTick = 0
    var wobblyTick = 0
    var goalTick = 0
    var landmarkTick = 0

    @ObservationIgnored var makeMotion: @MainActor () -> MotionSource = { CoreMotionSource() }
    @ObservationIgnored private var motion: MotionSource?
    @ObservationIgnored private var holdTimer: Task<Void, Never>?
    @ObservationIgnored private let voice = VoiceCounter()
    @ObservationIgnored private let defaults = UserDefaults.standard

    static let productID = ProductID.pro(bundleID: Bundle.main.bundleIdentifier ?? "com.enludus.daily.009")

    static var cityURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("city.json")
    }

    init(persists: Bool = true, now: Date = Date(), calendar: Calendar = .current) {
        self.persists = persists
        self.now = now
        self.calendar = calendar
        let d = UserDefaults.standard
        if persists, let data = try? Data(contentsOf: Self.cityURL), let saved = try? JSONDecoder().decode(CityLedger.self, from: data) {
            ledger = saved
        } else {
            ledger = CityLedger()
        }
        onboarded = persists ? d.bool(forKey: "onboarded") : true
        sensitivity = Sensitivity(rawValue: d.string(forKey: "sensitivity") ?? "") ?? .easy
        voiceOn = persists ? (d.object(forKey: "voice") as? Bool ?? true) : true
        hapticsOn = d.object(forKey: "haptics") as? Bool ?? true
        theme = persists ? (CityTheme(rawValue: d.string(forKey: "theme") ?? "") ?? .dusk) : .dusk
        goalCount = persists ? (d.object(forKey: "goalCount") as? Int ?? 15) : 15
        endless = persists ? d.bool(forKey: "endless") : false
        move = persists ? (Move(rawValue: d.string(forKey: "move") ?? "") ?? .squat) : .squat
        timelapseTried = persists ? d.bool(forKey: "timelapseTried") : false
        paywallOffered = persists ? d.bool(forKey: "paywallOffered") : false
        let id = Self.productID
        purchases = PurchaseStore(productIDs: [id], proProductIDs: [id])
    }

    // MARK: - 見るための値

    var todayKey: String { DayKey.of(now, calendar: calendar) }
    var today: DayBuild { ledger.build(on: todayKey) }
    var commission: Commission { Commission.of(now, calendar: calendar) }

    /// まだ 1 ブロックもない間は、見本の街を見せる（最初の 10 秒で何が育つか分かるように）
    var showsSample: Bool { ledger.totalBlocks == 0 && ledger.totalFoundation == 0 }

    var cityForDisplay: CityLedger { showsSample ? Self.makeSamples(now: now, calendar: calendar, includeToday: false) : ledger }

    var monthBuilds: [DayBuild] { cityForDisplay.month(containing: now, calendar: calendar) }
    var todayIndex: Int { (calendar.component(.day, from: now)) - 1 }
    var streak: Int { ledger.streak(today: now, calendar: calendar) }
    var monthBlocks: Int { ledger.monthBlocks(containing: now, calendar: calendar) }

    var monthTitle: String {
        let f = DateFormatter()
        f.locale = Lang.locale
        f.setLocalizedDateFormatFromTemplate(Lang.isJapanese ? "yMMMM" : "MMMM y")
        return f.string(from: now)
    }

    func canUse(_ move: Move) -> Bool { !move.isPro || isPro }
    func canUse(_ theme: CityTheme) -> Bool { !theme.isPro || isPro }

    // MARK: - 建てる

    func startSession() {
        press()
        guard canUse(move) else { activeSheet = .paywall(.move(move)); return }
        let source = makeMotion()
        motion = source
        var s = Session(move: move, goal: endless || move.isHold ? .endless : .reps(goalCount), day: todayKey,
                        counter: RepCounter(sensitivity: sensitivity), sensorLive: source.isAvailable)
        s.blocks = []
        session = s
        result = nil
        cover = .session
        if source.isAvailable {
            source.start { [weak self] sample in self?.handle(sample) }
        }
        if voiceOn { voice.say(move.isHold ? tr("土台をつくります", "Building the foundation") : tr("はじめます", "Let's build")) }
    }

    func handle(_ sample: MotionSample) {
        guard var s = session else { return }
        if s.move.isHold {
            _ = s.counter.feed(sample)
            s.hold.feed(t: sample.t, inside: s.counter.phase != .calibrating && s.counter.angle >= s.counter.sensitivity.downDegrees)
            let before = Int(session?.hold.seconds ?? 0)
            session = s
            if Int(s.hold.seconds) / 10 > before / 10 { holdMilestone(Int(s.hold.seconds)) }
            return
        }
        let rep = s.counter.feed(sample)
        session = s
        if let rep { place(Block(quality: rep.quality, move: s.move), rep: rep) }
    }

    /// 数え漏れを指で 1 回足す（指で足した分は「ふつう」のブロック）
    func addByHand() {
        guard let s = session, !s.move.isHold else { return }
        place(Block(quality: .normal, move: s.move), rep: nil)
    }

    private func place(_ block: Block, rep: Rep?) {
        guard var s = session else { return }
        s.blocks.append(block)
        s.lastRep = rep
        ledger.add(block, on: s.day)
        let count = s.blocks.count
        var reached = false
        if let g = s.goalCount, count == g, !s.reachedGoal { s.reachedGoal = true; reached = true }
        session = s
        switch block.quality {
        case .sturdy: sturdyTick += 1
        case .normal: blockTick += 1
        case .wobbly: wobblyTick += 1
        }
        if reached {
            goalTick += 1
            if voiceOn { voice.say(trf("%d、目標です", "%d. Goal!", count)) }
        } else if voiceOn {
            voice.say(Lang.isJapanese ? VoiceCounter.japanese(count) : "\(count)")
        }
    }

    /// センサーがない端末の空気椅子：指で始めて、指で止める
    func toggleManualHold() {
        guard var s = session, s.move.isHold else { return }
        press()
        s.manualHoldRunning.toggle()
        session = s
        holdTimer?.cancel()
        guard s.manualHoldRunning else { return }
        holdTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, var s = self.session, s.manualHoldRunning else { return }
                let before = Int(s.hold.seconds)
                s.hold.addManual(0.1)
                self.session = s
                if Int(s.hold.seconds) / 10 > before / 10 { self.holdMilestone(Int(s.hold.seconds)) }
            }
        }
    }

    private func holdMilestone(_ seconds: Int) {
        blockTick += 1
        if voiceOn { voice.say(trf("%d 秒", "%d seconds", seconds)) }
    }

    func finishSession() {
        press()
        motion?.stop()
        motion = nil
        holdTimer?.cancel()
        guard let s = session else { cover = nil; return }
        let beforeTotal = ledger.totalBlocks - s.blocks.count
        let hadCommission = commission.isDone(DayBuild(day: s.day, blocks: Array(today.blocks.dropLast(s.blocks.count)), foundationSeconds: today.foundationSeconds, ornament: today.ornament))
        let seconds = Int(s.hold.seconds.rounded())
        ledger.addFoundation(seconds: seconds, on: s.day)
        var ornament: Ornament?
        let doneNow = commission.isDone(ledger.build(on: s.day))
        if doneNow && !hadCommission && ledger.build(on: s.day).ornament == nil {
            ornament = commission.ornament
            ledger.setOrnament(commission.ornament, on: s.day)
        }
        let newMarks = Landmark.catalog.filter { $0.threshold > beforeTotal && $0.threshold <= ledger.totalBlocks }.map(\.name)
        if !newMarks.isEmpty { landmarkTick += 1 }
        let sturdy = s.blocks.filter { $0.quality == .sturdy }.count
        result = SessionResult(
            move: s.move, blocks: s.blocks.count, sturdy: sturdy, wobbly: s.blocks.filter { $0.quality == .wobbly }.count,
            foundationSeconds: seconds, commissionDone: ornament != nil, ornament: ornament, newLandmarks: newMarks,
            suggestion: s.goalCount.flatMap { Goal.suggestion(goal: $0, done: s.blocks.count, sturdy: sturdy) }.flatMap { $0 == s.goalCount ? nil : $0 },
            buildHeight: ledger.build(on: s.day).height)
        session = nil
        cover = .result
        if voiceOn { voice.say(tr("おつかれさま", "Nice work")) }
    }

    func cancelSession() {
        motion?.stop()
        motion = nil
        holdTimer?.cancel()
        session = nil
        cover = nil
    }

    func acceptSuggestion(_ n: Int) {
        press()
        goalCount = n
        endless = false
        if var r = result { r.suggestion = nil; result = r }
    }

    /// 結果を閉じる。3 棟目を建てた直後に 1 回だけ、Pro を案内する（価値を感じた直後）
    func closeResult() {
        press()
        cover = nil
        result = nil
        if !isPro && !paywallOffered && ledger.builtDays >= 3 {
            paywallOffered = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                self.activeSheet = .paywall(.thirdBuilding)
            }
        }
    }

    func choose(_ move: Move) {
        press()
        if canUse(move) { self.move = move; activeSheet = nil } else { activeSheet = .paywall(.move(move)) }
    }

    func choose(_ theme: CityTheme) {
        press()
        if canUse(theme) { self.theme = theme } else { activeSheet = .paywall(.theme(theme)) }
    }

    func press() { pressTick += 1 }

    // MARK: - 保存

    private func save() {
        guard persists else { return }
        let url = Self.cityURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(ledger) { try? data.write(to: url, options: .atomic) }
    }

    private func store(_ value: Any, _ key: String) {
        guard persists else { return }
        defaults.set(value, forKey: key)
    }

    // MARK: - 見本の街

    /// 見本の街（その月の 1 日から昨日まで。決まった並びで毎回同じ）
    nonisolated static func makeSamples(now: Date, calendar: Calendar, includeToday: Bool, todayBlocks: Int = 12) -> CityLedger {
        var ledger = CityLedger()
        let day = calendar.component(.day, from: now)
        guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return ledger }
        let moves: [Move] = [.squat, .squat, .wide, .squat, .bulgarian, .squat, .lunge, .squat, .jump]
        let ornaments = Ornament.allCases
        for d in 1..<max(1, day) {
            if d % 6 == 3 { continue }  // 休んだ日は空き地
            guard let date = calendar.date(byAdding: .day, value: d - 1, to: first) else { continue }
            let key = DayKey.of(date, calendar: calendar)
            let height = 7 + (d * 7) % 17
            let move = moves[d % moves.count]
            for k in 0..<height {
                let q: BlockQuality = (k + d) % 5 == 0 ? .wobbly : ((k * 3 + d) % 4 == 0 ? .normal : .sturdy)
                ledger.add(Block(quality: q, move: move), on: key)
            }
            if d % 4 == 1 { ledger.addFoundation(seconds: 30 + (d * 13) % 70, on: key) }
            if d % 3 == 0 { ledger.setOrnament(ornaments[d % ornaments.count], on: key) }
        }
        if includeToday {
            let key = DayKey.of(now, calendar: calendar)
            for k in 0..<todayBlocks {
                ledger.add(Block(quality: k % 5 == 4 ? .wobbly : (k % 3 == 2 ? .normal : .sturdy), move: .squat), on: key)
            }
            ledger.addFoundation(seconds: 40, on: key)
        }
        return ledger
    }
}

/// 声の数え上げ（小さく。設定でオフにできる）
@MainActor
final class VoiceCounter {
    private let synth = AVSpeechSynthesizer()

    func say(_ text: String) {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: Lang.isJapanese ? "ja-JP" : "en-US")
        u.volume = 0.55
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        synth.speak(u)
    }

    /// 「いち、に、さん」の数え方（20 まで。そこから先は数字のまま）
    nonisolated static func japanese(_ n: Int) -> String {
        let words = ["いち", "に", "さん", "し", "ご", "ろく", "しち", "はち", "く", "じゅう",
                     "じゅういち", "じゅうに", "じゅうさん", "じゅうし", "じゅうご", "じゅうろく", "じゅうしち", "じゅうはち", "じゅうく", "にじゅう"]
        return n >= 1 && n <= words.count ? words[n - 1] : "\(n)"
    }
}
