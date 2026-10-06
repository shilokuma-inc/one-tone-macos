//
//  ScreenshotDemoTests.swift
//  OneToneTests
//

import XCTest
@testable import OneTone

final class ScreenshotDemoTests: XCTestCase {
    func testSceneIsReadFromLaunchArguments() {
        XCTAssertEqual(ScreenshotDemo.scene(from: ["-screenshot-demo", "-screenshot-scene", "square"]), .square)
        XCTAssertEqual(ScreenshotDemo.scene(from: ["-screenshot-scene", "sawtooth", "-screenshot-demo"]), .sawtooth)
    }

    func testUnknownOrMissingSceneFallsBackToFirstScene() {
        XCTAssertEqual(ScreenshotDemo.scene(from: ["-screenshot-demo"]), .sine)
        XCTAssertEqual(ScreenshotDemo.scene(from: ["-screenshot-demo", "-screenshot-scene"]), .sine)
        XCTAssertEqual(ScreenshotDemo.scene(from: ["-screenshot-demo", "-screenshot-scene", "noise"]), .sine)
    }

    func testArgumentValueIsReadOnlyWhenPresent() {
        XCTAssertEqual(ScreenshotDemo.argument("-screenshot-output", in: ["-screenshot-output", "/tmp/a.png"]), "/tmp/a.png")
        XCTAssertNil(ScreenshotDemo.argument("-screenshot-output", in: ["-screenshot-output"]))
        XCTAssertNil(ScreenshotDemo.argument("-screenshot-output", in: ["-screenshot-demo"]))
    }

    func testAudioManagerForScreenshotPresentsSceneWithoutEngine() {
        let manager = AudioManager.forScreenshot(.sawtooth)
        XCTAssertTrue(manager.isPlaying)
        XCTAssertFalse(manager.audioEngine.isRunning)
        XCTAssertEqual(manager.currentFrequency, 100)
        XCTAssertEqual(manager.currentWaveform, .sawtooth)
        XCTAssertFalse(AudioManager.forScreenshot(nil).isPlaying)
    }

    func testEachAppStoreSceneHasDistinctWaveform() {
        // App Store の 3 枚のスクリーンショットで別々の波形を見せる前提なので、重複したら設定ミス
        let waveforms = ScreenshotDemo.Scene.appStoreScenes.map(\.waveform)
        XCTAssertEqual(Set(waveforms).count, waveforms.count)
        for scene in ScreenshotDemo.Scene.allCases {
            XCTAssertTrue(FrequencyInput.range.contains(scene.frequency), "\(scene) の周波数が範囲外")
        }
    }

    func testAppStoreScenesKeepTheirLaunchNames() {
        // AppStore/screenshots.json の scene と一致させている名前なので、変わったら撮影が既定の画面に化ける
        XCTAssertEqual(ScreenshotDemo.Scene.appStoreScenes.map(\.rawValue), ["sine", "square", "sawtooth"])
    }

    func testTutorialScenesCoverEveryTutorialPage() {
        // チュートリアルのアセット名（Tutorial-<ページ名>）と撮影の場面名（tutorial-<ページ名>）を対応させている
        let tutorialScenes = ScreenshotDemo.Scene.allCases.filter { !ScreenshotDemo.Scene.appStoreScenes.contains($0) }
        XCTAssertEqual(tutorialScenes.map(\.rawValue), ["tutorial-welcome", "tutorial-playback", "tutorial-frequency", "tutorial-volume", "tutorial-waveform"])
        XCTAssertEqual(ScreenshotDemo.scene(from: ["-screenshot-scene", "tutorial-frequency"]), .tutorialFrequency)
    }

    func testTutorialScenesShowTheirPage() {
        XCTAssertEqual(ScreenshotDemo.Scene.tutorialFrequency.scrollTarget, .frequency)
        XCTAssertTrue(FrequencyInput.presets.contains(ScreenshotDemo.Scene.tutorialFrequency.frequency), "プリセットが選択中に見えない")
        XCTAssertLessThan(ScreenshotDemo.Scene.tutorialVolume.volume, 0.5)
        XCTAssertEqual(ScreenshotDemo.Scene.tutorialWaveform.waveform, .triangle)
        for scene in ScreenshotDemo.Scene.appStoreScenes {
            XCTAssertNil(scene.scrollTarget, "App Store 用の \(scene) の見た目が変わる")
        }
    }

    func testPresentAsPlayingFillsOutputHistoryWithoutAudioEngine() {
        let manager = AudioManager(startsEngine: false)
        manager.presentAsPlaying(frequency: 440, volume: 0.8, waveform: .square)

        XCTAssertTrue(manager.isPlaying)
        XCTAssertEqual(manager.currentFrequency, 440)
        XCTAssertEqual(manager.currentWaveform, .square)
        // 末尾（最新）はフェードインが終わっていて、矩形波の振幅（= 音量）になっている
        let latest = manager.latestOutputSamples(Oscilloscope.windowLength)
        XCTAssertEqual(latest.count, Oscilloscope.windowLength)
        XCTAssertEqual(Double(latest.map { abs($0) }.max() ?? 0), 0.8, accuracy: 0.01)
    }
}
