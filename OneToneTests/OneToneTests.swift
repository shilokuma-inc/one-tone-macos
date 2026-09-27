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

    func testStopToneResetsIsPlaying() throws {
        let manager = AudioManager()
        // 出力デバイスが無い環境ではエンジンが起動せず、play() が例外で落ちるためスキップする
        try XCTSkipUnless(manager.audioEngine.isRunning, "AVAudioEngine が起動していない環境")
        manager.playTone(frequency: 440)
        XCTAssertTrue(manager.isPlaying)
        manager.stopTone()
        XCTAssertFalse(manager.isPlaying)
    }

    func testUpdateFrequencyAfterStopDoesNotRestartPlayback() throws {
        let manager = AudioManager()
        try XCTSkipUnless(manager.audioEngine.isRunning, "AVAudioEngine が起動していない環境")
        manager.playTone(frequency: 440)
        manager.stopTone()
        manager.updateFrequency(1000)
        XCTAssertFalse(manager.isPlaying)
        XCTAssertEqual(manager.currentFrequency, 1000)
    }

}
