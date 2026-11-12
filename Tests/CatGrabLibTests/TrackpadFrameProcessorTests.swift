import XCTest
@testable import CatGrabLib

final class TrackpadFrameProcessorTests: XCTestCase {
    private let touches = (0..<3).map { TrackpadTapRecognizer.Touch(id: Int32($0), x: Float($0) * 0.1, y: 0.5) }

    func test_stoppingInvalidatesAnAlreadyQueuedTap() throws {
        let processor = TrackpadFrameProcessor()
        processor.start(fingerCounts: [3])
        _ = processor.process(deviceID: 1, touches: touches, timestamp: 0)
        let tap = try XCTUnwrap(processor.process(deviceID: 1, touches: [], timestamp: 0.1))
        XCTAssertEqual(tap.fingerCount, 3)
        XCTAssertTrue(processor.isCurrent(tap))
        processor.stop()
        XCTAssertFalse(processor.isCurrent(tap))
        XCTAssertNil(processor.process(deviceID: 1, touches: touches, timestamp: 1))
        XCTAssertNil(processor.process(deviceID: 1, touches: [], timestamp: 1.1))
    }

    func test_reconnectingSameDeviceDoesNotCompleteAnOldGesture() {
        let processor = TrackpadFrameProcessor()
        processor.start(fingerCounts: [3])
        _ = processor.process(deviceID: 1, touches: touches, timestamp: 0)
        processor.start(fingerCounts: [3])
        XCTAssertNil(processor.process(deviceID: 1, touches: [], timestamp: 0.1))
    }

    func test_twoTrackpadsDoNotShareContacts() {
        let processor = TrackpadFrameProcessor()
        processor.start(fingerCounts: [3])
        _ = processor.process(deviceID: 1, touches: touches, timestamp: 0)
        XCTAssertNil(processor.process(deviceID: 2, touches: [], timestamp: 0.1))
        XCTAssertEqual(processor.process(deviceID: 1, touches: [], timestamp: 0.1)?.fingerCount, 3)
        _ = processor.process(deviceID: 0, touches: touches, timestamp: 0)
        XCTAssertEqual(processor.process(deviceID: 0, touches: [], timestamp: 0.1)?.fingerCount, 3)
    }

    func test_invalidFramesAndClockResetsDoNotTriggerATap() {
        for invalidTime in [Double.nan, .infinity, -1] {
            var recognizer = TrackpadTapRecognizer(fingerCount: 3)
            _ = recognizer.process(touches: touches, timestamp: 0)
            XCTAssertFalse(recognizer.process(touches: [], timestamp: invalidTime))
        }
        var recognizer = TrackpadTapRecognizer(fingerCount: 3)
        _ = recognizer.process(touches: [TrackpadTapRecognizer.Touch(id: 0, x: .nan, y: 0)], timestamp: 0)
        XCTAssertFalse(recognizer.process(touches: [], timestamp: 0.1))
    }

    func test_deviceRestartsCanOverlapCallbacks() {
        let processor = TrackpadFrameProcessor()
        DispatchQueue.concurrentPerform(iterations: 1_000) { iteration in
            if iteration.isMultiple(of: 3) {
                processor.start(fingerCounts: [3, 4])
            } else if iteration.isMultiple(of: 5) {
                processor.stop()
            } else {
                _ = processor.process(deviceID: 1, touches: touches, timestamp: Double(iteration))
            }
        }
        processor.stop()
        XCTAssertNil(processor.process(deviceID: 1, touches: [], timestamp: 1_001))
    }
}
