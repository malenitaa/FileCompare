import XCTest
@testable import FileCompare

final class FileLoaderTests: XCTestCase {
    func testPlainUTF8TextDecodes() throws {
        let data = Data("hola mundo".utf8)
        XCTAssertEqual(try FileLoader.decode(data), "hola mundo")
    }

    func testBinaryDataWithNulByteIsRejected() {
        var bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] // PNG header
        bytes.append(contentsOf: (0..<500).map { _ in UInt8.random(in: 0...255) })
        let data = Data(bytes)
        XCTAssertThrowsError(try FileLoader.decode(data)) { error in
            XCTAssertTrue(error is FileLoaderError)
        }
    }

    func testLegacyEncodingWithoutBinaryMarkersStillDecodes() throws {
        // Latin-1 text with accented characters and no NUL/control bytes should
        // still fall through to the legacy-encoding path successfully, and NOT
        // get mis-decoded as UTF-16 along the way (the BOM-less UTF-16 path is
        // gated behind an actual BOM precisely to avoid that).
        let data = Data([0xE9, 0xE8, 0xE0]) // "éèà" in ISO Latin-1
        let text = try FileLoader.decode(data)
        XCTAssertEqual(text, "éèà")
        XCTAssertEqual(text.count, 3)
    }

    func testUTF16WithBOMDecodesCorrectly() throws {
        let text = "hola"
        let data = text.data(using: .utf16)! // Foundation prepends a BOM here.
        XCTAssertEqual(try FileLoader.decode(data), text)
    }
}
