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
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isPlaying)

            Button(action: onStop) {
                Text("Stop Tone")
                    .padding()
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!isPlaying)
        }
        // iOS の既定のボタンは背景を持たないため、白文字のままではライトモードで読めない。
        // 塗りつぶしスタイルを指定して macOS/iOS どちらでも視認できるようにする
        .buttonStyle(.borderedProminent)
    }
}

#Preview("停止中") {
    PlaybackControls(isPlaying: false, onPlay: {}, onStop: {})
}

#Preview("再生中") {
    PlaybackControls(isPlaying: true, onPlay: {}, onStop: {})
}
