//
//  ContentView.swift
//  OneTone
//
//  Created by 村石 拓海 on 2024/05/28.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var frequency: Double = 20.0
    @State private var frequencyText: String = FrequencyInput.format(20.0)
    @State private var volume: Double = 0.5
    @State private var waveform: Waveform = .sine
    
    var body: some View {
        VStack {
            Spacer()
            
            TitleView()
            
            Spacer()
            
            PlaybackControls(
                isPlaying: audioManager.isPlaying,
                onPlay: { audioManager.playTone(frequency: frequency) },
                onStop: { audioManager.stopTone() }
            )
            
            FrequencySlider(frequency: frequency, onChange: setFrequency)
            
            FrequencyDisplay(frequency: frequency)
            
            FrequencyTextField(text: $frequencyText, onSubmit: submitFrequencyText)
            
            FrequencyPresetButtons(onSelect: setFrequency)
            
            VolumeControl(volume: volume, onChange: setVolume)
            
            WaveformPicker(waveform: waveform, onChange: setWaveform)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedScreen()
    }
    
    /// スライダー・数値入力・プリセットのどこから変えても、表示と入力欄と再生中の音をそろえる
    private func setFrequency(_ newFrequency: Double) {
        frequency = newFrequency
        frequencyText = FrequencyInput.format(newFrequency)
        audioManager.updateFrequency(newFrequency)
    }
    
    private func setVolume(_ newVolume: Double) {
        volume = newVolume
        audioManager.updateVolume(newVolume)
    }
    
    private func setWaveform(_ newWaveform: Waveform) {
        waveform = newWaveform
        audioManager.updateWaveform(newWaveform)
    }
    
    /// 範囲外や数値でない入力は反映せず、入力欄を現在の周波数に戻す
    private func submitFrequencyText() {
        if let newFrequency = FrequencyInput.parse(frequencyText) {
            setFrequency(newFrequency)
        } else {
            frequencyText = FrequencyInput.format(frequency)
        }
    }
}

/// 周波数の数値入力とプリセットの定義。UI から切り離してテストできるようにしている
enum FrequencyInput {
    /// 可聴域に合わせた入力可能な範囲（スライダーと同じ）
    static let range: ClosedRange<Double> = 20...20000
    static let presets: [Double] = [100, 440, 1000, 10000]

    /// 入力文字列を周波数に変換する。数値でない・範囲外の場合は nil
    static func parse(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespaces)),
              range.contains(value) else { return nil }
        return value
    }

    /// 入力欄と表示ラベルで共通に使う表記（1Hz 単位に四捨五入）
    static func format(_ frequency: Double) -> String {
        String(Int(frequency.rounded()))
    }

    /// プリセットボタンの表記。1kHz 以上は kHz で表す
    static func presetLabel(_ frequency: Double) -> String {
        if frequency >= 1000 {
            return "\(format(frequency / 1000)) kHz"
        }
        return "\(format(frequency)) Hz"
    }
}

#Preview {
    ContentView()
}
