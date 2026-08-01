import XCTest
@testable import FileCompare

final class LineDiffEngineTests: XCTestCase {
    func testIdenticalFilesProduceNoChanges() {
        let text = "a\nb\nc"
        let result = DiffEngine.compute(leftText: text, rightText: text, options: DiffOptions())
        XCTAssertEqual(result.summary, DiffSummary())
        XCTAssertTrue(result.lines.allSatisfy { $0.kind == .unchanged })
    }

    func testPureAddition() {
        let left = "a\nb"
        let right = "a\nb\nc"
        let result = DiffEngine.compute(leftText: left, rightText: right, options: DiffOptions())
        XCTAssertEqual(result.summary.added, 1)
        XCTAssertEqual(result.summary.removed, 0)
        XCTAssertEqual(result.summary.modified, 0)
    }

    func testPureRemoval() {
        let left = "a\nb\nc"
        let right = "a\nc"
        let result = DiffEngine.compute(leftText: left, rightText: right, options: DiffOptions())
        XCTAssertEqual(result.summary.removed, 1)
        XCTAssertEqual(result.summary.added, 0)
    }

    func testReplacementIsMarkedModified() {
        let left = "a\nhello world\nc"
        let right = "a\nhello there\nc"
        let result = DiffEngine.compute(leftText: left, rightText: right, options: DiffOptions())
        XCTAssertEqual(result.summary.modified, 1)
        XCTAssertEqual(result.summary.added, 0)
        XCTAssertEqual(result.summary.removed, 0)
    }

    func testIgnoreWhitespaceOption() {
        let left = "hello   world"
        let right = "hello world"
        var options = DiffOptions()
        options.ignoreWhitespace = true
        let result = DiffEngine.compute(leftText: left, rightText: right, options: options)
        XCTAssertEqual(result.summary, DiffSummary())
    }

    func testIgnoreCaseOption() {
        let left = "Hello World"
        let right = "hello world"
        var options = DiffOptions()
        options.ignoreCase = true
        let result = DiffEngine.compute(leftText: left, rightText: right, options: options)
        XCTAssertEqual(result.summary, DiffSummary())
    }

    func testChangeGroupsMergeContiguousChanges() {
        let left = "a\nb\nc\nd\ne"
        let right = "a\nX\nY\nd\ne"
        let result = DiffEngine.compute(leftText: left, rightText: right, options: DiffOptions())
        XCTAssertEqual(result.changeGroups.count, 1)
    }

    func testLargeFileDisablesWordDiff() {
        var options = DiffOptions()
        options.largeFileLineThreshold = 2
        let left = "a\nb\nc"
        let right = "a\nx\nc"
        let result = DiffEngine.compute(leftText: left, rightText: right, options: options)
        XCTAssertTrue(result.wordDiffDisabled)
        XCTAssertTrue(result.lines.allSatisfy { $0.leftSegments == nil && $0.rightSegments == nil })
    }
}
