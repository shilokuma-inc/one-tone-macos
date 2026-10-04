//
//  PlaybackControls.swift
//  OneTone
//

import SwiftUI

/// 再生／停止のボタン。再生状態は親が持ち、押されたことだけをクロージャで伝える
struct PlaybackControls: View {
    let isPlaying: Bool
    let onPlay: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack {
            Button(action: onPlay) {
                Text("Play Tone")
                    .padding()
                    .foregroundStyle(Theme.onAccent)
                    .cornerRadius(10)
            }
            .disabled(isPlaying)

            Button(action: onStop) {
                Text("Stop Tone")
                    .padding()
                    .foregroundStyle(Theme.onAccent)
                    .cornerRadius(10)
            }
            .disabled(!isPlaying)
        }
        // iOS の既定のボタンは背景を持たないため、塗りつぶしスタイルで macOS/iOS どちらでも押せる形に見せる。
        // 塗りは差し色（シアン）になるので、文字は白ではなく暗色にして読めるようにする
        .buttonStyle(.borderedProminent)
    }
}

#Preview("停止中") {
    PlaybackControls(isPlaying: false, onPlay: {}, onStop: {})
        .padding()
        .themedScreen()
}

#Preview("再生中") {
    PlaybackControls(isPlaying: true, onPlay: {}, onStop: {})
        .padding()
        .themedScreen()
}
