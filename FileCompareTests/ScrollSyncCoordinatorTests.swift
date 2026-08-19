import XCTest
@testable import FileCompare

final class ScrollSyncCoordinatorTests: XCTestCase {
    func testIdentityMappingWithNoAnchors() {
        XCTAssertEqual(ScrollSyncCoordinator.mappedLine(42, from: .left, anchors: []), 42)
    }

    func testExactAnchorMapsDirectly() {
        let anchors: [(left: Int, right: Int)] = [(left: 1, right: 1), (left: 10, right: 10)]
        XCTAssertEqual(ScrollSyncCoordinator.mappedLine(10, from: .left, anchors: anchors), 10)
    }

    /// Left has a 100-line block inserted before line 200; from line 200
    /// onward the files are identical again. Scrolling to left line 250
    /// should land on right line 150 (250 - 100), not "the same fraction of
    /// height" — which is exactly the bug the old fraction-based sync had.
    func testInterpolatesAcrossAnInsertedBlock() {
        let anchors: [(left: Int, right: Int)] = [(left: 1, right: 1), (left: 200, right: 100)]
        XCTAssertEqual(ScrollSyncCoordinator.mappedLine(250, from: .left, anchors: anchors), 150)
    }

    func testMapsFromRightBackToLeftSymmetrically() {
        let anchors: [(left: Int, right: Int)] = [(left: 1, right: 1), (left: 200, right: 100)]
        XCTAssertEqual(ScrollSyncCoordinator.mappedLine(150, from: .right, anchors: anchors), 250)
    }

    func testLineBeforeFirstAnchorExtrapolatesFromIt() {
        let anchors: [(left: Int, right: Int)] = [(left: 50, right: 40)]
        XCTAssertEqual(ScrollSyncCoordinator.mappedLine(45, from: .left, anchors: anchors), 35)
    }
}
