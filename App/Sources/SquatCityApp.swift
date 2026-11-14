import SwiftUI

@main
struct SquatCityApp: App {
    @State private var model = Launch.makeModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    @State var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        ZStack {
            if model.onboarded {
                HomeView()
                    // 全画面の場面やシートを出している間は、下のホームを読み上げ・UI テストの対象から外す
                    .accessibilityHidden(model.cover != nil || model.activeSheet != nil)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.35), value: model.onboarded)
        .environment(model)
        // 淡い空と細い線の街が主役。夜景は街のテーマで選べるので、画面はライトに固定する（StudyReel と同じ）
        .preferredColorScheme(.light)
        .fullScreenCover(item: $model.cover) { cover in
            Group {
                switch cover {
                case .session: SessionView()
                case .result: ResultView()
                }
            }
            .environment(model)
            .preferredColorScheme(.light)
        }
        .sheet(item: $model.activeSheet) { sheet in
            sheetView(sheet)
                .environment(model)
                .preferredColorScheme(.light)
        }
        .sensoryFeedback(trigger: model.pressTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.blockTick) { _, _ in model.hapticsOn ? .impact(weight: .light) : nil }
        .sensoryFeedback(trigger: model.sturdyTick) { _, _ in model.hapticsOn ? .impact(weight: .medium) : nil }
        .sensoryFeedback(trigger: model.wobblyTick) { _, _ in model.hapticsOn ? .impact(flexibility: .soft, intensity: 0.4) : nil }
        .sensoryFeedback(trigger: model.goalTick) { _, _ in model.hapticsOn ? .success : nil }
        .sensoryFeedback(trigger: model.landmarkTick) { _, _ in model.hapticsOn ? .impact(weight: .heavy) : nil }
        .task { await Launch.run(model) }
        .task { await model.purchases.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !model.frozen { model.now = Date() }
        }
        // 撮影の日本語の画面では、日付の書き方も日本語に
        .environment(\.locale, Lang.locale)
    }

    @ViewBuilder
    private func sheetView(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .settings: SettingsView()
        case .paywall(let reason): PaywallView(reason: reason)
        case .share: ShareView()
        case .moves: MovesView()
        case .town: TownView()
        }
    }
}

/// 動きを出さない入力（撮影用。センサーがある端末の画面を、決まった状態で撮る）
@MainActor
final class StillMotionSource: MotionSource {
    var isAvailable: Bool { true }
    func start(_ handler: @escaping @MainActor (MotionSample) -> Void) {}
    func stop() {}
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）・UI テスト（-uiTestFresh）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（CI のシミュレータは英語のため）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var isFreshUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFresh") }

    /// 撮影中は動きを最後の形で止めて撮る
    static var isStill: Bool { scene != nil }

    /// 撮影の日：その月の 20 日（月の通りが 3 分の 2 ほど埋まった状態）
    static func stageDate() -> Date {
        let cal = Calendar.current
        var c = cal.dateComponents([.year, .month], from: Date())
        c.day = 20
        c.hour = 19
        return cal.date(from: c) ?? Date()
    }

    static func makeModel() -> AppModel {
        Lang.forcedJapanese = forcesJapanese
        if isFreshUITest {
            for key in ["onboarded", "sensitivity", "voice", "haptics", "theme", "goalCount", "endless", "move", "timelapseTried", "paywallOffered"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            try? FileManager.default.removeItem(at: AppModel.cityURL)
            let model = AppModel()
            model.voiceOn = false
            return model
        }
        guard isDemo || scene != nil else { return AppModel() }
        let now = stageDate()
        let model = AppModel(persists: false, now: now)
        model.frozen = true
        model.voiceOn = false
        // 撮影・デモでは Pro の案内を自動で出さない（案内の画面は paywall の場面で撮る）
        model.paywallOffered = true
        model.onboarded = scene != "onboarding"
        if scene != "empty" && scene != "onboarding" {
            model.ledger = AppModel.makeSamples(now: now, calendar: model.calendar, includeToday: !isDemo)
        }
        if scene == "night" { model.proOverride = true; model.theme = .night }
        if scene == "snow" { model.proOverride = true; model.theme = .snow }
        if scene == "dusk" { model.theme = .dusk }
        if scene == "pro" { model.proOverride = true }
        return model
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        try? await Task.sleep(for: .milliseconds(300))
        switch scene {
        case "session", "nosensor":
            if scene == "session" {
                model.makeMotion = { StillMotionSource() }
            } else {
                model.makeMotion = { UnavailableMotionSource() }
            }
            model.goalCount = 15
            model.startSession()
            if var s = model.session {
                s.blocks = Array(model.today.blocks.suffix(9))
                s.lastRep = scene == "session" ? Rep(descent: 2.3, depth: 34) : nil
                model.session = s
            }
            model.depthOverride = scene == "session" ? 0.62 : 0
        case "wobbly":
            model.makeMotion = { StillMotionSource() }
            model.startSession()
            if var s = model.session {
                s.blocks = Array(model.today.blocks.suffix(5))
                s.lastRep = Rep(descent: 0.6, depth: 30)
                model.session = s
            }
            model.depthOverride = 0.2
        case "hold":
            model.makeMotion = { StillMotionSource() }
            model.move = .chair
            model.startSession()
            if var s = model.session {
                s.hold.addManual(37)
                model.session = s
            }
            model.depthOverride = 0.8
        case "result":
            model.ledger.setOrnament(model.commission.ornament, on: model.todayKey)
            model.result = SessionResult(move: .squat, blocks: 12, sturdy: 8, wobbly: 1, foundationSeconds: 0, commissionDone: true,
                                         ornament: model.commission.ornament, newLandmarks: [Landmark.catalog[13].name], suggestion: 17,
                                         buildHeight: model.today.height)
            model.cover = .result
        case "share":
            model.activeSheet = .share
        case "moves":
            model.activeSheet = .moves
        case "town":
            model.activeSheet = .town
        case "settings":
            model.activeSheet = .settings
        case "paywall":
            model.activeSheet = .paywall(.thirdBuilding)
        default:
            break
        }
    }
}

/// センサーのない端末（シミュレータと同じ）
@MainActor
final class UnavailableMotionSource: MotionSource {
    var isAvailable: Bool { false }
    func start(_ handler: @escaping @MainActor (MotionSample) -> Void) {}
    func stop() {}
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
/// 見本の街 → 決まった動きで 4 回しゃがむ（頑丈・ふつう・ぐらぐら・頑丈）→ 結果 → 今月の街を共有
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .milliseconds(Int(seconds * 1000))) }
        await wait(2.0)
        model.makeMotion = { ScriptedMotionSource(descents: [2.2, 1.3, 0.6, 2.1]) }
        model.goalCount = 4
        model.startSession()
        await wait(11.5)
        model.finishSession()
        await wait(3.0)
        model.closeResult()
        await wait(0.8)
        model.activeSheet = .share
    }
}
