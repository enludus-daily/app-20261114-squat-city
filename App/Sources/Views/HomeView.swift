import SwiftUI

/// ホーム：今月の通り（スカイライン）・今日の注文・回数を決めて建てる。
/// iPhone Duo の内側など広い画面（regular）では、左に街、右に今日の回数と次のブロック
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// 全画面の場面・シートの下にいる間は、主なボタンの印を外す（UI テストが隠れたボタンを探さないように）
    private var covered: Bool { model.cover != nil || model.activeSheet != nil }
    private func mainID(_ name: String) -> String { covered ? "home.covered." + name : "main." + name }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            Blueprint().ignoresSafeArea().opacity(0.6)
            // 見出しと「建てはじめる」は固定し、真ん中だけをスクロールする（主なボタンがスクロールの下に重ならない）
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, sizeClass == .regular ? 28 : 18)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 28) {
                        VStack(alignment: .leading, spacing: 16) {
                            city(height: 400)
                            stats
                        }
                        .frame(maxWidth: .infinity)
                        ScrollView {
                            VStack(spacing: 14) {
                                commissionPlate
                                planPlate
                                townLink
                            }
                        }
                        .frame(maxWidth: 380)
                    }
                    .padding(.horizontal, 28)
                    .frame(maxHeight: .infinity, alignment: .top)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            city(height: 250)
                            stats
                            commissionPlate
                            planPlate
                            townLink
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 16)
                    }
                    .frame(maxHeight: .infinity)
                }
                buildBar
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: model.showsSample ? tr("見本の街", "Sample city") : model.monthTitle)
                Text(tr("しゃがんで建てる", "Squat City"))
                    .font(Theme.serif(30))
                    .kerning(-0.8)
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Button { model.press(); model.activeSheet = .share } label: {
                Image(systemName: "square.and.arrow.up").font(.system(size: 16, weight: .regular))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(Theme.deep)
            .accessibilityLabel(tr("今月の街を共有", "Share this month's city"))
            .accessibilityIdentifier(mainID("share"))
            Button { model.press(); model.activeSheet = .settings } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 16, weight: .regular))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(Theme.deep)
            .accessibilityLabel(tr("設定", "Settings"))
            .accessibilityIdentifier(mainID("settings"))
        }
    }

    private func city(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SkylineView(builds: model.monthBuilds, todayIndex: model.todayIndex, theme: model.theme, landmarks: model.cityForDisplay.landmarks)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).stroke(Theme.line, lineWidth: Theme.hairline))
                .overlay(alignment: .topLeading) {
                    if model.showsSample {
                        Text(tr("見本：1 日 1 棟、1 回が 1 ブロック", "Sample: one building a day, one block a rep"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.deep)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.card.opacity(0.9), in: Capsule())
                            .padding(10)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(trf("今月の街。%d 棟、%d ブロック", "This month's city: %d buildings, %d blocks",
                                        model.monthBuilds.filter { !$0.isEmpty }.count, model.monthBuilds.reduce(0) { $0 + $1.height }))
            HStack(spacing: 6) {
                ForEach(CityTheme.allCases) { t in
                    Button { model.choose(t) } label: {
                        HStack(spacing: 4) {
                            Text(t.name)
                            if t.isPro && !model.isPro { Image(systemName: "lock").font(.system(size: 9)) }
                        }
                        .font(.system(size: 12, weight: model.theme == t ? .semibold : .regular))
                        .foregroundStyle(model.theme == t ? Theme.deep : Theme.sub)
                        .padding(.horizontal, 10).frame(height: 30)
                        .background(model.theme == t ? Theme.soft : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat(value: model.today.height, label: tr("今日のブロック", "Blocks today"))
            divider
            stat(value: model.monthBlocks, label: tr("今月", "This month"))
            divider
            stat(value: model.streak, label: tr("続けた日", "Day streak"))
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: Theme.hairline) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: Theme.hairline) }
    }

    private var divider: some View { Rectangle().fill(Theme.line).frame(width: Theme.hairline, height: 34) }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(Theme.serif(30))
                .kerning(-1.5)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Theme.ink)
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.sub)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var commissionPlate: some View {
        let c = model.commission
        let progress = c.progress(model.today)
        return Plate {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Eyebrow(text: tr("今日の注文", "Today's commission"))
                    Spacer()
                    if progress >= 1 {
                        Label(tr("済み", "Done"), systemImage: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.deep)
                    }
                }
                Text(c.title).font(Theme.serif(19)).foregroundStyle(Theme.ink)
                Text(c.requirement).font(.system(size: 13)).foregroundStyle(Theme.sub)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.soft)
                        Capsule().fill(Theme.accent).frame(width: max(6, geo.size.width * progress))
                    }
                }
                .frame(height: 5)
                Text(trf("ごほうび：屋上に「%@」", "Reward: %@ on today's roof", c.ornament.name))
                    .font(.system(size: 12)).foregroundStyle(Theme.deep)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var planPlate: some View {
        @Bindable var model = model
        return Plate {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow(text: tr("今日のやり方", "Today's move"))
                    Spacer()
                    Button { model.press(); model.activeSheet = .moves } label: {
                        Text(tr("やり方を選ぶ", "Choose move")).font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Theme.deep)
                    .accessibilityIdentifier("home.moves")
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(model.move.name).font(Theme.serif(21)).foregroundStyle(Theme.ink)
                    Text("→ " + model.move.building).font(.system(size: 13)).foregroundStyle(Theme.sub)
                }
                Text(model.move.howTo).font(.system(size: 12.5)).foregroundStyle(Theme.sub)
                if !model.move.isHold {
                    HStack(spacing: 10) {
                        Button { model.press(); model.goalCount = max(Goal.range.lowerBound, model.goalCount - 1); model.endless = false } label: {
                            Image(systemName: "minus").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(tr("1 回へらす", "One fewer"))
                        VStack(spacing: 0) {
                            Text(model.endless ? "∞" : "\(model.goalCount)")
                                .font(Theme.serif(38)).kerning(-2).monospacedDigit()
                                .contentTransition(.numericText())
                                .foregroundStyle(Theme.ink)
                            Text(model.endless ? tr("エンドレス", "Endless") : tr("回（自分で決める）", "reps — your call"))
                                .font(.system(size: 11)).foregroundStyle(Theme.sub)
                        }
                        .frame(maxWidth: .infinity)
                        Button { model.press(); model.goalCount = min(Goal.range.upperBound, model.goalCount + 1); model.endless = false } label: {
                            Image(systemName: "plus").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(tr("1 回ふやす", "One more"))
                    }
                    .foregroundStyle(Theme.deep)
                    HStack(spacing: 8) {
                        ForEach([10, 20, 30], id: \.self) { n in
                            Button("\(n)") { model.press(); model.goalCount = n; model.endless = false }
                                .buttonStyle(QuietButtonStyle())
                        }
                        Button(tr("エンドレス", "Endless")) { model.press(); model.endless = true }
                            .buttonStyle(QuietButtonStyle())
                            .accessibilityIdentifier("home.endless")
                    }
                } else {
                    Text(tr("保った秒が土台になり、その日のビルの敷地が広がります（30 秒で 1 マス）", "Seconds you hold become the foundation and widen today's lot (1 cell per 30 sec)"))
                        .font(.system(size: 12.5)).foregroundStyle(Theme.deep)
                }
            }
        }
    }

    private var townLink: some View {
        Button { model.press(); model.activeSheet = .town } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow(text: tr("街の記録", "City records"))
                    if let next = model.ledger.nextLandmark {
                        Text(trf("次に置かれる物：%@（あと %d ブロック）", "Next to appear: %@ (%d blocks to go)", next.name, next.threshold - model.ledger.totalBlocks))
                            .font(.system(size: 13)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                    }
                    Text(trf("街に置かれた物 %d / %d", "Landmarks %d / %d", model.ledger.landmarks.count, Landmark.catalog.count))
                        .font(.system(size: 12)).foregroundStyle(Theme.sub)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.sub)
            }
        }
        .buttonStyle(.plain)
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.line, lineWidth: Theme.hairline))
        .accessibilityIdentifier("home.town")
    }

    private var buildBar: some View {
        VStack(spacing: 6) {
            Button { model.startSession() } label: {
                HStack(spacing: 8) {
                    Image(systemName: model.move.isHold ? "square.stack.3d.down.right" : "building.2")
                    Text(model.move.isHold ? tr("土台をつくる", "Lay the foundation") : tr("建てはじめる", "Start building"))
                    if model.move.isPro && !model.isPro { Image(systemName: "lock") }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(mainID("build"))
            Text(tr("iPhone を胸に当てるか、前のポケットへ", "Hold your iPhone to your chest, or put it in a front pocket"))
                .font(.system(size: 11)).foregroundStyle(Theme.sub)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: sizeClass == .regular ? 420 : .infinity)
        .frame(maxWidth: .infinity)
        .background(Theme.paper.opacity(0.96).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: Theme.hairline) }
    }
}
