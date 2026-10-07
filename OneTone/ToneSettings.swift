//
//  ToneSettings.swift
//  OneTone
//

import Foundation

/// 再起動後も保持する音の設定（周波数・音量・波形）。再生状態は持たない（起動時は常に停止状態）
struct ToneSettings: Equatable {
    var frequency: Double
    /// 0...1
    var volume: Double
    var waveform: Waveform

    /// 保存値が無い・読めないときの値（440Hz / 50% / Sine）
    static let `default` = ToneSettings(frequency: FrequencyInput.defaultFrequency, volume: 0.5, waveform: .sine)
    static let volumeRange: ClosedRange<Double> = 0...1

    /// 起動時の初期値。撮影モードではシーンの値を使い、保存値は読まない（撮影画像が実行環境の保存値で変わらないように）
    static func initial(screenshotScene: ScreenshotDemo.Scene?, store: ToneSettingsStore?) -> ToneSettings {
        if let screenshotScene {
            return ToneSettings(frequency: screenshotScene.frequency, volume: screenshotScene.volume, waveform: screenshotScene.waveform)
        }
        return store?.load() ?? .default
    }
}

/// 音の設定の読み書き（`UserDefaults` に端末内だけで保存し、iCloud では同期しない）。テストでは専用の suite の `UserDefaults` を渡す
struct ToneSettingsStore {
    static let frequencyKey = "toneFrequency"
    static let volumeKey = "toneVolume"
    static let waveformKey = "toneWaveform"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 起動時に使うストア。撮影モードでは読み書きしないので nil
    static func forLaunch(screenshotScene: ScreenshotDemo.Scene?, defaults: UserDefaults = .standard) -> ToneSettingsStore? {
        screenshotScene == nil ? ToneSettingsStore(defaults: defaults) : nil
    }

    /// 保存値を読む。項目ごとに、保存値が無い・型が違う・範囲外なら既定値にする
    func load() -> ToneSettings {
        let fallback = ToneSettings.default
        return ToneSettings(
            frequency: storedDouble(forKey: Self.frequencyKey, in: FrequencyInput.range) ?? fallback.frequency,
            volume: storedDouble(forKey: Self.volumeKey, in: ToneSettings.volumeRange) ?? fallback.volume,
            waveform: storedWaveform() ?? fallback.waveform
        )
    }

    func save(frequency: Double) {
        defaults.set(frequency, forKey: Self.frequencyKey)
    }

    func save(volume: Double) {
        defaults.set(volume, forKey: Self.volumeKey)
    }

    /// `Waveform` の RawValue（`UInt8`）をそのまま数値で保存する
    func save(waveform: Waveform) {
        defaults.set(Int(waveform.rawValue), forKey: Self.waveformKey)
    }

    /// 文字列などの別の型で入っているものは読まない（`double(forKey:)` は文字列も数値に変換してしまう）
    private func storedDouble(forKey key: String, in range: ClosedRange<Double>) -> Double? {
        guard let number = defaults.object(forKey: key) as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let value = number.doubleValue
        return range.contains(value) ? value : nil
    }

    private func storedWaveform() -> Waveform? {
        guard let number = defaults.object(forKey: Self.waveformKey) as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              let rawValue = UInt8(exactly: number.doubleValue) else { return nil }
        return Waveform(rawValue: rawValue)
    }
}

extension AudioManager {
    /// メイン画面の `AudioManager`。撮影モードは音を出さずに表示だけ再生中にし、それ以外は復元した設定を反映した停止状態で作る
    static func forLaunch(screenshotScene: ScreenshotDemo.Scene?, settings: ToneSettings) -> AudioManager {
        guard screenshotScene == nil else { return forScreenshot(screenshotScene) }
        let manager = AudioManager()
        manager.apply(settings)
        return manager
    }

    /// 周波数・音量・波形をまとめて反映する。再生状態は変えない
    func apply(_ settings: ToneSettings) {
        updateFrequency(settings.frequency)
        updateVolume(settings.volume)
        updateWaveform(settings.waveform)
    }
}
