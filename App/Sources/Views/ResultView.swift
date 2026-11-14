import SwiftUI

/// 終わったあと：今日のビル・ブロックの出来・注文のごほうび・街に置かれた物・次の回数の提案
struct ResultView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            Blueprint().ignoresSafeArea().opacity(0.6)
            if let r = model.result {
                if sizeClass == .regular {
                    HStack(spacing: 32) {
                        building.frame(maxWidth: .infinity)
                        ScrollView { details(r) }.frame(maxWidth: 400)
                    }
                    .padding(32)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            building.frame(height: 260)
                            details(r)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { model.closeResult() } label: { Text(tr("街に戻る", "Back to the city")) }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("main.done")
                .padding(.horizontal, 18).padding(.vertical, 8)
                .frame(maxWidth: sizeClass == .regular ? 420 : .infinity)
                .frame(maxWidth: .infinity)
                .background(Theme.paper.opacity(0.96))
        }
        .onAppear {
            if reduceMotion || Launch.isStill { shown = true } else { withAnimation(.easeOut(duration: 0.5).delay(0.15)) { shown = true } }
        }
    }

    private var building: some View {
        BuildingView(build: model.today, theme: model.theme)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            .accessibilityElement()
            .accessibilityLabel(trf("今日のビル %d 階", "Today's building: %d floors", model.today.height))
    }

    private func details(_ r: SessionResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: tr("今日のビル", "Today's building"))
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if r.move.isHold {
                        Text("+\(r.foundationSeconds)").font(Theme.serif(52)).kerning(-3).monospacedDigit().foregroundStyle(Theme.ink)
                        Text(tr("秒の土台", "sec of foundation")).font(.system(size: 14)).foregroundStyle(Theme.sub)
                    } else {
                        Text("+\(r.blocks)").font(Theme.serif(52)).kerning(-3).monospacedDigit().foregroundStyle(Theme.ink)
                        Text(trf("ブロック　いま %d 階", "blocks · now %d floors", r.buildHeight)).font(.system(size: 14)).foregroundStyle(Theme.sub)
                    }
                }
            }
            if !r.move.isHold && r.blocks > 0 {
                QualityBars(sturdy: r.sturdy, normal: r.blocks - r.sturdy - r.wobbly, wobbly: r.wobbly)
                let lean = model.today.leanDegrees
                Text(lean > 0.5
                     ? trf("ぐらぐらが多く、ビルが %.1f 度傾いています。頑丈なブロックを足すと、まっすぐに戻ります", "Too many wobbly blocks: the building leans %.1f°. Add solid blocks to straighten it", lean)
                     : tr("まっすぐ建っています。ゆっくり下ろせた証拠です", "Standing straight. That's slow, steady lowering"))
                    .font(.system(size: 13)).foregroundStyle(Theme.deep)
            }
            if r.commissionDone, let o = r.ornament {
                Plate {
                    HStack(spacing: 10) {
                        Image(systemName: "seal").foregroundStyle(Theme.deep)
                        Text(trf("今日の注文を済ませました。屋上に「%@」", "Commission complete: %@ added to the roof", o.name))
                            .font(.system(size: 14)).foregroundStyle(Theme.ink)
                    }
                }
            }
            ForEach(r.newLandmarks, id: \.self) { name in
                Plate {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkle").foregroundStyle(Theme.deep)
                        Text(trf("街に「%@」が置かれました", "%@ appeared in your city", name)).font(.system(size: 14)).foregroundStyle(Theme.ink)
                    }
                }
            }
            if let n = r.suggestion {
                Plate {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(n > (model.goalCount) ? trf("いい出来です。次は %d 回にしますか", "Great form. Make it %d next time?", n)
                             : trf("今日は %d 回。次の目標を %d 回にしますか", "You did %d today. Set the next goal to %d?", r.blocks, n))
                            .font(.system(size: 14)).foregroundStyle(Theme.ink)
                        Button(trf("%d 回にする", "Set to %d", n)) { model.acceptSuggestion(n) }
                            .buttonStyle(QuietButtonStyle())
                            .accessibilityIdentifier("result.accept")
                    }
                }
            }
            if let next = model.ledger.nextLandmark {
                Text(trf("次に街に置かれる物：%@（あと %d ブロック）", "Next landmark: %@ (%d blocks to go)", next.name, next.threshold - model.ledger.totalBlocks))
                    .font(.system(size: 12)).foregroundStyle(Theme.sub)
            }
        }
    }
}

/// ブロックの出来の内訳（細い帯）
struct QualityBars: View {
    let sturdy: Int
    let normal: Int
    let wobbly: Int

    var body: some View {
        let total = max(1, sturdy + normal + wobbly)
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    segment(.sturdy, width: geo.size.width * CGFloat(sturdy) / CGFloat(total))
                    segment(.normal, width: geo.size.width * CGFloat(normal) / CGFloat(total))
                    segment(.wobbly, width: geo.size.width * CGFloat(wobbly) / CGFloat(total))
                }
            }
            .frame(height: 14)
            HStack(spacing: 14) {
                legend(.sturdy, sturdy)
                legend(.normal, normal)
                legend(.wobbly, wobbly)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trf("頑丈 %d、ふつう %d、ぐらぐら %d", "Solid %d, plain %d, wobbly %d", sturdy, normal, wobbly))
    }

    @ViewBuilder
    private func segment(_ q: BlockQuality, width: CGFloat) -> some View {
        if width > 0 {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(q.fill)
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(q.stroke, style: q == .wobbly ? StrokeStyle(lineWidth: 1, dash: [2.5, 2]) : StrokeStyle(lineWidth: q == .sturdy ? 1.3 : 1)))
                .frame(width: max(4, width - 2))
        }
    }

    private func legend(_ q: BlockQuality, _ n: Int) -> some View {
        HStack(spacing: 4) {
            Text(q.name).font(.system(size: 12)).foregroundStyle(Theme.sub)
            Text("\(n)").font(Theme.serif(15)).monospacedDigit().foregroundStyle(Theme.ink)
        }
    }
}
