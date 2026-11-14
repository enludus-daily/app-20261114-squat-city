import CoreMotion
import Foundation

/// 動きの入力。本物は CoreMotion、撮影・デモ・テストは決まった動きの偽物
@MainActor
protocol MotionSource: AnyObject {
    /// 読めない端末（シミュレータなど）では false
    var isAvailable: Bool { get }
    func start(_ handler: @escaping @MainActor (MotionSample) -> Void)
    func stop()
}

/// CoreMotion の重力の向き（deviceMotion.gravity）。50 回／秒。許可の確認は要らない
@MainActor
final class CoreMotionSource: MotionSource {
    private let manager = CMMotionManager()

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start(_ handler: @escaping @MainActor (MotionSample) -> Void) {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            let g = motion.gravity
            let sample = MotionSample(t: motion.timestamp, x: g.x, y: g.y, z: g.z)
            MainActor.assumeIsolated { handler(sample) }
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}

/// 決まった動き（撮影・デモ用）。決めた下ろす秒で、しゃがんで立つを繰り返す
@MainActor
final class ScriptedMotionSource: MotionSource {
    private let samples: [MotionSample]
    private var task: Task<Void, Never>?

    init(descents: [TimeInterval]) {
        samples = MotionScript.samples(descents: descents)
    }

    var isAvailable: Bool { true }

    func start(_ handler: @escaping @MainActor (MotionSample) -> Void) {
        let samples = self.samples
        task = Task { @MainActor in
            for s in samples {
                if Task.isCancelled { return }
                handler(s)
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
    }

    func stop() { task?.cancel() }
}

/// しゃがむ動きを、重力の向きの列にする（テストと偽物の入力で使う）
enum MotionScript {
    /// - descents: 1 回ずつの下ろす秒
    /// - depth: しゃがんだときの傾き（度）。胸に当てると 25〜35 度、ポケットだと 60〜80 度
    /// - jitter: 手の揺れ（度）。決まった並びで足す（毎回同じ）
    static func samples(descents: [TimeInterval], depth: Double = 40, ascent: TimeInterval = 0.9,
                        pause: TimeInterval = 0.5, hz: Double = 50, jitter: Double = 1.2) -> [MotionSample] {
        var out: [MotionSample] = []
        var t: TimeInterval = 0
        let dt = 1 / hz
        var i = 0
        func push(_ angle: Double) {
            let wobble = jitter * sin(Double(i) * 1.7) * cos(Double(i) * 0.31)
            let a = (angle + wobble) * .pi / 180
            // 立った姿勢で画面を前に向けて胸に当てる：重力は端末の -y。前に傾くと z に回る
            out.append(MotionSample(t: t, x: 0, y: -cos(a), z: -sin(a)))
            t += dt
            i += 1
        }
        // 最初に 0.4 秒立って、基準を取る
        for _ in 0..<Int(0.4 * hz) { push(0) }
        for descent in descents {
            let down = max(1, Int(descent * hz))
            for k in 0..<down { push(depth * easeInOut(Double(k + 1) / Double(down))) }
            for _ in 0..<Int(0.25 * hz) { push(depth) }
            let up = max(1, Int(ascent * hz))
            for k in 0..<up { push(depth * (1 - easeInOut(Double(k + 1) / Double(up)))) }
            for _ in 0..<Int(pause * hz) { push(0) }
        }
        return out
    }

    /// 人の動きに近い、なめらかな始めと終わり
    private static func easeInOut(_ x: Double) -> Double { (1 - cos(.pi * x)) / 2 }
}
