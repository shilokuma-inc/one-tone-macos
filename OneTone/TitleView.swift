//
//  TitleView.swift
//  OneTone
//

import SwiftUI

/// 虹色のタイトル。グラデーションは常に表示し、色相の回転と発光は再生中だけにする（停止中は静か）。
/// Reduce Motion がオンのときは回転させない
struct TitleView: View {
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // 経過時間から角度を決めるので、止めるとその角度のまま静止し、再開しても色が飛ばない
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying || reduceMotion)) { context in
            title(hue: Self.hueDegrees(at: context.date.timeIntervalSinceReferenceDate))
        }
    }

    private func title(hue: Double) -> some View {
        Text("One Tone")
            .foregroundStyle(Theme.textPrimary)
            .font(.custom("Helvetica Neue", size: 60))
            .fontWeight(.bold)
            // iPhone の幅では 60pt のままだとタイトルが収まらないので縮小を許可する
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: Theme.rainbow),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    Text("One Tone")
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                )
                .font(.custom("Helvetica Neue", size: 60))
                .fontWeight(.bold)
                .hueRotation(Angle(degrees: hue))
            )
            .neonGlow(Theme.accentSecondary, isActive: isPlaying)
    }

    /// 経過時間に対する色相の回転角（0..<360）。`Theme.titleHueCyclePeriod` 秒で 1 周する
    static func hueDegrees(at time: TimeInterval) -> Double {
        let progress = time / Theme.titleHueCyclePeriod
        return (progress - floor(progress)) * 360
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
