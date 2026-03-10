import XCTest
@testable import VideoNotes

final class TimecodeTests: XCTestCase {

    func testTimecodeFromZeroSeconds() {
        let tc = TimecodeInfo.from(seconds: 0, frameRate: 24)
        XCTAssertEqual(tc.hours, 0)
        XCTAssertEqual(tc.minutes, 0)
        XCTAssertEqual(tc.seconds, 0)
        XCTAssertEqual(tc.frames, 0)
        XCTAssertEqual(tc.description, "00:00:00:00")
    }

    func testTimecodeFromSeconds24fps() {
        // 1 hour, 2 minutes, 3 seconds, 12 frames at 24fps
        let seconds: Double = 3600 + 120 + 3 + 12.0 / 24.0
        let tc = TimecodeInfo.from(seconds: seconds, frameRate: 24)
        XCTAssertEqual(tc.hours, 1)
        XCTAssertEqual(tc.minutes, 2)
        XCTAssertEqual(tc.seconds, 3)
        XCTAssertEqual(tc.frames, 12)
        XCTAssertEqual(tc.description, "01:02:03:12")
    }

    func testTimecodeFromSeconds25fps() {
        let seconds: Double = 10 + 13.0 / 25.0
        let tc = TimecodeInfo.from(seconds: seconds, frameRate: 25)
        XCTAssertEqual(tc.seconds, 10)
        XCTAssertEqual(tc.frames, 13)
        XCTAssertEqual(tc.description, "00:00:10:13")
    }

    func testTimecodeFromSeconds30fps() {
        let seconds: Double = 60 + 15.0 / 30.0
        let tc = TimecodeInfo.from(seconds: seconds, frameRate: 30)
        XCTAssertEqual(tc.minutes, 1)
        XCTAssertEqual(tc.seconds, 0)
        XCTAssertEqual(tc.frames, 15)
    }

    func testNonDropFrameFormat() {
        let tc = TimecodeInfo(hours: 1, minutes: 0, seconds: 0, frames: 0, frameRate: 24, isDropFrame: false)
        XCTAssertEqual(tc.description, "01:00:00:00")
        XCTAssertFalse(tc.description.contains(";"))
    }

    func testDropFrameFormat() {
        let tc = TimecodeInfo(hours: 1, minutes: 0, seconds: 0, frames: 0, frameRate: 29.97, isDropFrame: true)
        XCTAssertEqual(tc.description, "01:00:00;00")
        XCTAssertTrue(tc.description.contains(";"))
    }

    func testTotalSeconds() {
        let tc = TimecodeInfo(hours: 0, minutes: 1, seconds: 30, frames: 0, frameRate: 24, isDropFrame: false)
        XCTAssertEqual(tc.totalSeconds, 90.0, accuracy: 0.001)
    }

    func testTotalFrames() {
        let tc = TimecodeInfo(hours: 0, minutes: 0, seconds: 1, frames: 0, frameRate: 24, isDropFrame: false)
        XCTAssertEqual(tc.totalFrames, 24)
    }
}
