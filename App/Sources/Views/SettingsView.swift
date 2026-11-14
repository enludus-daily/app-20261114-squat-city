import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Picker(tr("判定のゆるさ", "Detection"), selection: $model.sensitivity) {
                        ForEach(Sensitivity.allCases) { s in Text(s.name).tag(s) }
                    }
                    .pickerStyle(.segmented)
                    Text(tr("数えにくいときは「ゆるめ」に。深くしゃがんでも、行き過ぎで弾くことはありません。数え漏れは建てる画面の ＋1 で足せます",
                            "If reps are missed, pick Easy. Going deeper never fails a rep. You can always add a missed one with +1"))
                        .font(.system(size: 12)).foregroundStyle(Theme.sub)
                } header: { Text(tr("数え方", "Counting")) }

                Section {
                    Toggle(tr("声で数える（小さめ）", "Count out loud (quietly)"), isOn: $model.voiceOn)
                    Toggle(tr("振動", "Haptics"), isOn: $model.hapticsOn)
                } header: { Text(tr("音と振動", "Sound & haptics")) }

                Section {
                    ForEach(CityTheme.allCases) { t in
                        Button { model.choose(t) } label: {
                            HStack {
                                Text(t.name).foregroundStyle(Theme.ink)
                                Spacer()
                                if t.isPro && !model.isPro { Image(systemName: "lock").foregroundStyle(Theme.sub) }
                                if model.theme == t { Image(systemName: "checkmark").foregroundStyle(Theme.deep) }
                            }
                        }
                    }
                } header: { Text(tr("街の見た目", "City look")) }

                Section {
                    Button(model.isPro ? tr("Pro を使っています。ありがとうございます", "You're on Pro. Thank you") : tr("Pro を見る", "See Pro")) {
                        model.activeSheet = .paywall(.settings)
                    }
                    .disabled(model.isPro)
                    Button(tr("購入を復元", "Restore purchase")) { Task { await model.purchases.restore() } }
                } header: { Text("Pro") }

                Section {
                    Button(tr("使い方をもう一度見る", "Show the intro again")) {
                        model.activeSheet = nil
                        model.onboarded = false
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("動きのデータは回数を数えるためだけに、この iPhone の中で使います。外には送りません。ログインも広告もありません",
                                "Motion data is only used on this iPhone to count reps. Nothing is sent anywhere. No login, no ads"))
                        Text(tr("痛みがあるときは休んでください。ひざがつま先より前に出すぎないように", "Rest if anything hurts. Keep your knees from drifting far past your toes"))
                    }
                    .font(.system(size: 12)).foregroundStyle(Theme.sub)
                } header: { Text(tr("そのほか", "Other")) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .tint(Theme.deep)
            .navigationTitle(tr("設定", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("閉じる", "Close")) { model.activeSheet = nil }.accessibilityIdentifier("main.closeSettings")
                }
            }
        }
    }
}

/// Pro の案内。値段・購入・復元は下に固定して、スクロールなしで見える
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    let reason: PaywallReason
    @State private var buying = false
    @State private var message: String?

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Spacer()
                        Button { model.activeSheet = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                            .foregroundStyle(Theme.sub)
                            .accessibilityLabel(tr("閉じる", "Close"))
                            .accessibilityIdentifier("main.closePaywall")
                    }
                    Eyebrow(text: headline)
                    Text(tr("街を、もっと自分のものに", "Make the city truly yours"))
                        .font(Theme.serif(28)).kerning(-0.6).foregroundStyle(Theme.ink)
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach([Move.wide, .bulgarian, .jump, .lunge]) { m in
                            BuildingView(build: MovesView.preview(m), theme: .dusk)
                                .frame(maxWidth: .infinity).frame(height: 96)
                        }
                    }
                    .padding(8)
                    .background(Theme.soft.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
                    benefit("building.columns", tr("やり方 4 種と建物 4 種", "4 moves, 4 building styles"),
                            tr("ワイド＝倉庫、ブルガリアン＝塔、ジャンプ＝灯台、ランジ＝時計塔。効く所を選べます", "Wide = warehouse, Bulgarian = tower, Jump = lighthouse, Lunge = clock tower. Pick what you train"))
                    benefit("moon.stars", tr("夜景と雪の街", "Night and snow cities"),
                            tr("同じ街が、窓に明かりの点く夜景や雪景色に", "Your city with lit windows at night, or under snow"))
                    benefit("play.rectangle", tr("月のタイムラプス", "Month timelapse"),
                            tr("1 日目から 1 棟ずつ建っていく様子を再生", "Watch the month rise, one building a day"))
                    benefit("calendar", tr("過去の月の街", "Every past month"),
                            tr("先月も、去年の夏も。月ごとのスカイラインを見返せます", "Last month, last summer: revisit every skyline"))
                    Text(tr("スクワット・空気椅子・街づくり・今日の注文・共有は、ずっと無料です", "Squats, holds, city building, daily commissions and sharing stay free forever"))
                        .font(.system(size: 12)).foregroundStyle(Theme.sub)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }
        }
        .safeAreaInset(edge: .bottom) { buyBar }
    }

    private var headline: String {
        switch reason {
        case .thirdBuilding: tr("3 棟目が建ちました", "Your third building is up")
        case .move(let m): trf("%@は Pro のやり方です", "%@ is a Pro move", m.name)
        case .theme(let t): trf("「%@」は Pro の街です", "%@ is a Pro look", t.name)
        case .timelapse: tr("タイムラプスのお試しは使い終わりました", "You've used your free timelapse")
        case .pastMonths: tr("過去の月は Pro で見返せます", "Past months come with Pro")
        case .settings: "Pro"
        }
    }

    private func benefit(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Theme.deep).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.system(size: 12.5)).foregroundStyle(Theme.sub)
            }
        }
    }

    private var buyBar: some View {
        let product = model.purchases.products.first
        return VStack(spacing: 8) {
            if let message { Text(message).font(.system(size: 12)).foregroundStyle(Theme.deep) }
            Button {
                guard let product else { return }
                buying = true
                Task {
                    let outcome = await model.purchases.purchase(product)
                    buying = false
                    switch outcome {
                    case .purchased: model.activeSheet = nil
                    case .pending: message = tr("承認を待っています", "Waiting for approval")
                    case .failed: message = tr("購入できませんでした。時間をおいてもう一度", "Purchase failed. Please try again later")
                    case .cancelled: break
                    }
                }
            } label: {
                if let product {
                    Text(trf("Pro にする　%@（買い切り）", "Get Pro · %@ one-time", product.displayPrice))
                } else {
                    Text(model.purchases.loadState == .loading ? tr("読み込み中…", "Loading…") : tr("いまは購入できません", "Not available right now"))
                }
            }
            .buttonStyle(PrimaryButtonStyle(enabled: product != nil && !buying))
            .disabled(product == nil || buying)
            .accessibilityIdentifier("main.buy")
            HStack(spacing: 18) {
                Button(tr("購入を復元", "Restore purchase")) { Task { await model.purchases.restore(); if model.isPro { model.activeSheet = nil } } }
                Text(tr("家族で共有できます", "Family Sharing supported")).foregroundStyle(Theme.sub)
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.deep)
            if product == nil && model.purchases.loadState != .loading {
                Text(tr("通信のよい所で開き直すと、値段が出ます", "Reopen with a connection to see the price"))
                    .font(.system(size: 11)).foregroundStyle(Theme.sub)
            }
        }
        .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 6)
        .background(Theme.paper.opacity(0.97))
    }
}
