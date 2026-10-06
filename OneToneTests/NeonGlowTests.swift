//
//  NeonGlowTests.swift
//  OneToneTests
//

import XCTest
@testable import OneTone

final class NeonGlowTests: XCTestCase {

    func testGlowIsOffWhileStopped() {
        for time in stride(from: 0.0, to: 5.0, by: 0.1) {
            XCTAssertEqual(NeonGlow.intensity(at: time, isActive: false, reduceMotion: false), 0)
            XCTAssertEqual(NeonGlow.intensity(at: time, isActive: false, reduceMotion: true), 0)
        }
    }

    func testGlowIsSteadyWithReduceMotion() {
        for time in stride(from: 0.0, to: 5.0, by: 0.1) {
            XCTAssertEqual(NeonGlow.intensity(at: time, isActive: true, reduceMotion: true), 1)
        }
    }

    func testGlowPulseStaysBrightAndSlow() {
        let samples = stride(from: 0.0, to: Theme.glowPulsePeriod, by: 1.0 / 60).map {
            NeonGlow.intensity(at: $0, isActive: true, reduceMotion: false)
        }
        // 消えたり大きく明滅したりせず、ゆらぎの幅に収まる
        XCTAssertGreaterThanOrEqual(samples.min() ?? 0, 1 - Theme.glowPulseDepth - 1e-9)
        XCTAssertLessThanOrEqual(samples.max() ?? 2, 1 + 1e-9)
        // 1 フレーム（60fps）あたりの変化が小さい（急な明滅にならない）
        let maxStep = zip(samples, samples.dropFirst()).map { abs($1 - $0) }.max() ?? 0
        XCTAssertLessThan(maxStep, 0.01)
        // 周期は 1 秒より遅い
        XCTAssertGreaterThan(Theme.glowPulsePeriod, 1)
    }

    func testTitleHueSwingsAroundThemeColorOncePerPeriod() {
        let period = Theme.titleHueSwingPeriod
        let amplitude = Theme.titleHueSwingAmplitude
        XCTAssertGreaterThan(period, 1, "タイトルの色相の揺れは以前の 1 秒周期より遅くする")
        XCTAssertEqual(amplitude, 30, "選んだ色の周りで ±30° 揺らす（判断ログ #91）")
        // 選んだ色（0°）から始まり、1/4 周期で +振幅、半周期で 0°、3/4 周期で -振幅、1 周期で 0° に戻る
        XCTAssertEqual(TitleView.hueDegrees(at: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(TitleView.hueDegrees(at: period / 4), amplitude, accuracy: 1e-6)
        XCTAssertEqual(TitleView.hueDegrees(at: period / 2), 0, accuracy: 1e-6)
        XCTAssertEqual(TitleView.hueDegrees(at: period * 3 / 4), -amplitude, accuracy: 1e-6)
        XCTAssertEqual(TitleView.hueDegrees(at: period * 3 + period / 4), amplitude, accuracy: 1e-6)
    }

    func testTitleHueStaysWithinSwingAmplitude() {
        let amplitude = Theme.titleHueSwingAmplitude
        for time in stride(from: 0.0, to: 100.0, by: 0.37) {
            let hue = TitleView.hueDegrees(at: time)
            XCTAssertGreaterThanOrEqual(hue, -amplitude - 1e-9)
            XCTAssertLessThanOrEqual(hue, amplitude + 1e-9)
        }
    }

    func testTitleHueSwingIsSmooth() {
        // 30fps の 1 フレームあたりの変化が小さく、折り返しで角度が飛ばない（往復で滑らかに動く）
        let samples = stride(from: 0.0, to: Theme.titleHueSwingPeriod * 2, by: 1.0 / 30).map(TitleView.hueDegrees(at:))
        let maxStep = zip(samples, samples.dropFirst()).map { abs($1 - $0) }.max() ?? .infinity
        XCTAssertLessThan(maxStep, 1)
    }

    func testPausableClockDoesNotAdvanceWhileStopped() {
        let origin = Date(timeIntervalSinceReferenceDate: 1000)
        var clock = PausableClock()
        XCTAssertEqual(clock.elapsed(at: origin), 0)
        clock.start(at: origin)
        XCTAssertEqual(clock.elapsed(at: origin + 3), 3, accuracy: 1e-9)
        clock.stop(at: origin + 3)
        // 止めている間は進まない
        XCTAssertEqual(clock.elapsed(at: origin + 10), 3, accuracy: 1e-9)
        // 再開した瞬間は止めたときと同じ値から続く（色が飛ばない）
        clock.start(at: origin + 10)
        XCTAssertEqual(clock.elapsed(at: origin + 10), 3, accuracy: 1e-9)
        XCTAssertEqual(clock.elapsed(at: origin + 12), 5, accuracy: 1e-9)
    }

    func testPausableClockIgnoresRepeatedStartAndStop() {
        let origin = Date(timeIntervalSinceReferenceDate: 1000)
        var clock = PausableClock()
        clock.stop(at: origin)
        XCTAssertEqual(clock.elapsed(at: origin + 5), 0)
        clock.start(at: origin)
        clock.start(at: origin + 2)
        XCTAssertEqual(clock.elapsed(at: origin + 4), 4, accuracy: 1e-9)
        clock.stop(at: origin + 4)
        clock.stop(at: origin + 6)
        XCTAssertEqual(clock.elapsed(at: origin + 8), 4, accuracy: 1e-9)
    }
}
