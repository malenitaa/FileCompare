import XCTest
@testable import FileCompare

final class WordDiffEngineTests: XCTestCase {
    func testTokenizePreservesAllCharacters() {
        let tokens = WordDiffEngine.tokenize("let x = 1 + 2;")
        XCTAssertEqual(tokens.joined(), "let x = 1 + 2;")
    }

    func testWordLevelHighlightsOnlyChangedWord() {
        let (left, right) = WordDiffEngine.diffSegments(left: "hello world", right: "hello there", options: DiffOptions())
        XCTAssertEqual(left.map(\.text).joined(), "hello world")
        XCTAssertEqual(right.map(\.text).joined(), "hello there")
        XCTAssertTrue(left.contains { $0.text == "world" && $0.changed })
        XCTAssertTrue(right.contains { $0.text == "there" && $0.changed })
        XCTAssertFalse(left.contains { $0.text.contains("hello") && $0.changed })
    }
}
