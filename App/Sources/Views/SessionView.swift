import SwiftUI

/// 建てる：1 回ごとにブロックが落ちてきて、今日のビルが伸びる（Forest の「真ん中で育つ 1 つの物」）
struct SessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drop: Double = 1

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            SiteBackdrop().ignoresSafeArea()
            if let s = model.session {
                if sizeClass == .regular {
                    HStack(spacing: 32) {
                        building(s).frame(maxWidth: .infinity)
                        VStack(spacing: 18) { counter(s); feedback(s); manual(s) }
                            .frame(maxWidth: 380)
                    }
                    .padding(32)
                } else {
                    VStack(spacing: 10) {
                        topBar(s)
                        building(s).frame(maxHeight: .infinity)
                        counter(s)
                        feedback(s)
                        manual(s)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { model.finishSession() } label: {
                Label(tr("今日はここまで", "Done for today"), systemImage: "flag.checkered")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("main.finish")
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .frame(maxWidth: sizeClass == .regular ? 420 : .infinity)
            .frame(maxWidth: .infinity)
            .background(Theme.paper.opacity(0.96))
        }
        .onChange(of: model.session?.blocks.count ?? 0) { _, _ in
            guard !reduceMotion, !Launch.isStill else { return }
            drop = 0
            withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) { drop = 1 }
        }
    }

    private func topBar(_ s: Session) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: s.move.name + " → " + s.move.building, color: Theme.accent)
                Text(model.commission.title).font(Theme.display(15)).foregroundStyle(Theme.ink).lineLimit(1)
            }
            Spacer()
            CommissionRing(progress: model.commission.progress(model.today))
                .frame(width: 34, height: 34)
                .accessibilityLabel(tr("今日の注文の進み具合", "Commission progress"))
        }
    }

    private func building(_ s: Session) -> some View {
        BuildingView(build: model.today, goal: s.goalCount, theme: model.theme, drop: drop)
            .accessibilityElement()
            .accessibilityLabel(trf("今日のビル %d 階", "Today's building: %d floors", model.today.height))
    }

    @ViewBuilder
    private func counter(_ s: Session) -> some View {
        if s.move.isHold {
            VStack(spacing: 2) {
                Text(String(format: "%.0f", s.hold.seconds))
                    .font(Theme.number(88))
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.accent)
                Text(trf("秒　→ 敷地 %d マス", "sec → lot of %d cells", min(5, 2 + (model.today.foundationSeconds + Int(s.hold.seconds)) / 30)))
                    .font(.system(size: 13)).foregroundStyle(Theme.sub)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(s.blocks.count)")
                    .font(Theme.number(88))
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.accent)
                if let g = s.goalCount {
                    Text("/ \(g)").font(Theme.display(24)).foregroundStyle(Theme.sub)
                } else {
                    Text("∞").font(Theme.display(24)).foregroundStyle(Theme.sub)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("session.count")
        }
    }

    @ViewBuilder
    private func feedback(_ s: Session) -> some View {
        VStack(spacing: 8) {
            DepthGauge(ratio: model.depthOverride ?? s.counter.depthRatio,
                       threshold: s.counter.sensitivity.downDegrees / (s.counter.sensitivity.downDegrees * 1.6),
                       live: s.sensorLive)
                .frame(height: 22)
            Group {
                if s.reachedGoal {
                    Text(tr("目標の高さに届きました。続けても、ここで終えても", "You reached your goal height. Keep going, or call it a day"))
                } else if let rep = s.lastRep {
                    switch rep.quality {
                    case .sturdy: Text(trf("頑丈なブロック（%.1f 秒で下ろした）", "Solid block (lowered in %.1f sec)", rep.descent))
                    case .normal: Text(trf("ふつうのブロック（%.1f 秒）。2 秒かけると頑丈に", "Plain block (%.1f sec). Take 2 sec for solid", rep.descent))
                    case .wobbly: Text(trf("ぐらぐら（%.1f 秒）。ビルが少し傾きます", "Wobbly (%.1f sec). The building leans a little", rep.descent))
                    }
                } else if s.move.isHold {
                    Text(s.sensorLive ? tr("しゃがんだ姿勢で止まると、秒が進みます", "Hold the low position and the seconds count up")
                         : tr("この端末では動きを読めません。始めると時計で数えます", "This device can't read motion. Start the timer instead"))
                } else {
                    Text(s.sensorLive ? tr("2 秒かけて下ろし、1 秒で立つ。立ったら 1 ブロック", "Lower for 2 sec, stand in 1. Each stand places a block")
                         : tr("この端末では動きを読めません。1 回ごとに ＋1 を押してください", "This device can't read motion. Tap +1 after each rep"))
                }
            }
            .foregroundStyle(s.lastRep?.quality == .wobbly ? Theme.cone : Theme.deep)
            .font(.system(size: 13, weight: .semibold))
            .multilineTextAlignment(.center)
            .frame(minHeight: 34)
        }
    }

    @ViewBuilder
    private func manual(_ s: Session) -> some View {
        if s.move.isHold {
            if !s.sensorLive {
                Button { model.toggleManualHold() } label: {
                    Label(s.manualHoldRunning ? tr("止める", "Stop") : tr("時計で数える", "Start timer"), systemImage: s.manualHoldRunning ? "pause" : "timer")
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("main.hold")
            }
        } else {
            Button { model.addByHand() } label: {
                Label(s.sensorLive ? tr("数え漏れを ＋1", "Missed one? +1") : "＋1", systemImage: "plus")
                    .frame(minWidth: s.sensorLive ? 0 : 120)
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityIdentifier("main.plus")
        }
    }
}

/// しゃがみの深さの目盛り（細い線。しゃがんだと数える所に印）
struct DepthGauge: View {
    var ratio: Double
    var threshold: Double
    var live: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Theme.hazardBlack).frame(height: 10)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.line, lineWidth: 1))
                Group {
                    if ratio >= threshold {
                        HazardStripe(stripe: 6)
                    } else {
                        Theme.amber
                    }
                }
                .frame(width: max(8, w * ratio), height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .animation(.easeOut(duration: 0.12), value: ratio)
                Rectangle().fill(Theme.accent).frame(width: 2, height: 18).offset(x: w * threshold)
                Text(tr("しゃがむ", "LOW")).font(.system(size: 9, weight: .black).width(.condensed)).foregroundStyle(Theme.accent)
                    .offset(x: w * threshold + 5, y: -12)
            }
            .frame(maxHeight: .infinity)
        }
        .opacity(live ? 1 : 0.35)
        .accessibilityHidden(true)
    }
}

/// 今日の注文の進み具合（細い輪）
struct CommissionRing: View {
    var progress: Double
    var body: some View {
        ZStack {
            Circle().stroke(Theme.line, lineWidth: 3)
            Circle().trim(from: 0, to: progress).stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .butt)).rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))").font(.system(size: 11, weight: .black).width(.condensed)).monospacedDigit().foregroundStyle(Theme.accent)
        }
    }
}
