import SwiftUI

/// 最初の 3 ページ：1 回が 1 ブロック → ゆっくりは頑丈 → 持ち方と、動きは外に送らない
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var demoBlocks = 3

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            SiteBackdrop().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 1).fill(i <= page ? Theme.accent : Theme.line).frame(width: i == page ? 28 : 10, height: 5)
                    }
                }
                .padding(.top, 12)
                Group {
                    switch page {
                    case 0: pageOne
                    case 1: pageTwo
                    default: pageThree
                    }
                }
                .transition(.opacity)
                .id(page)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                model.press()
                if page < 2 {
                    withAnimation(.easeOut(duration: 0.3)) { page += 1 }
                } else {
                    model.onboarded = true
                }
            } label: {
                Text(page < 2 ? tr("つぎへ", "Next") : tr("街をつくりはじめる", "Start my city"))
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(page < 2 ? "main.next" : "main.start")
            .padding(.horizontal, 24).padding(.vertical, 8)
            .frame(maxWidth: 560)
        }
        .task {
            // 動く見本：ブロックが 1 つずつ積み上がる（動きを減らす設定では止めた絵）
            guard !reduceMotion, !Launch.isStill else { demoBlocks = 8; return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) { demoBlocks = demoBlocks >= 10 ? 3 : demoBlocks + 1 }
            }
        }
    }

    private var pageOne: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: tr("しゃがんで建てる", "Squat City"), color: Theme.accent)
            Text(tr("しゃがんで立つ 1 回が、\nビルの 1 ブロックになる", "One squat,\none block of your building"))
                .font(Theme.display(30)).foregroundStyle(Theme.ink)
            BuildingView(build: DayBuild(day: "2026-01-01", blocks: (0..<demoBlocks).map { Block(quality: $0 % 4 == 2 ? .normal : .sturdy, move: .squat) }), goal: 10)
                .frame(height: 280)
            Text(tr("今日の回数が今日のビルの高さに。1 か月で、あなたの通りのスカイラインができます", "Today's reps set today's height. In a month, your street has a skyline"))
                .font(.system(size: 14)).foregroundStyle(Theme.sub)
        }
    }

    private var pageTwo: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: tr("ゆっくりが強い", "Slow is strong"), color: Theme.accent)
            Text(tr("2 秒かけて下ろすと、\n頑丈なブロック", "Lower for 2 seconds\nfor a solid block"))
                .font(Theme.display(30)).foregroundStyle(Theme.ink)
            HStack(alignment: .bottom, spacing: 18) {
                sample(.sturdy, tr("2 秒以上", "2 sec+"), lean: 0)
                sample(.normal, tr("1〜2 秒", "1–2 sec"), lean: 0)
                sample(.wobbly, tr("1 秒未満", "under 1 sec"), lean: 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            Text(tr("速いとぐらぐらのブロックになり、ビルが少し傾きます。空気椅子の秒は土台になり、敷地が広がります", "Rush it and blocks wobble, tilting the building. Holding a low sit lays a foundation and widens the lot"))
                .font(.system(size: 14)).foregroundStyle(Theme.sub)
        }
    }

    private func sample(_ q: BlockQuality, _ label: String, lean: Double) -> some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                ForEach(0..<4) { _ in
                    RoundedRectangle(cornerRadius: 2).fill(q.fill)
                        .overlay(RoundedRectangle(cornerRadius: 1).fill(Theme.window.opacity(q == .wobbly ? 0.25 : 0.8)).frame(width: 8, height: 10))
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(q.stroke, style: q == .wobbly ? StrokeStyle(lineWidth: 1.1, dash: [3, 2]) : StrokeStyle(lineWidth: q == .sturdy ? 1.5 : 1.1)))
                        .frame(width: 58, height: 26)
                }
            }
            .rotationEffect(.degrees(lean), anchor: .bottom)
            Text(q.name).font(Theme.display(16)).foregroundStyle(q.stroke)
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.sub)
        }
        .accessibilityElement(children: .combine)
    }

    private var pageThree: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: tr("持ち方", "How to hold"), color: Theme.accent)
            Text(tr("胸に当てるか、\n前のポケットへ", "Hold it to your chest,\nor slip it in a front pocket"))
                .font(Theme.display(30)).foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 12) {
                tip("hand.raised", tr("立った姿勢から、どれだけ傾いたかで数えます。判定はゆるめ。深くしゃがんでも弾きません", "Reps are counted from how far you tilt from standing. Detection is easy-going; going deeper never fails"))
                tip("plus.circle", tr("数え漏れたら、画面の ＋1 で足せます", "Missed one? Add it with +1"))
                tip("number", tr("回数は自分で決めます。エンドレスもあります", "You choose the reps. There's an endless mode too"))
                tip("lock.shield", tr("動きはこの iPhone の中で数えるためだけに使い、外に送りません", "Motion is only used on this iPhone to count. Nothing leaves the device"))
            }
        }
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.hazardBlack).frame(width: 30, height: 30).background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.radiusS))
            Text(text).font(.system(size: 14)).foregroundStyle(Theme.ink)
        }
    }
}
