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
}
