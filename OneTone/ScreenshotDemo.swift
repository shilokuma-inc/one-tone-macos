//
//  ScreenshotDemo.swift
//  OneTone
//

import SwiftUI

/// App Store 用スクリーンショットの撮影モード。
///
/// 起動引数 `-screenshot-demo` で有効になり、`-screenshot-scene <名前>` で撮る画面（周波数と波形の組み合わせ）を選ぶ。
/// 撮影は `Tools/capture_screenshots.sh`（iOS Simulator）と `Tools/capture_mac_screenshots.sh`（macOS）が、
/// 画面ごとにアプリを起動し直して行う。撮る画面の並び順と出力ファイル名は `AppStore/screenshots.json` で決める。
///
/// 撮影モードでは音を出さず、表示だけを「再生中」にする（`AudioManager.presentAsPlaying`）。
/// また、撮影スクリプトは「連続で撮った 2 枚が一致するまで待つ」ので、タイトルの色相の回転や発光のゆらぎのような
/// 止まらないアニメーションは `\.freezesAnimations` で止める
enum ScreenshotDemo {
    /// 撮る画面。`rawValue` が `-screenshot-scene` に渡す名前で、`AppStore/screenshots.json` の scene と一致させる
    enum Scene: String, CaseIterable {
        /// 440 Hz（A4）のサイン波を再生中
        case sine
        /// 1 kHz の矩形波を再生中
        case square
        /// 100 Hz のノコギリ波を再生中
        case sawtooth

        var frequency: Double {
            switch self {
            case .sine: return 440
            case .square: return 1000
            case .sawtooth: return 100
            }
        }

        var waveform: Waveform {
            switch self {
            case .sine: return .sine
            case .square: return .square
            case .sawtooth: return .sawtooth
            }
        }

        /// 音量。レベルメーターが上の方まで点いて見えるよう、既定の 50% より高くする
        var volume: Double { 0.8 }
    }

    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-screenshot-demo")

    /// 撮る画面。撮影モードでないときは nil
    static let scene: Scene? = isEnabled ? scene(from: ProcessInfo.processInfo.arguments) : nil

    /// 起動引数から撮る画面を読む。指定が無い・知らない名前のときは最初の画面にする
    static func scene(from arguments: [String]) -> Scene {
        guard let index = arguments.firstIndex(of: "-screenshot-scene"),
              arguments.indices.contains(index + 1),
              let scene = Scene(rawValue: arguments[index + 1]) else {
            return Scene.allCases[0]
        }
        return scene
    }

    /// macOS で撮影するときのウィンドウの中身の大きさ（pt）。撮影モードでないときは nil（ふだんどおり自由に変えられる）。
    ///
    /// 撮影スクリプトはウィンドウの画像を 1440x900（Retina では 2880x1800）のキャンバスに合成するので、
    /// タイトルバーを含めてもそこに収まり、かつ 2 枚のパネルが横に並ぶ幅（`DeckLayout.sideBySideMinWidth` 以上）にする
    static let macWindowContentSize: CGSize? = isEnabled ? CGSize(width: 1280, height: 800) : nil
}

private struct FreezesAnimationsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// 止まらないアニメーション（色相の回転・発光のゆらぎ・波形やメーターの更新）を止めて、画面を静止させる。
    /// スクリーンショットの撮影モードで `OneToneApp` が立てる。各部品では Reduce Motion と同じように扱う
    var freezesAnimations: Bool {
        get { self[FreezesAnimationsKey.self] }
        set { self[FreezesAnimationsKey.self] = newValue }
    }
}
