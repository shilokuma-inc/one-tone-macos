//
//  WaveformPicker.swift
//  OneTone
//

import SwiftUI

/// 波形の切替。選ばれた波形を `onChange` で親に渡す
struct WaveformPicker: View {
    let waveform: Waveform
    let onChange: (Waveform) -> Void

    var body: some View {
        Picker("Waveform", selection: Binding<Waveform>(
            get: {
                waveform
            },
            set: { newValue in
                onChange(newValue)
            }
        )) {
            ForEach(Waveform.allCases) { waveform in
                Text(waveform.displayName).tag(waveform)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }
}

#Preview {
    WaveformPicker(waveform: .sine, onChange: { _ in })
}
