//
//  ContentView.swift
//  OneTone
//
//  Created by 村石 拓海 on 2024/05/28.
//

import SwiftUI

struct ContentView: View {
    /// 縦スクロールで送り先にできる部品
    enum Section: Hashable {
        case frequency
    }

    @StateObject private var audioManager: AudioManager
    @State private var frequency: Double
    @State private var frequencyText: String
    @State private var volume: Double
    @State private var waveform: Waveform
    /// 選んだテーマ。保存値が無い・読めないときは既定のテーマ
    @AppStorage(ThemeColor.storageKey) private var storedThemeColor: ThemeColor = .default
    private let isScreenshotDemo: Bool
    #if os(iOS)
    @State private var isShowingSettings = false
    #endif
    /// チュートリアルを閉じたことがあるか。Skip / 完了 / 閉じる のどれでも立てる
    @AppStorage(Tutorial.hasSeenKey) private var hasSeenTutorial = false
    @State private var isShowingTutorial = false
    /// 撮影モードで、開いた直後に見える位置まで送る部品
    private let initialScrollTarget: Section?

    /// - Parameter screenshotScene: スクリーンショットの撮影モードで撮る画面。渡すと、その周波数・波形・音量を初期値にし、
    ///   音を出さずに再生中の表示にする。画面を出さずに描く経路でも使えるよう、`.task` ではなく初期値で状態を作る
    init(screenshotScene: ScreenshotDemo.Scene? = ScreenshotDemo.scene) {
        let initialFrequency = screenshotScene?.frequency ?? FrequencyInput.defaultFrequency
        _audioManager = StateObject(wrappedValue: AudioManager.forScreenshot(screenshotScene))
        _frequency = State(initialValue: initialFrequency)
        _frequencyText = State(initialValue: FrequencyInput.format(initialFrequency))
        _volume = State(initialValue: screenshotScene?.volume ?? 0.5)
        _waveform = State(initialValue: screenshotScene?.waveform ?? .sine)
        isScreenshotDemo = screenshotScene != nil
        initialScrollTarget = screenshotScene?.scrollTarget
    }
    
    var body: some View {
        // 幅で並べ方だけを変え、狭い画面では縦にスクロールして部品が切れないようにする
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 16) {
                        TitleView(isPlaying: audioManager.isPlaying)
                            .padding(.top)
                    
                        OscilloscopeView(isPlaying: audioManager.isPlaying, readSamples: audioManager.latestOutputSamples)
                            .frame(maxWidth: DeckLayout.panelMaxWidth * 2)
                    
                        if DeckLayout.isSideBySide(width: proxy.size.width) {
                            HStack(alignment: .top, spacing: 16) {
                                frequencyPanel
                                outputPanel
                            }
                        } else {
                            VStack(spacing: 16) {
                                outputPanel
                                frequencyPanel
                                    .id(Section.frequency)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                #if os(iOS)
                // 数値入力のキーボードをスクロールで閉じられるようにする（確定は従来どおり onSubmit）
                .scrollDismissesKeyboard(.interactively)
                #endif
                .onAppear {
                    // チュートリアル用の撮影で、画面の下の方にある部品を写す
                    if let initialScrollTarget {
                        scrollProxy.scrollTo(initialScrollTarget, anchor: .top)
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            TutorialButton(action: openTutorial)
        }
        #if os(iOS)
        // 撮影モードではスクリーンショットの見た目を変えないよう、設定ボタンを出さない
        .overlay(alignment: .topTrailing) {
            if !isScreenshotDemo {
                settingsButton
            }
        }
        #endif
        #if os(macOS)
        .frame(minWidth: DeckLayout.minimumWindowSize.width, minHeight: DeckLayout.minimumWindowSize.height)
        #endif
        .themedScreen()
        .environment(\.themeColor, ThemeColor.displayed(stored: storedThemeColor, isScreenshotDemo: isScreenshotDemo))
        #if os(iOS)
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isShowingSettings = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        #endif
        // シートを下へスワイプして閉じたときも、閉じる操作として既読にする
        .sheet(isPresented: $isShowingTutorial, onDismiss: { finishTutorial(.closed) }) {
            TutorialView(onDismiss: finishTutorial)
        }
        .onAppear {
            // 初回起動時だけ自動で出す（撮影モードと -skip-tutorial 付きの起動では出さない）
            if Tutorial.shouldPresentAutomatically(hasSeen: hasSeenTutorial) {
                openTutorial()
            }
        }
    }

    /// チュートリアルを開く。説明を聞いている間に鳴り続けないよう、メイン画面の音は止める
    private func openTutorial() {
        audioManager.stopTone()
        isShowingTutorial = true
    }

    /// チュートリアルを閉じる。閉じ方によらず既読にする（表示しただけでは既読にしない）
    private func finishTutorial(_ dismissal: TutorialDismissal) {
        if dismissal.marksAsSeen {
            hasSeenTutorial = true
        }
        isShowingTutorial = false
    }

    #if os(iOS)
    /// 設定（シート）を開くボタン。タイトルと重ならないよう画面の右上に置く
    private var settingsButton: some View {
        Button {
            isShowingSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Settings")
        .padding(.trailing, 4)
    }
    #endif
    
    /// 周波数を決める部品（ノブ・表示・スライダー・数値入力・プリセット）
    private var frequencyPanel: some View {
        DeckPanel(title: "FREQUENCY") {
            FrequencyKnob(frequency: frequency, onChange: setFrequency)
            
            FrequencyDisplay(frequency: frequency)
            
            FrequencySlider(frequency: frequency, onChange: setFrequency)
            
            FrequencyTextField(text: $frequencyText, onSubmit: submitFrequencyText)
            
            FrequencyPresetButtons(frequency: frequency, onSelect: setFrequency)
        }
    }
    
    /// 鳴らし方を決める部品（再生／停止・音量とメーター・波形）
    private var outputPanel: some View {
        DeckPanel(title: "OUTPUT") {
            HStack(alignment: .center, spacing: 8) {
                PlaybackControls(
                    isPlaying: audioManager.isPlaying,
                    onPlay: { audioManager.playTone(frequency: frequency) },
                    onStop: { audioManager.stopTone() }
                )
                .frame(maxWidth: .infinity)
                
                VolumeControl(volume: volume, onChange: setVolume)
            }
            
            LevelMeterView(isPlaying: audioManager.isPlaying, readSamples: audioManager.latestOutputSamples)
            
            WaveformPicker(waveform: waveform, onChange: setWaveform)
        }
    }
    
    /// スライダー・ノブ・数値入力・プリセットのどこから変えても、表示と入力欄と再生中の音をそろえる
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
    /// 起動直後の周波数。聞き取りやすい基準音（A4）にする
    static let defaultFrequency: Double = 440
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

    /// 今の周波数がプリセットと一致するか。表示と同じ 1Hz 単位の表記で比べるので、
    /// 表示が「440」ならスライダーで 439.7Hz にしていても 440Hz のプリセットが選択中になる
    static func isPresetSelected(_ preset: Double, frequency: Double) -> Bool {
        format(preset) == format(frequency)
    }

    /// プリセットボタンの表記。1kHz 以上は kHz で表す。単位の付け方は言語ごとの書式（catalog）に任せる
    static func presetLabel(_ frequency: Double) -> String {
        if frequency >= 1000 {
            return String(localized: "\(format(frequency / 1000)) kHz")
        }
        return String(localized: "\(format(frequency)) Hz")
    }
}

#Preview("iPhone の幅") {
    ContentView()
        .frame(width: 390, height: 844)
}

#Preview("広い画面") {
    ContentView()
        .frame(width: 1024, height: 768)
}
