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
    @State private var hue: Double = 0
    
    var body: some View {
        VStack {
            Spacer()
            
            Text("One Tone")
                .foregroundColor(Color.white)
                .font(.custom("Helvetica Neue", size: 60))
                .fontWeight(.bold)
                // iPhone の幅では 60pt のままだとタイトルが収まらないので縮小を許可する
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.red, Color.orange, Color.yellow, Color.green,
                            Color.blue, Color.purple, Color.red
                        ]),
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
                .onAppear {
                    withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                        hue = 360
                    }
                }
            
            Spacer()
            
            HStack {
                Button(action: {
                    audioManager.playTone(frequency: frequency)
                }) {
                    Text("Play Tone")
                        .padding()
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(audioManager.isPlaying)
                
                Button(action: {
                    audioManager.stopTone()
                }) {
                    Text("Stop Tone")
                        .padding()
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!audioManager.isPlaying)
            }
            // iOS の既定のボタンは背景を持たないため、白文字のままではライトモードで読めない。
            // 塗りつぶしスタイルを指定して macOS/iOS どちらでも視認できるようにする
            .buttonStyle(.borderedProminent)
            
            Slider(value: Binding<Double>(
                get: {
                    log10(frequency)
                },
                set: { newValue in
                    setFrequency(pow(10, newValue))
                }
            ), in: log10(20)...log10(20000), step: 0.02) {
                Text("Frequency")
            }
            .padding()
            
            Text("Frequency: \(FrequencyInput.format(frequency)) Hz")
                .padding()
            
            HStack {
                TextField("Frequency", text: $frequencyText)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    #if os(iOS)
                    // decimalPad には確定キーが無く onSubmit が呼べないため、確定キーのある数字キーボードにする
                    .keyboardType(.numbersAndPunctuation)
                    #endif
                    .submitLabel(.done)
                    .onSubmit(submitFrequencyText)
                Text("Hz")
            }
            .textFieldStyle(.roundedBorder)
            
            HStack {
                ForEach(FrequencyInput.presets, id: \.self) { preset in
                    Button(FrequencyInput.presetLabel(preset)) {
                        setFrequency(preset)
                    }
                }
            }
            .buttonStyle(.bordered)
            .padding()
            
            Slider(value: Binding<Double>(
                get: {
                    volume
                },
                set: { newValue in
                    volume = newValue
                    audioManager.updateVolume(volume)
                }
            ), in: 0...1) {
                Text("Volume")
            }
            .padding()
            
            Text("Volume: \(Int((volume * 100).rounded()))%")
                .padding()
            
            Picker("Waveform", selection: Binding<Waveform>(
                get: {
                    waveform
                },
                set: { newValue in
                    waveform = newValue
                    audioManager.updateWaveform(waveform)
                }
            )) {
                ForEach(Waveform.allCases) { waveform in
                    Text(waveform.displayName).tag(waveform)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Spacer()
        }
        .padding()
    }
    
    /// スライダー・数値入力・プリセットのどこから変えても、表示と入力欄と再生中の音をそろえる
    private func setFrequency(_ newFrequency: Double) {
        frequency = newFrequency
        frequencyText = FrequencyInput.format(newFrequency)
        audioManager.updateFrequency(newFrequency)
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
