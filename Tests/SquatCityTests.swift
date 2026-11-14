import Foundation
import Testing
@testable import SquatCity

/// 決まった動きを流して、数えた回を返す
private func count(_ descents: [TimeInterval], depth: Double = 40, sensitivity: Sensitivity = .easy,
                   ascent: TimeInterval = 0.9, pause: TimeInterval = 0.5, jitter: Double = 1.2) -> [Rep] {
    var counter = RepCounter(sensitivity: sensitivity)
    return MotionScript.samples(descents: descents, depth: depth, ascent: ascent, pause: pause, jitter: jitter)
        .compactMap { counter.feed($0) }
}

struct RepCounterTests {
    @Test func countsEachSquatOnce() {
        let reps = count([2.0, 2.0, 2.0, 2.0, 2.0])
        #expect(reps.count == 5)
    }

    @Test func slowLoweringMakesSolidBlocksAndFastMakesWobbly() {
        let reps = count([2.4, 1.4, 0.6])
        #expect(reps.map(\.quality) == [.sturdy, .normal, .wobbly])
    }

    @Test func descentEstimateIsCloseToTheRealLowering() {
        let reps = count([2.4, 1.4, 0.6, 3.0])
        for (rep, real) in zip(reps, [2.4, 1.4, 0.6, 3.0]) {
            #expect(abs(rep.descent - real) < 0.35, "見積もり \(rep.descent) 実際 \(real)")
        }
    }

    @Test func chestHoldWithSmallTiltStillCountsOnEasy() {
        // 胸に当てると、上体の傾きは 20〜30 度ほど
        #expect(count([2.0, 2.0, 2.0], depth: 22).count == 3)
    }

    @Test func pocketWithDeepTiltIsNotRejected() {
        // 前のポケット：太ももが水平に近づき 75 度。行き過ぎでも弾かない
        let reps = count([2.2, 1.2, 0.7], depth: 75)
        #expect(reps.count == 3)
        #expect(reps.map(\.quality) == [.sturdy, .normal, .wobbly])
    }

    @Test func strictNeedsADeeperSquat() {
        #expect(count([2.0, 2.0], depth: 22, sensitivity: .strict).isEmpty)
        #expect(count([2.0, 2.0], depth: 45, sensitivity: .strict).count == 2)
    }

    @Test func handShakeWhileStandingIsNotARep() {
        var counter = RepCounter()
        let samples = MotionScript.samples(descents: [], jitter: 4)
        // 立ったまま 5 秒、4 度ほどの揺れ
        var t = samples.last?.t ?? 0
        var extra: [MotionSample] = []
        for i in 0..<250 {
            t += 0.02
            let a = 4 * sin(Double(i) * 0.9) * .pi / 180
            extra.append(MotionSample(t: t, x: 0, y: -cos(a), z: -sin(a)))
        }
        let reps = (samples + extra).compactMap { counter.feed($0) }
        #expect(reps.isEmpty)
    }

    @Test func aQuickBobShorterThanTheMinimumIsIgnored() {
        // 0.15 秒で下りて 0.15 秒で戻る（つまずき・持ち直し）
        let reps = count([0.15], depth: 30, ascent: 0.15)
        #expect(reps.isEmpty)
    }

    @Test func pauseAtTheBottomDoesNotInflateTheDescent() {
        var counter = RepCounter()
        var samples = MotionScript.samples(descents: [0.7], depth: 40, pause: 0)
        // 一番下で 3 秒止まってから立つ形に作り直す：下りきった直後に 3 秒の静止を差し込む
        let bottom = samples.firstIndex { abs(acos(-$0.y) * 180 / .pi - 40) < 0.8 } ?? 30
        let hold = (0..<150).map { k in MotionSample(t: samples[bottom].t + Double(k + 1) * 0.02, x: 0, y: -cos(40 * .pi / 180), z: -sin(40 * .pi / 180)) }
        let shifted = samples[(bottom + 1)...].map { MotionSample(t: $0.t + 3, x: $0.x, y: $0.y, z: $0.z) }
        samples = Array(samples[...bottom]) + hold + shifted
        let reps = samples.compactMap { counter.feed($0) }
        #expect(reps.count == 1)
        #expect(reps.first?.quality == .wobbly)
    }
}

struct HoldTrackerTests {
    @Test func countsOnlyWhileHoldingWithShortGrace() {
        var h = HoldTracker()
        var t = 0.0
        for _ in 0..<100 { h.feed(t: t, inside: true); t += 0.1 }      // 10 秒
        for _ in 0..<4 { h.feed(t: t, inside: false); t += 0.1 }       // 0.4 秒のぶれ：数え続ける
        for _ in 0..<50 { h.feed(t: t, inside: true); t += 0.1 }       // 5 秒
        for _ in 0..<30 { h.feed(t: t, inside: false); t += 0.1 }      // 3 秒立った：止まる
        #expect(abs(h.seconds - 15.5) < 0.8)
        #expect(!h.holding)
    }

    @Test func manualTimerAddsSeconds() {
        var h = HoldTracker()
        h.addManual(12.5)
        #expect(h.seconds == 12.5)
    }
}

struct CityLedgerTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    func date(_ d: Int, month: Int = 11) -> Date { cal.date(from: DateComponents(year: 2026, month: month, day: d, hour: 20))! }
    func key(_ d: Int, month: Int = 11) -> String { DayKey.of(date(d, month: month), calendar: cal) }

    @Test func dayKeyRoundTrips() {
        #expect(key(4) == "2026-11-04")
        #expect(DayKey.date("2026-11-04", calendar: cal).map { cal.component(.day, from: $0) } == 4)
    }

    @Test func eachRepRaisesTodaysBuildingByOneBlock() {
        var city = CityLedger()
        for _ in 0..<7 { city.add(Block(quality: .sturdy, move: .squat), on: key(14)) }
        #expect(city.build(on: key(14)).height == 7)
        #expect(city.totalBlocks == 7)
    }

    @Test func streakKeepsGoingUntilTodayIsBuilt() {
        var city = CityLedger()
        for d in 10...13 { city.add(Block(quality: .normal, move: .squat), on: key(d)) }
        // 14 日の夜、まだ建てていない：昨日まで 4 日続いている
        #expect(city.streak(today: date(14), calendar: cal) == 4)
        city.add(Block(quality: .normal, move: .squat), on: key(14))
        #expect(city.streak(today: date(14), calendar: cal) == 5)
        // 2 日あくと途切れる
        #expect(city.streak(today: date(16), calendar: cal) == 0)
    }

    @Test func foundationOnlyDayCountsForTheStreak() {
        var city = CityLedger()
        city.addFoundation(seconds: 40, on: key(14))
        #expect(city.streak(today: date(14), calendar: cal) == 1)
    }

    @Test func monthHasOneSlotPerDayWithEmptyLots() {
        var city = CityLedger()
        city.add(Block(quality: .sturdy, move: .squat), on: key(3))
        let month = city.month(containing: date(14), calendar: cal)
        #expect(month.count == 30)
        #expect(month[2].height == 1)
        #expect(month[3].isEmpty)
    }

    @Test func wobblyBlocksLeanTheBuildingAndSolidOnesStraightenIt() {
        var b = DayBuild(day: "2026-11-14")
        b.blocks = Array(repeating: Block(quality: .wobbly, move: .squat), count: 6)
        #expect(b.leanDegrees == 6)
        b.blocks += Array(repeating: Block(quality: .sturdy, move: .squat), count: 12)
        #expect(b.leanDegrees == 0)
        b.blocks = Array(repeating: Block(quality: .normal, move: .squat), count: 10)
        #expect(b.leanDegrees == 0)
    }

    @Test func foundationWidensTheLotUpToFive() {
        var b = DayBuild(day: "2026-11-14")
        #expect(b.lotWidth == 2)
        b.foundationSeconds = 65
        #expect(b.lotWidth == 4)
        b.foundationSeconds = 600
        #expect(b.lotWidth == 5)
    }

    @Test func landmarksAppearAtTheirThresholds() {
        var city = CityLedger()
        #expect(city.landmarks.isEmpty)
        #expect(city.nextLandmark?.threshold == 5)
        for _ in 0..<10 { city.add(Block(quality: .normal, move: .squat), on: key(1)) }
        #expect(city.landmarks.map(\.threshold) == [5, 10])
        #expect(city.nextLandmark?.threshold == 20)
    }

    @Test func monthsAreListedNewestFirst() {
        var city = CityLedger()
        city.add(Block(quality: .normal, move: .squat), on: key(2, month: 9))
        city.add(Block(quality: .normal, move: .squat), on: key(5, month: 11))
        city.add(Block(quality: .normal, move: .squat), on: key(6, month: 11))
        let months = city.months(calendar: cal)
        #expect(months.map { cal.component(.month, from: $0) } == [11, 9])
    }

    @Test func sampleCityIsTheSameEveryTimeAndSkipsSomeDays() {
        let a = AppModel.makeSamples(now: date(20), calendar: cal, includeToday: false)
        let b = AppModel.makeSamples(now: date(20), calendar: cal, includeToday: false)
        #expect(a == b)
        #expect(a.build(on: key(3)).isEmpty)
        #expect(a.build(on: key(4)).height > 0)
        #expect(a.build(on: key(20)).isEmpty)
    }
}

struct GoalTests {
    @Test func suggestsMoreWhenTheGoalWasMetWithSolidBlocks() {
        #expect(Goal.suggestion(goal: 15, done: 15, sturdy: 13) == 18)
        #expect(Goal.suggestion(goal: 15, done: 16, sturdy: 9) == 17)
    }

    @Test func noChangeWhenMostlyRushed() {
        #expect(Goal.suggestion(goal: 15, done: 15, sturdy: 3) == nil)
    }

    @Test func meetsYouWhereYouAreWhenShort() {
        #expect(Goal.suggestion(goal: 20, done: 12, sturdy: 10) == 12)
        #expect(Goal.suggestion(goal: 20, done: 1, sturdy: 1) == 3)
        #expect(Goal.suggestion(goal: 20, done: 0, sturdy: 0) == nil)
    }

    @Test func neverAboveTheMaximum() {
        #expect(Goal.suggestion(goal: 200, done: 200, sturdy: 200) == 200)
    }
}

struct CatalogTests {
    @Test func thereIsMoreContentThanADayCanUse() {
        #expect(Commission.catalog.count == 60)
        #expect(Landmark.catalog.count == 40)
        #expect(Set(Landmark.catalog.map(\.threshold)).count == 40)
        #expect(Landmark.catalog.map(\.threshold) == Landmark.catalog.map(\.threshold).sorted())
    }

    @Test func everyEntryHasJapaneseAndEnglish() {
        for c in Commission.catalog {
            #expect(!c.ja.isEmpty && !c.en.isEmpty)
            #expect(c.en.range(of: "\\p{Han}|\\p{Hiragana}|\\p{Katakana}", options: .regularExpression) == nil)
        }
        for l in Landmark.catalog {
            #expect(!l.ja.isEmpty && !l.en.isEmpty)
        }
    }

    @Test func commissionIsStableForADayAndChangesTheNextDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let morning = cal.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 7))!
        let night = cal.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 23))!
        let tomorrow = cal.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 7))!
        #expect(Commission.of(morning, calendar: cal).id == Commission.of(night, calendar: cal).id)
        #expect(Commission.of(morning, calendar: cal).id != Commission.of(tomorrow, calendar: cal).id)
    }

    @Test func commissionProgress() {
        let c = Commission(id: 0, kind: .sturdy(4), ornament: .flag, ja: "旗", en: "Flag")
        var b = DayBuild(day: "2026-11-14")
        b.blocks = [Block(quality: .sturdy, move: .squat), Block(quality: .wobbly, move: .squat), Block(quality: .sturdy, move: .squat)]
        #expect(c.progress(b) == 0.5)
        #expect(!c.isDone(b))
        b.blocks += [Block(quality: .sturdy, move: .squat), Block(quality: .sturdy, move: .squat)]
        #expect(c.isDone(b))
        let hold = Commission(id: 1, kind: .hold(30), ornament: .tank, ja: "樽", en: "Barrel")
        b.foundationSeconds = 45
        #expect(hold.isDone(b))
    }

    @Test func freeMovesAreSquatAndHold() {
        #expect(Move.allCases.filter { !$0.isPro } == [.squat, .chair])
        #expect(CityTheme.allCases.filter(\.isPro) == [.night, .snow])
    }

    @Test func japaneseCountingWords() {
        #expect(VoiceCounter.japanese(1) == "いち")
        #expect(VoiceCounter.japanese(20) == "にじゅう")
        #expect(VoiceCounter.japanese(21) == "21")
    }
}
