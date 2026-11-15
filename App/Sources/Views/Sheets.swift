import SwiftUI

/// 共有：今月のスカイラインのカード。Pro は月のタイムラプス（1 日ずつ建っていく）
struct ShareView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: Int?
    @State private var playing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ShareCard(model: model, revealDays: reveal)
                        .frame(width: 320, height: 480)
                        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
                        .padding(.top, 8)
                    if let image = renderImage() {
                        ShareLink(item: image, preview: SharePreview(tr("今月の街", "This month's city"), image: image)) {
                            Label(tr("画像で共有", "Share as image"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("share.image")
                    }
                    Button { playTimelapse() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play")
                            Text(tr("月のタイムラプス", "Month timelapse"))
                            if !model.isPro { Text(model.timelapseTried ? "Pro" : tr("1 回お試し", "Try once")).font(.system(size: 11)).foregroundStyle(Theme.sub) }
                        }
                    }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(playing)
                    Text(tr("画像はこの iPhone の中で作ります。送り先は自分で選びます", "The image is made on this iPhone. You choose where it goes"))
                        .font(.system(size: 11)).foregroundStyle(Theme.sub).multilineTextAlignment(.center)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }
            .background(Theme.paper)
            .navigationTitle(tr("今月の街を共有", "Share this month's city"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("閉じる", "Close")) { model.activeSheet = nil }.accessibilityIdentifier("main.closeShare")
                }
            }
        }
    }

    private func renderImage() -> Image? {
        let renderer = ImageRenderer(content: ShareCard(model: model, revealDays: nil).frame(width: 360, height: 540))
        renderer.scale = 3
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }

    private func playTimelapse() {
        model.press()
        guard model.isPro || !model.timelapseTried else { model.activeSheet = .paywall(.timelapse); return }
        if !model.isPro { model.timelapseTried = true }
        let days = model.monthBuilds.count
        playing = true
        Task { @MainActor in
            for d in 0...days {
                if reduceMotion { reveal = nil; break }
                withAnimation(.easeOut(duration: 0.1)) { reveal = d }
                try? await Task.sleep(for: .milliseconds(140))
            }
            reveal = nil
            playing = false
        }
    }
}

/// 共有カード（360×540 → 3 倍で書き出す）
struct ShareCard: View {
    let model: AppModel
    var revealDays: Int?

    var body: some View {
        let builds = model.monthBuilds
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: model.monthTitle, color: Theme.accent)
                Spacer()
                Text(tr("しゃがんで建てる", "Squat City")).font(Theme.display(12)).foregroundStyle(Theme.sub)
            }
            Text(tr("今月のスカイライン", "This month's skyline"))
                .font(Theme.display(26)).foregroundStyle(Theme.ink)
            SkylineView(builds: builds, todayIndex: nil, theme: model.theme, landmarks: model.cityForDisplay.landmarks, revealDays: revealDays)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.line, lineWidth: 2))
            HStack(spacing: 0) {
                cell(builds.reduce(0) { $0 + $1.height }, tr("ブロック", "blocks"))
                cell(builds.filter { !$0.isEmpty }.count, tr("棟", "buildings"))
                cell(model.cityForDisplay.tallest(in: builds)?.height ?? 0, tr("いちばん高い", "tallest"))
            }
            if model.showsSample {
                Text(tr("見本の街", "Sample city")).font(.system(size: 10)).foregroundStyle(Theme.sub)
            }
        }
        .padding(20)
        .padding(.top, 8)
        .background(Theme.card)
        .overlay(alignment: .top) { HazardStripe(stripe: 8).frame(height: 10) }
        .overlay { Bolts() }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
    }

    private func cell(_ n: Int, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text("\(n)").font(Theme.number(30)).foregroundStyle(Theme.accent)
            Text(label).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Theme.sub)
        }
        .frame(maxWidth: .infinity)
    }
}

/// やり方を選ぶ（効く所から）
struct MovesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Move.allCases) { m in
                        Button { model.choose(m) } label: { row(m) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("move.\(m.rawValue)")
                    }
                    Text(tr("やり方ごとに建物の種類が変わります。1 日の中で混ぜると、階ごとに違う建物が積み上がります", "Each move raises a different kind of building. Mix them in a day for a stacked, mixed-style tower"))
                        .font(.system(size: 12)).foregroundStyle(Theme.sub).padding(.top, 4)
                }
                .padding(18)
            }
            .background(Theme.paper)
            .navigationTitle(tr("今日のやり方", "Today's move"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(tr("閉じる", "Close")) { model.activeSheet = nil } }
            }
        }
    }

    private func row(_ m: Move) -> some View {
        HStack(spacing: 14) {
            BuildingView(build: Self.preview(m), theme: .dusk, minFloors: 4, crane: false)
                .frame(width: 58, height: 74)
                .background(LinearGradient(gradient: CityPalette.of(.dusk).sky, startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(m.name).font(Theme.display(17)).foregroundStyle(Theme.ink)
                    Text("→ " + m.building).font(.system(size: 12)).foregroundStyle(Theme.sub)
                    if m.isPro && !model.isPro { Image(systemName: "lock").font(.system(size: 10)).foregroundStyle(Theme.sub) }
                }
                Text(m.target).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.deep)
                Text(m.howTo).font(.system(size: 12)).foregroundStyle(Theme.sub).lineLimit(2)
            }
            Spacer(minLength: 0)
            if model.move == m { Image(systemName: "checkmark.square.fill").font(.system(size: 20)).foregroundStyle(Theme.accent) }
        }
        .padding(12)
        .background(model.move == m ? Theme.soft : Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(model.move == m ? Theme.accent : Theme.line, lineWidth: model.move == m ? 1.5 : Theme.hairline))
    }

    static func preview(_ m: Move) -> DayBuild {
        if m.isHold { return DayBuild(day: "2026-01-01", blocks: [], foundationSeconds: 90) }
        return DayBuild(day: "2026-01-01", blocks: (0..<4).map { Block(quality: $0 == 2 ? .normal : .sturdy, move: m) })
    }
}

/// 街の記録：街に置かれた物（40 種）と、建てた月
struct TownView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 0) {
                        cell(model.ledger.totalBlocks, tr("通算ブロック", "total blocks"))
                        cell(model.ledger.builtDays, tr("建てた日", "days built"))
                        cell(model.ledger.totalFoundation, tr("土台の秒", "foundation sec"))
                    }
                    Eyebrow(text: trf("街に置かれた物 %d / %d", "Landmarks %d / %d", model.ledger.landmarks.count, Landmark.catalog.count), color: Theme.accent)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                        ForEach(Landmark.catalog) { mark in
                            let got = mark.threshold <= model.ledger.totalBlocks
                            VStack(spacing: 6) {
                                Canvas { ctx, size in
                                    CityDraw.landmark(&ctx, mark.shape, at: CGPoint(x: size.width / 2, y: size.height - 4), size: 26, palette: .of(.day))
                                }
                                .frame(height: 44)
                                .opacity(got ? 1 : 0.25)
                                Text(got ? mark.name : "？").font(.system(size: 11)).foregroundStyle(got ? Theme.ink : Theme.sub).lineLimit(2).multilineTextAlignment(.center)
                                Text(trf("%d ブロック", "%d blocks", mark.threshold)).font(.system(size: 9.5)).monospacedDigit().foregroundStyle(Theme.sub)
                            }
                            .frame(maxWidth: .infinity, minHeight: 104)
                            .padding(6)
                            .background(got ? Theme.card : Theme.hazardBlack.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(got ? Theme.accent.opacity(0.5) : Theme.line, style: got ? StrokeStyle(lineWidth: 1) : StrokeStyle(lineWidth: 1, dash: [4, 3])))
                            .accessibilityElement(children: .combine)
                        }
                    }
                    Eyebrow(text: tr("建てた月", "Past months"), color: Theme.accent)
                    let months = model.ledger.months(calendar: model.calendar)
                    if months.isEmpty {
                        Text(tr("まだ建てた月はありません。最初の 1 回で、今月の 1 棟目が建ちます", "No months yet. Your first rep raises this month's first building"))
                            .font(.system(size: 13)).foregroundStyle(Theme.sub)
                    }
                    ForEach(months, id: \.self) { start in
                        monthRow(start)
                    }
                }
                .padding(18)
            }
            .background(Theme.paper)
            .navigationTitle(tr("街の記録", "City records"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(tr("閉じる", "Close")) { model.activeSheet = nil } }
            }
        }
    }

    @ViewBuilder
    private func monthRow(_ start: Date) -> some View {
        let isCurrent = model.calendar.isDate(start, equalTo: model.now, toGranularity: .month)
        let locked = !isCurrent && !model.isPro
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Self.title(start)).font(Theme.display(15)).foregroundStyle(Theme.ink)
                Spacer()
                if locked { Label("Pro", systemImage: "lock").font(.system(size: 11)).foregroundStyle(Theme.sub) }
            }
            SkylineView(builds: model.ledger.month(containing: start, calendar: model.calendar), theme: model.theme)
                .frame(height: 110)
                .blur(radius: locked ? 6 : 0)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                .onTapGesture { if locked { model.activeSheet = .paywall(.pastMonths) } }
        }
    }

    static func title(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Lang.locale
        f.setLocalizedDateFormatFromTemplate(Lang.isJapanese ? "yMMMM" : "MMMM y")
        return f.string(from: date)
    }

    private func cell(_ n: Int, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text("\(n)").font(Theme.number(30)).foregroundStyle(Theme.accent)
            Text(label).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Theme.sub)
        }
        .frame(maxWidth: .infinity)
    }
}
