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

    func testTitleHueCompletesOneCyclePerPeriod() {
        let period = Theme.titleHueCyclePeriod
        XCTAssertGreaterThan(period, 1, "タイトルの色相の回転は以前の 1 秒周期より遅くする")
        XCTAssertEqual(TitleView.hueDegrees(at: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(TitleView.hueDegrees(at: period / 4), 90, accuracy: 1e-6)
        XCTAssertEqual(TitleView.hueDegrees(at: period * 3 + period / 2), 180, accuracy: 1e-6)
    }

    func testTitleHueStaysInRange() {
        for time in stride(from: 0.0, to: 100.0, by: 0.37) {
            let hue = TitleView.hueDegrees(at: time)
            XCTAssertGreaterThanOrEqual(hue, 0)
            XCTAssertLessThan(hue, 360)
        }
    }
}
