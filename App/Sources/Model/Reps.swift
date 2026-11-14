import Foundation

/// 端末の動きの 1 つ分（重力の向き。CoreMotion の deviceMotion.gravity、単位は g）
struct MotionSample: Equatable, Sendable {
    var t: TimeInterval
    var x: Double
    var y: Double
    var z: Double
}

/// ブロックの出来。ゆっくり下ろすほど頑丈
enum BlockQuality: String, Codable, Sendable, CaseIterable {
    case sturdy, normal, wobbly

    /// 下ろすのにかかった秒から決める（2 秒以上で頑丈、1 秒未満でぐらつく）
    static func from(descent: TimeInterval) -> BlockQuality {
        if descent >= RepCounter.sturdySeconds { return .sturdy }
        if descent >= RepCounter.wobblySeconds { return .normal }
        return .wobbly
    }

    var name: String {
        switch self {
        case .sturdy: tr("頑丈", "Solid")
        case .normal: tr("ふつう", "Plain")
        case .wobbly: tr("ぐらぐら", "Wobbly")
        }
    }
}

/// 判定のゆるさ。既定はゆるめ（本人の実機の意見 2026-11-11：判定がシビアだと続かない）
enum Sensitivity: String, Codable, Sendable, CaseIterable, Identifiable {
    case easy, normal, strict
    var id: String { rawValue }

    /// しゃがんだと数える傾き（度）と、立ったと数える傾き（度）
    var downDegrees: Double {
        switch self {
        case .easy: 15
        case .normal: 22
        case .strict: 32
        }
    }

    var upDegrees: Double {
        switch self {
        case .easy: 7
        case .normal: 9
        case .strict: 12
        }
    }

    var name: String {
        switch self {
        case .easy: tr("ゆるめ", "Easy")
        case .normal: tr("標準", "Normal")
        case .strict: tr("きっちり", "Strict")
        }
    }
}

/// 数えた 1 回
struct Rep: Equatable, Sendable {
    /// 立った姿勢を離れてから、いちばん深い所の近くに届くまでの秒
    var descent: TimeInterval
    /// いちばん深い所の傾き（度）
    var depth: Double
    var quality: BlockQuality { .from(descent: descent) }
}

/// 立った姿勢からの傾きで、しゃがんで立つ 1 回を数える（画面から切り離してテストする）。
/// - 胸に当てても（上体が前に傾く）、前のポケットでも（太ももが水平に近づく）、傾きは同じ向きに増える
/// - 行き過ぎは弾かない（深くしゃがめたら、それも 1 回）
/// - 立っている間は、基準の向きを少しずつ合わせ直す（持ち直し・ずれに強くする）
struct RepCounter: Sendable {
    /// 画面では「2 秒かけて下ろす」と伝え、判定は少しゆるく 1.8 秒から頑丈にする（判定はゆるめが既定）
    static let sturdySeconds: TimeInterval = 1.8
    static let wobblySeconds: TimeInterval = 1.0
    /// これより短い上下は数えない（手の揺れ・歩き）
    static let minimumRepSeconds: TimeInterval = 0.6

    enum Phase: Equatable, Sendable { case calibrating, up, down }

    var sensitivity: Sensitivity
    private(set) var phase: Phase = .calibrating
    private(set) var count = 0
    /// いまの傾き（度。なめらかにしたもの）
    private(set) var angle: Double = 0
    /// 0〜1：しゃがみの深さの目安（画面の目盛り用）
    var depthRatio: Double { min(1, max(0, angle / (sensitivity.downDegrees * 1.6))) }

    private var baseline: SIMD3<Double>?
    private var calibration: [SIMD3<Double>] = []
    private var leaveTime: TimeInterval = 0
    private var trace: [(t: TimeInterval, angle: Double)] = []
    private var peak: Double = 0

    init(sensitivity: Sensitivity = .easy) {
        self.sensitivity = sensitivity
    }

    /// いまの姿勢を「立っている」として基準にする
    mutating func calibrate(to sample: MotionSample) {
        baseline = normalized(SIMD3(sample.x, sample.y, sample.z))
        calibration = []
        phase = .up
        angle = 0
        leaveTime = sample.t
    }

    /// 1 つ読み込む。1 回が終わったら返す
    mutating func feed(_ sample: MotionSample) -> Rep? {
        let v = normalized(SIMD3(sample.x, sample.y, sample.z))
        guard let base = baseline else {
            // 最初の 8 つ（約 0.15 秒）の平均を、立った姿勢の基準にする
            calibration.append(v)
            if calibration.count >= 8 {
                let sum = calibration.reduce(SIMD3<Double>(0, 0, 0), +)
                baseline = normalized(sum)
                calibration = []
                phase = .up
                leaveTime = sample.t
            }
            return nil
        }
        let raw = degrees(between: base, and: v)
        angle = angle * 0.55 + raw * 0.45

        switch phase {
        case .calibrating:
            return nil
        case .up:
            trace.append((sample.t, angle))
            if trace.count > 600 { trace.removeFirst(trace.count - 600) }
            if angle <= sensitivity.upDegrees {
                leaveTime = sample.t
                // 立っている間は、基準を少しずつ合わせ直す
                if angle < sensitivity.upDegrees * 0.6 {
                    baseline = normalized(base * 0.97 + v * 0.03)
                }
            } else if angle >= sensitivity.downDegrees {
                phase = .down
                peak = angle
            }
            return nil
        case .down:
            trace.append((sample.t, angle))
            if trace.count > 600 { trace.removeFirst(trace.count - 600) }
            peak = max(peak, angle)
            guard angle <= sensitivity.upDegrees else { return nil }
            phase = .up
            let start = leaveTime
            leaveTime = sample.t
            guard sample.t - start >= Self.minimumRepSeconds else {
                trace = [(sample.t, angle)]
                return nil
            }
            count += 1
            let rep = Rep(descent: Self.descent(in: trace, peak: peak), depth: peak)
            // 前の回のいちばん深い所を、次の回の計算に混ぜない
            trace = [(sample.t, angle)]
            return rep
        }
    }

    /// 下ろした秒の見積もり。傾きが深さの 10% から 90% に進む間を測り、全体に直す
    /// （なめらかに下ろすと、その間は全体の約 6 割。始めと終わりのゆっくりな所はぶれに埋もれるので測らない）
    static func descent(in trace: [(t: TimeInterval, angle: Double)], peak: Double) -> TimeInterval {
        guard let peakIndex = trace.indices.max(by: { trace[$0].angle < trace[$1].angle }) else { return 0 }
        var startIndex = 0
        for i in stride(from: peakIndex, through: 0, by: -1) where trace[i].angle <= peak * 0.1 {
            startIndex = i
            break
        }
        let endIndex = (startIndex...peakIndex).first { trace[$0].angle >= peak * 0.9 } ?? peakIndex
        return max(0, trace[endIndex].t - trace[startIndex].t) / 0.6
    }

    private func normalized(_ v: SIMD3<Double>) -> SIMD3<Double> {
        let length = (v * v).sum().squareRoot()
        return length > 0.0001 ? v / length : SIMD3(0, -1, 0)
    }

    private func degrees(between a: SIMD3<Double>, and b: SIMD3<Double>) -> Double {
        let dot = min(1, max(-1, (a * b).sum()))
        return acos(dot) * 180 / .pi
    }
}

/// 空気椅子・プランクの「土台」の時間。しゃがんだ姿勢を保っている間だけ進む。
/// 0.6 秒以内のぶれでは途切れさせない（判定はゆるめ）
struct HoldTracker: Sendable {
    static let graceSeconds: TimeInterval = 0.6

    private(set) var seconds: TimeInterval = 0
    private(set) var holding = false
    private var lastTime: TimeInterval?
    private var lastInside: TimeInterval?

    /// inside：いま、しゃがんだ姿勢（傾きが基準を超えている）か
    mutating func feed(t: TimeInterval, inside: Bool) {
        defer { lastTime = t }
        guard let previous = lastTime else {
            if inside { lastInside = t; holding = true }
            return
        }
        let dt = max(0, min(0.5, t - previous))
        if inside {
            lastInside = t
            holding = true
            seconds += dt
        } else if let last = lastInside, t - last <= Self.graceSeconds {
            // 少しのぶれ：途切れさせずに数え続ける
            seconds += dt
        } else {
            holding = false
        }
    }

    /// センサーがない端末では、指で始めて指で止める（時計で数える）
    mutating func addManual(_ dt: TimeInterval) {
        seconds += max(0, dt)
        holding = true
    }
}
