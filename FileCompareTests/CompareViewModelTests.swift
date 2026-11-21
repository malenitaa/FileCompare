import XCTest
@testable import FileCompare

@MainActor
final class CompareViewModelTests: XCTestCase {
    private var directory: URL!
    private var savedRecents: [String: Any] = [:]
    private let recentKeys = ["RecentFilesStore.leftPath", "RecentFilesStore.rightPath"]

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // The tests run inside the app, so the view model reads and writes the
        // real recent-files defaults: set them aside and start empty, so the
        // init doesn't load the user's files and the tests don't replace them.
        let defaults = UserDefaults.standard
        for key in recentKeys {
            savedRecents[key] = defaults.object(forKey: key)
            defaults.removeObject(forKey: key)
        }
    }

    override func tearDown() async throws {
        let defaults = UserDefaults.standard
        for key in recentKeys {
            defaults.set(savedRecents[key], forKey: key)
        }
        try? FileManager.default.removeItem(at: directory)
    }

    func testSavingKeepsLatin1Encoding() throws {
        let url = directory.appendingPathComponent("latin1.txt")
        let latin1 = Data([0x61, 0xF1, 0x6F, 0x0A]) // "año\n" in ISO Latin-1
        try latin1.write(to: url)

        let viewModel = CompareViewModel()
        viewModel.loadFile(url, into: .left)
        XCTAssertEqual(viewModel.leftText, "año\n")
        viewModel.save(side: .left)

        XCTAssertNil(viewModel.activeError)
        XCTAssertEqual(try Data(contentsOf: url), latin1)
    }
}
