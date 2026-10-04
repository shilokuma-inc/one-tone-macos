//
//  VolumeControl.swift
//  OneTone
//

import SwiftUI

/// 音量のスライダーと % 表示。変更は `onChange` で親に渡し、親が音量を反映する
struct VolumeControl: View {
    let volume: Double
    let onChange: (Double) -> Void

    var body: some View {
        Slider(value: Binding<Double>(
            get: {
                volume
            },
            set: { newValue in
                onChange(newValue)
            }
        ), in: 0...1) {
            Text("Volume")
        }
        .padding()

        Text("Volume: \(Int((volume * 100).rounded()))%")
            .padding()
    }
}

#Preview {
    VStack {
        VolumeControl(volume: 0.5, onChange: { _ in })
    }
    .themedScreen()
}
