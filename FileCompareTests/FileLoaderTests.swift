import XCTest
@testable import FileCompare

final class FileLoaderTests: XCTestCase {
    func testPlainUTF8TextDecodes() throws {
        let data = Data("hola mundo".utf8)
        XCTAssertEqual(try FileLoader.decode(data).text, "hola mundo")
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
        let text = try FileLoader.decode(data).text
        XCTAssertEqual(text, "éèà")
        XCTAssertEqual(text.count, 3)
    }

    func testUTF16WithBOMDecodesCorrectly() throws {
        let text = "hola"
        let data = text.data(using: .utf16)! // Foundation prepends a BOM here.
        XCTAssertEqual(try FileLoader.decode(data).text, text)
    }

    func testUTF16LittleEndianWithoutBOMDecodes() throws {
        // NUL is valid UTF-8, so these bytes used to be accepted as UTF-8 and
        // shown as "h\0o\0l\0a\0…" instead of being recognised as UTF-16.
        let text = "hola mundo"
        let data = text.data(using: .utf16LittleEndian)!
        XCTAssertEqual(try FileLoader.decode(data).text, text)
    }

    func testUTF16BigEndianWithoutBOMDecodes() throws {
        let text = "hola mundo"
        let data = text.data(using: .utf16BigEndian)!
        XCTAssertEqual(try FileLoader.decode(data).text, text)
    }

    func testNULFilledDataIsRejected() {
        let data = Data(repeating: 0, count: 64)
        XCTAssertThrowsError(try FileLoader.decode(data)) { error in
            XCTAssertEqual(error as? FileLoaderError, .notText)
        }
    }

    func testASCIIWithStrayNULIsRejected() {
        let data = Data("abc\0def".utf8)
        XCTAssertThrowsError(try FileLoader.decode(data)) { error in
            XCTAssertEqual(error as? FileLoaderError, .notText)
        }
    }

    func testWindows1252PunctuationDecodes() throws {
        // Bytes 0x80-0x9F are printable in Windows-1252 but C1 control
        // characters in Latin-1, so trying Latin-1 first hid them.
        let data = Data([0x31, 0x30, 0x20, 0x80, 0x20, 0x93, 0x68, 0x6F, 0x6C, 0x61, 0x94, 0x20, 0x96])
        let decoded = try FileLoader.decode(data)
        XCTAssertEqual(decoded, DecodedText(text: "10 € “hola” –", encoding: TextEncoding(encoding: .windowsCP1252)))
    }

    func testSingleByteTextReportsWindows1252() throws {
        let decoded = try FileLoader.decode(Data([0x61, 0xF1, 0x6F])) // "año"
        XCTAssertEqual(decoded, DecodedText(text: "año", encoding: TextEncoding(encoding: .windowsCP1252)))
    }

    func testBytesUndefinedInWindows1252FallBackToLatin1() throws {
        // 0x81 has no character in Windows-1252, so that decode fails and
        // Latin-1 (which maps every byte) takes the file.
        let decoded = try FileLoader.decode(Data([0x61, 0x81, 0xF1]))
        XCTAssertEqual(decoded, DecodedText(text: "a\u{81}ñ", encoding: TextEncoding(encoding: .isoLatin1)))
    }

    func testEuroTypedIntoSingleByteFileSavesInPlace() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let decoded = try FileLoader.decode(Data([0x61, 0xF1, 0x6F])) // "año"
        try FileLoader.write(decoded.text + " €", to: url, encoding: decoded.encoding)
        XCTAssertEqual(try Data(contentsOf: url), Data([0x61, 0xF1, 0x6F, 0x20, 0x80]))
    }

    func testWriteKeepsLatin1Bytes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let latin1 = Data([0x61, 0xF1, 0x6F]) // "año"
        let decoded = try FileLoader.decode(latin1)
        try FileLoader.write(decoded.text, to: url, encoding: decoded.encoding)
        XCTAssertEqual(try Data(contentsOf: url), latin1)
    }

    func testWriteKeepsUTF16BOMAndByteOrder() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data([0xFE, 0xFF]) + "año".data(using: .utf16BigEndian)!
        let decoded = try FileLoader.decode(original)
        XCTAssertEqual(decoded.text, "año")
        try FileLoader.write(decoded.text, to: url, encoding: decoded.encoding)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testWriteKeepsUTF8BOM() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data([0xEF, 0xBB, 0xBF]) + Data("año".utf8)
        let decoded = try FileLoader.decode(original)
        XCTAssertEqual(decoded.text, "año")
        try FileLoader.write(decoded.text, to: url, encoding: decoded.encoding)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testWriteRefusesTextTheEncodingCantHold() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try FileLoader.write("10 €", to: url, encoding: TextEncoding(encoding: .isoLatin1))) { error in
            XCTAssertEqual(error as? FileLoaderError, .notRepresentable)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testReadRefusesFilesOverTheCapWithoutReadingThem() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(FileLoader.maxFileSize + 1)) // sparse: no real disk use
        try handle.close()

        XCTAssertThrowsError(try FileLoader.readText(from: url)) { error in
            XCTAssertEqual(error as? FileLoaderError, .tooLarge)
        }
    }
}
