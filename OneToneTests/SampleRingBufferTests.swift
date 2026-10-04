//
//  SampleRingBufferTests.swift
//  OneToneTests
//

import XCTest
@testable import OneTone

final class SampleRingBufferTests: XCTestCase {

    func testLatestIsEmptyBeforeWriting() {
        let buffer = SampleRingBuffer(capacity: 4)
        defer { buffer.deallocate() }
        XCTAssertEqual(buffer.totalWritten, 0)
        XCTAssertEqual(buffer.latest(4), [])
    }

    func testLatestReturnsOnlyWrittenSamplesInOrder() {
        let buffer = SampleRingBuffer(capacity: 4)
        defer { buffer.deallocate() }
        buffer.write(0.1)
        buffer.write(0.2)
        XCTAssertEqual(buffer.totalWritten, 2)
        XCTAssertEqual(buffer.latest(4), [0.1, 0.2])
        XCTAssertEqual(buffer.latest(1), [0.2])
    }

    func testLatestKeepsNewestSamplesAfterWrapAround() {
        let buffer = SampleRingBuffer(capacity: 4)
        defer { buffer.deallocate() }
        for sample in [1, 2, 3, 4, 5, 6] as [Float] {
            buffer.write(sample)
        }
        XCTAssertEqual(buffer.totalWritten, 6)
        XCTAssertEqual(buffer.latest(4), [3, 4, 5, 6])
        XCTAssertEqual(buffer.latest(2), [5, 6])
    }

    func testLatestIsLimitedToCapacity() {
        let buffer = SampleRingBuffer(capacity: 3)
        defer { buffer.deallocate() }
        for sample in [1, 2, 3, 4, 5] as [Float] {
            buffer.write(sample)
        }
        XCTAssertEqual(buffer.latest(10), [3, 4, 5])
    }

    func testLatestWithNonPositiveCountIsEmpty() {
        let buffer = SampleRingBuffer(capacity: 3)
        defer { buffer.deallocate() }
        buffer.write(1)
        XCTAssertEqual(buffer.latest(0), [])
        XCTAssertEqual(buffer.latest(-1), [])
    }

    func testCopiesShareTheSameStorage() {
        // レンダーブロックはコピーを持つので、コピーへの書き込みが元から読めること
        let buffer = SampleRingBuffer(capacity: 4)
        defer { buffer.deallocate() }
        let writer = buffer
        writer.write(0.5)
        XCTAssertEqual(buffer.latest(1), [0.5])
    }

    func testWriterOnAnotherThreadIsReadable() {
        // 書き込みと読み出しを別スレッドで同時に行っても、読み出し結果の長さと範囲が崩れないこと
        let buffer = SampleRingBuffer(capacity: 256)
        let total = 100_000
        let writer = DispatchGroup()
        writer.enter()
        DispatchQueue.global().async {
            for index in 0..<total {
                buffer.write(Float(index % 2))
            }
            writer.leave()
        }
        for _ in 0..<1000 {
            let samples = buffer.latest(128)
            XCTAssertLessThanOrEqual(samples.count, 128)
            XCTAssertTrue(samples.allSatisfy { $0 == 0 || $0 == 1 })
        }
        XCTAssertEqual(writer.wait(timeout: .now() + 10), .success)
        // タイムアウトしても、書き込み中の領域を解放しないよう書き込みの完了を待ってから解放する
        writer.wait()
        XCTAssertEqual(buffer.totalWritten, total)
        XCTAssertEqual(buffer.latest(2).count, 2)
        buffer.deallocate()
    }
}
