//
//  OneToneTests.swift
//  OneToneTests
//
//  Created by 村石 拓海 on 2024/05/28.
//

import XCTest
@testable import OneTone

final class OneToneTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testStopToneWithoutPlayingKeepsIsPlayingFalse() {
        let manager = AudioManager()
        manager.stopTone()
        XCTAssertFalse(manager.isPlaying)
    }

    func testStopToneResetsIsPlaying() {
        let manager = AudioManager()
        manager.playTone(frequency: 440)
        XCTAssertTrue(manager.isPlaying)
        manager.stopTone()
        XCTAssertFalse(manager.isPlaying)
    }

    func testUpdateFrequencyAfterStopDoesNotRestartPlayback() {
        let manager = AudioManager()
        manager.playTone(frequency: 440)
        manager.stopTone()
        manager.updateFrequency(1000)
        XCTAssertFalse(manager.isPlaying)
        XCTAssertEqual(manager.currentFrequency, 1000)
    }

    func testToneGeneratorSamplesStayInRange() {
        var generator = ToneGenerator(sampleRate: 48000, frequency: 440)
        for _ in 0..<48000 {
            let sample = generator.nextSample()
            XCTAssertLessThanOrEqual(abs(sample), 1)
            XCTAssertTrue((0..<1).contains(generator.phase))
        }
    }

    func testToneGeneratorCompletesOneCyclePerPeriod() {
        // 48000 / 480 = 100 サンプルでちょうど 1 周期
        var generator = ToneGenerator(sampleRate: 48000, frequency: 480)
        let first = generator.nextSample()
        for _ in 0..<99 {
            _ = generator.nextSample()
        }
        XCTAssertEqual(generator.nextSample(), first, accuracy: 1e-6)
    }

    func testToneGeneratorOutputsSineWave() {
        // 1 周期 4 サンプルなら 0, 1, 0, -1 になる
        var generator = ToneGenerator(sampleRate: 4, frequency: 1)
        let samples = (0..<4).map { _ in generator.nextSample() }
        XCTAssertEqual(samples[0], 0, accuracy: 1e-6)
        XCTAssertEqual(samples[1], 1, accuracy: 1e-6)
        XCTAssertEqual(samples[2], 0, accuracy: 1e-6)
        XCTAssertEqual(samples[3], -1, accuracy: 1e-6)
    }

    func testToneGeneratorKeepsPhaseWhenFrequencyChanges() {
        let sampleRate = 48000.0
        var generator = ToneGenerator(sampleRate: sampleRate, frequency: 440)
        for _ in 0..<1234 {
            _ = generator.nextSample()
        }
        let phaseBeforeChange = generator.phase
        generator.frequency = 1000

        // 周波数を変えても位相はリセットされず、そこから新しい周波数ぶんだけ進む
        XCTAssertEqual(generator.phase, phaseBeforeChange)
        let sample = generator.nextSample()
        XCTAssertEqual(sample, Float(sin(2 * Double.pi * phaseBeforeChange)), accuracy: 1e-6)
        let expectedPhase = phaseBeforeChange + 1000 / sampleRate
        XCTAssertEqual(generator.phase, expectedPhase - floor(expectedPhase), accuracy: 1e-12)
    }

    func testToneGeneratorAdjacentSamplesAreContinuousAcrossFrequencyChange() {
        // 1 サンプルあたりの変化量は、使った周波数のうち高い方で 2π × f / fs 以下に収まる（位相が飛ぶとこれを超える）
        let sampleRate = 48000.0
        let maxStep = Float(2 * Double.pi * 2000 / sampleRate) + 1e-4
        var generator = ToneGenerator(sampleRate: sampleRate, frequency: 200)
        var previous = generator.nextSample()
        for index in 1..<4800 {
            if index % 480 == 0 {
                generator.frequency = generator.frequency == 200 ? 2000 : 200
            }
            let sample = generator.nextSample()
            XCTAssertLessThanOrEqual(abs(sample - previous), maxStep)
            previous = sample
        }
    }
    // MARK: - ParameterSmoother

    func testSmootherConvergesToTargetWithoutOvershoot() {
        var smoother = ParameterSmoother(value: 0, sampleRate: 48000, timeConstant: 0.005)
        smoother.target = 1
        var previous = smoother.current
        // 時定数の 10 倍（50ms）で差分は e^-10 ≒ 0.005% 未満になる
        for _ in 0..<2400 {
            let value = smoother.next()
            XCTAssertGreaterThanOrEqual(value, previous)
            XCTAssertLessThanOrEqual(value, 1)
            previous = value
        }
        XCTAssertEqual(smoother.current, 1, accuracy: 1e-4)
    }

    func testSmootherReachesAbout63PercentAfterTimeConstant() {
        var smoother = ParameterSmoother(value: 100, sampleRate: 48000, timeConstant: 0.005)
        smoother.target = 200
        for _ in 0..<240 {
            _ = smoother.next()
        }
        XCTAssertEqual(smoother.current, 100 + 100 * (1 - exp(-1)), accuracy: 1e-6)
    }

    func testSmootherSnapSkipsInterpolation() {
        var smoother = ParameterSmoother(value: 0, sampleRate: 48000, timeConstant: 0.005)
        smoother.snap(to: 440)
        XCTAssertEqual(smoother.current, 440)
        XCTAssertEqual(smoother.next(), 440)
    }

    // MARK: - ToneSynthesizer

    func testSynthesizerIsSilentBeforePlaying() {
        var synthesizer = ToneSynthesizer(sampleRate: 48000, frequency: 440, volume: 1)
        synthesizer.update(frequency: 440, volume: 1, isPlaying: false)
        XCTAssertTrue(synthesizer.isSilent)
    }

    func testSynthesizerFadesInFromSilence() {
        var synthesizer = ToneSynthesizer(sampleRate: 48000, frequency: 440, volume: 1)
        synthesizer.update(frequency: 440, volume: 1, isPlaying: true)
        XCTAssertFalse(synthesizer.isSilent)
        // 立ち上がりの 1 周期目は最大振幅に届かない（いきなり ±1 にならない）
        let firstCycle = (0..<109).map { _ in abs(synthesizer.nextSample()) }
        XCTAssertLessThan(firstCycle.max()!, 0.5)
        // 十分な時間が経てば最大振幅まで上がる
        for _ in 0..<4800 {
            _ = synthesizer.nextSample()
        }
        let settled = (0..<109).map { _ in abs(synthesizer.nextSample()) }
        XCTAssertEqual(settled.max()!, 1, accuracy: 0.01)
    }

    func testSynthesizerFadesOutAndBecomesSilentAfterStop() {
        var synthesizer = ToneSynthesizer(sampleRate: 48000, frequency: 440, volume: 1)
        synthesizer.update(frequency: 440, volume: 1, isPlaying: true)
        for _ in 0..<4800 {
            _ = synthesizer.nextSample()
        }
        synthesizer.update(frequency: 440, volume: 1, isPlaying: false)
        // 停止直後はまだフェードアウト中で、すぐには無音にならない
        XCTAssertFalse(synthesizer.isSilent)
        var previousPeak = Float.greatestFiniteMagnitude
        // 約 -80dB まで下がるのは時定数の約 9.2 倍（46ms）。余裕を見て 1 周期 × 30（68ms）回す
        for _ in 0..<30 {
            let peak = (0..<109).map { _ in abs(synthesizer.nextSample()) }.max()!
            XCTAssertLessThanOrEqual(peak, previousPeak + 1e-6)
            previousPeak = peak
        }
        synthesizer.update(frequency: 440, volume: 1, isPlaying: false)
        XCTAssertTrue(synthesizer.isSilent)
    }

    func testSynthesizerGlidesFrequencyWhilePlaying() {
        var synthesizer = ToneSynthesizer(sampleRate: 48000, frequency: 440, volume: 1)
        synthesizer.update(frequency: 440, volume: 1, isPlaying: true)
        for _ in 0..<4800 {
            _ = synthesizer.nextSample()
        }
        synthesizer.update(frequency: 880, volume: 1, isPlaying: true)
        _ = synthesizer.nextSample()
        // 1 サンプル目では目標に届かず、中間の周波数になっている
        XCTAssertGreaterThan(synthesizer.generator.frequency, 440)
        XCTAssertLessThan(synthesizer.generator.frequency, 880)
        for _ in 0..<2400 {
            _ = synthesizer.nextSample()
        }
        XCTAssertEqual(synthesizer.generator.frequency, 880, accuracy: 0.1)
    }

    func testSynthesizerStartsAtTargetFrequencyFromSilence() {
        var synthesizer = ToneSynthesizer(sampleRate: 48000, frequency: 440, volume: 1)
        // 停止中に周波数を変えてから鳴らしたときは、前の周波数から滑らせない
        synthesizer.update(frequency: 1000, volume: 1, isPlaying: true)
        _ = synthesizer.nextSample()
        XCTAssertEqual(synthesizer.generator.frequency, 1000)
    }

    func testSynthesizerOutputHasNoLargeJumpOnStartAndStop() {
        // 開始・停止をまたいでも、隣り合うサンプルの差は正弦波の 1 サンプル分の変化量を超えない
        let sampleRate = 48000.0
        let maxStep = Float(2 * Double.pi * 440 / sampleRate) + 1e-3
        var synthesizer = ToneSynthesizer(sampleRate: sampleRate, frequency: 440, volume: 1)
        var previous: Float = 0
        for index in 0..<9600 {
            if index % 1024 == 0 {
                synthesizer.update(frequency: 440, volume: 1, isPlaying: (index / 1024) % 2 == 0)
            }
            let sample = synthesizer.nextSample()
            XCTAssertLessThanOrEqual(abs(sample - previous), maxStep)
            previous = sample
        }
    }
}
