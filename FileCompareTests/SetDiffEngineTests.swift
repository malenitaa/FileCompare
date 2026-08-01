import XCTest
@testable import FileCompare

final class SetDiffEngineTests: XCTestCase {
    /// Mirrors the real shape of Instagram's data export: "following" lists
    /// each person as username / blank / profile URL / timestamp, while
    /// "followers" lists each as just username / timestamp — a different
    /// number of lines per entry, which is exactly why a positional line
    /// diff can't compare these two files meaningfully.
    private let following = """
    jppieczocha

    https://www.instagram.com/_u/jppieczocha
    Jul 13, 2026 8:33 am
    nacho_r3

    https://www.instagram.com/_u/nacho_r3
    Jun 12, 2026 8:49 am
    soloSigo

    https://www.instagram.com/_u/soloSigo
    May 01, 2026 9:00 am
    """

    private let followers = """
    jppieczocha
    Jul 13, 2026 8:33 am
    nacho_r3
    Jun 05, 2026 8:19 am
    soloMeSigue
    Apr 01, 2026 7:00 am
    """

    func testWithoutNoiseFilterURLsPolluteTheResult() {
        let options = DiffOptions()
        let result = SetDiffEngine.compute(leftText: following, rightText: followers, options: options)
        // "following" has a URL line per person that "followers" never has,
        // so without filtering it shows up as a spurious "only in left" —
        // even for someone who's actually a mutual follow.
        XCTAssertTrue(result.onlyLeft.contains { $0.hasPrefix("https://") })
    }

    func testNoiseFilterMatchesUsersByUsernameOnly() {
        var options = DiffOptions()
        options.ignoreNoiseLines = true
        let result = SetDiffEngine.compute(leftText: following, rightText: followers, options: options)

        XCTAssertEqual(Set(result.both), ["jppieczocha", "nacho_r3"])
        XCTAssertEqual(result.onlyLeft, ["soloSigo"])
        XCTAssertEqual(result.onlyRight, ["soloMeSigue"])
    }

    func testNoiseFilterRecognizesOtherDateFormatsToo() {
        // Not tied to Instagram's specific "Jul 13, 2026 8:33 am" shape —
        // uses macOS's system date detector, which understands plenty of
        // other formats too.
        var options = DiffOptions()
        options.ignoreNoiseLines = true
        let left = "alice\n2026-07-13\n07/13/2026 08:33"
        let right = "alice\nbob"
        let result = SetDiffEngine.compute(leftText: left, rightText: right, options: options)
        XCTAssertEqual(result.both, ["alice"])
        XCTAssertEqual(result.onlyRight, ["bob"])
        XCTAssertTrue(result.onlyLeft.isEmpty, "date-shaped lines should be dropped as noise, got \(result.onlyLeft)")
    }

    func testNoiseFilterCombinesWithIgnoreCase() {
        var options = DiffOptions()
        options.ignoreNoiseLines = true
        options.ignoreCase = true
        let result = SetDiffEngine.compute(leftText: "JPpieczocha\nhttps://x/JPpieczocha", rightText: "jppieczocha", options: options)
        XCTAssertEqual(result.both, ["jppieczocha"])
    }
}
