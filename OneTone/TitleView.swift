//
//  TitleView.swift
//  OneTone
//

import SwiftUI

/// 選んだテーマの差し色を中心にしたグラデーションのタイトル。グラデーションは常に表示し、色相の揺れと発光は再生中だけにする（停止中は静か）。
/// 色相は選んだ色の周りで ±`Theme.titleHueSwingAmplitude` 度だけ揺らし、別の色にはしない。
/// Reduce Motion がオンのとき、またはスクリーンショットの撮影モードのときは揺らさない
struct TitleView: View {
    let isPlaying: Bool
    @Environment(\.themeColor) private var themeColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.freezesAnimations) private var freezesAnimations
    /// 揺れていた時間だけを数える時計。止めている間の時間を角度に含めず、再開したとき色が飛ばないようにする
    @State private var clock = PausableClock()

    /// 色相を揺らすか。再生中かつ Reduce Motion がオフで、撮影モードでもないときだけ揺らす
    private var isAnimating: Bool {
        isPlaying && !reduceMotion && !freezesAnimations
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isAnimating)) { context in
            title(hue: Self.hueDegrees(at: clock.elapsed(at: context.date)))
        }
        // 表示時と、揺らす／止めるが切り替わるたびに時計を動かす・止める
        // （2 引数の onChange は macOS 14 からなので、表示時にも呼ばれる task(id:) を使う）
        .task(id: isAnimating) {
            if isAnimating {
                clock.start(at: Date())
            } else {
                clock.stop(at: Date())
            }
        }
    }

    private func title(hue: Double) -> some View {
        Text(verbatim: "One Tone")
            .foregroundStyle(Theme.textPrimary)
            .font(.custom("Helvetica Neue", size: 60))
            .fontWeight(.bold)
            // iPhone の幅では 60pt のままだとタイトルが収まらないので縮小を許可する
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: themeColor.titleGradient),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    Text(verbatim: "One Tone")
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                )
                .font(.custom("Helvetica Neue", size: 60))
                .fontWeight(.bold)
                .hueRotation(Angle(degrees: hue))
            )
            .neonGlow(Theme.accentSecondary, isActive: isPlaying)
    }

    /// 揺れていた時間（秒）に対する色相のずらし角（-振幅...+振幅）。
    /// 0 秒では 0°（選んだ色のまま）から始まり、正弦波で `Theme.titleHueSwingPeriod` 秒ごとに 1 往復する。
    /// 端で速度が 0 になるので、折り返しでカクつかない
    static func hueDegrees(at time: TimeInterval) -> Double {
        Theme.titleHueSwingAmplitude * sin(2 * .pi * time / Theme.titleHueSwingPeriod)
    }
}

/// 動いていた時間だけを積み上げる時計。止めている間は進まない
struct PausableClock {
    /// 直前に止めるまでに動いていた時間の合計
    private(set) var accumulated: TimeInterval = 0
    /// 動いている間は動き始めた時刻、止まっている間は nil
    private(set) var startedAt: Date?

    mutating func start(at date: Date) {
        guard startedAt == nil else { return }
        startedAt = date
    }

    mutating func stop(at date: Date) {
        guard let startedAt else { return }
        accumulated += max(0, date.timeIntervalSince(startedAt))
        self.startedAt = nil
    }

    /// `date` の時点までに動いていた時間の合計
    func elapsed(at date: Date) -> TimeInterval {
        guard let startedAt else { return accumulated }
        return accumulated + max(0, date.timeIntervalSince(startedAt))
    }
}

#Preview("停止中") {
    TitleView(isPlaying: false)
        .padding()
        .themedScreen()
}

#Preview("再生中") {
    TitleView(isPlaying: true)
        .padding()
        .themedScreen()
}

#Preview("ピンクのテーマで再生中") {
    TitleView(isPlaying: true)
        .padding()
        .themedScreen()
        .environment(\.themeColor, .pink)
}
