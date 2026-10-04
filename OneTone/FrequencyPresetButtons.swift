//
//  FrequencyPresetButtons.swift
//  OneTone
//

import SwiftUI

/// 周波数のプリセットボタン。選ばれた値を `onSelect` で親に渡す
struct FrequencyPresetButtons: View {
    let onSelect: (Double) -> Void

    var body: some View {
        HStack {
            ForEach(FrequencyInput.presets, id: \.self) { preset in
                Button(FrequencyInput.presetLabel(preset)) {
                    onSelect(preset)
                }
            }
        }
        .buttonStyle(.bordered)
        .padding()
    }
}

#Preview {
    FrequencyPresetButtons(onSelect: { _ in })
}
