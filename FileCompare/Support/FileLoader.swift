import Foundation

// Rendered by the UI via CompareError/Strings so the message follows the
// in-app language selector — no LocalizedError text hardcoded here.
enum FileLoaderError: Error, Equatable {
    case notText
    /// The text has characters the file's original encoding can't hold.
    case notRepresentable
    /// Over `FileLoader.maxFileSize`.
    case tooLarge
}

/// How a file's bytes were decoded, so saving can write them back the same way.
struct TextEncoding: Equatable {
    var encoding: String.Encoding
    /// The byte-order mark the file started with. Foundation strips it when
    /// decoding, so it's kept here to be written back on save.
    var bom: [UInt8] = []

    static let utf8 = TextEncoding(encoding: .utf8)
}

struct DecodedText: Equatable {
    var text: String
    var encoding: TextEncoding
}

enum FileLoader {
    private static let utf8BOM: [UInt8] = [0xEF, 0xBB, 0xBF]

    /// Hard cap: past this, reading the file, decoding it, splitting it into
    /// lines and handing it to the text views can exhaust memory. Files over
    /// 50MB already get a "may be slow" warning; this one refuses to open.
    static let maxFileSize = 100 * 1024 * 1024

    /// Tries UTF-16 (BOM or NUL pattern), then UTF-8, then falls back to a
    /// handful of common single-byte encodings.
    static func readText(from url: URL) throws -> DecodedText {
        if let size = fileSize(at: url), size > maxFileSize {
            throw FileLoaderError.tooLarge
        }
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> DecodedText {
        // UTF-16 is NOT self-validating without a BOM: almost any even-length
        // byte pair is *some* valid UTF-16 code unit, and Foundation silently
        // drops a trailing odd byte rather than failing. Decoding as UTF-16
        // without a BOM can turn ordinary Latin-1 text into garbage (verified:
        // bytes 0xE9 0xE8 0xE0, plain "éèà" in Latin-1, silently decode as a
        // single wrong UTF-16 character if tried here) — so only take this
        // path when a real BOM says the bytes are actually UTF-16, or when the
        // NUL pattern below does.
        if let encoding = utf16BOMEncoding(data), let text = String(data: data, encoding: .utf16) {
            return DecodedText(text: text, encoding: TextEncoding(encoding: encoding, bom: Array(data.prefix(2))))
        }
        // NUL is valid UTF-8, so this check has to run *before* trusting
        // UTF-8: otherwise BOM-less UTF-16 or a NUL-filled binary decodes as
        // "UTF-8" text full of NULs. Real text files never contain NUL, so a
        // NUL means BOM-less UTF-16 (recognisable by where the NULs fall) or
        // not text at all.
        if data.contains(0) {
            if let encoding = bomlessUTF16Encoding(data),
               let text = String(data: data, encoding: encoding) {
                return DecodedText(text: text, encoding: TextEncoding(encoding: encoding))
            }
            throw FileLoaderError.notText
        }
        // UTF-8 is self-validating (its multi-byte structure makes false
        // positives on arbitrary bytes vanishingly unlikely) — trust it outright.
        if let text = String(data: data, encoding: .utf8) {
            let bom = data.starts(with: utf8BOM) ? utf8BOM : []
            return DecodedText(text: text, encoding: TextEncoding(encoding: .utf8, bom: bom))
        }

        // .isoLatin1/.windowsCP1252 map every possible byte value to *some*
        // character, so they never fail to decode — which means, unguarded,
        // they'll happily turn a PNG or a compiled binary into text-shaped
        // garbage instead of reporting notText. Reject anything that looks
        // binary (a heavy concentration of control bytes; NULs were already
        // handled above) before trying them.
        if looksBinary(data) {
            throw FileLoaderError.notText
        }
        for encoding in [String.Encoding.isoLatin1, .windowsCP1252] {
            if let text = String(data: data, encoding: encoding) {
                return DecodedText(text: text, encoding: TextEncoding(encoding: encoding))
            }
        }
        throw FileLoaderError.notText
    }

    private static func utf16BOMEncoding(_ data: Data) -> String.Encoding? {
        if data.starts(with: [0xFF, 0xFE]) { return .utf16LittleEndian }
        if data.starts(with: [0xFE, 0xFF]) { return .utf16BigEndian }
        return nil
    }

    /// Mostly-Latin text in BOM-less UTF-16 has a NUL in one byte of nearly
    /// every pair (the high byte: odd offsets in little-endian, even ones in
    /// big-endian) and almost never in the other. Binary data spreads its
    /// NULs over both, so it doesn't match either pattern.
    private static func bomlessUTF16Encoding(_ data: Data) -> String.Encoding? {
        guard data.count >= 2, data.count % 2 == 0 else { return nil }
        let sample = data.prefix(8000)
        var evenNULs = 0
        var oddNULs = 0
        for (offset, byte) in sample.enumerated() where byte == 0 {
            if offset % 2 == 0 { evenNULs += 1 } else { oddNULs += 1 }
        }
        let pairs = sample.count / 2
        let few = pairs / 100
        if oddNULs * 2 >= pairs, evenNULs <= few { return .utf16LittleEndian }
        if evenNULs * 2 >= pairs, oddNULs <= few { return .utf16BigEndian }
        return nil
    }

    private static func looksBinary(_ data: Data) -> Bool {
        let sample = data.prefix(8000)
        guard !sample.isEmpty else { return false }
        let controlBytes = sample.filter { byte in
            byte < 0x09 || (byte > 0x0D && byte < 0x20)
        }.count
        return Double(controlBytes) / Double(sample.count) > 0.01
    }

    /// Writes `text` back in the encoding (and BOM) it was read with. Throws
    /// `notRepresentable` instead of silently switching encodings when the
    /// text has characters that encoding can't hold.
    static func write(_ text: String, to url: URL, encoding: TextEncoding) throws {
        guard let body = text.data(using: encoding.encoding) else {
            throw FileLoaderError.notRepresentable
        }
        try (Data(encoding.bom) + body).write(to: url, options: .atomic)
    }

    static func fileSize(at url: URL) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int
    }
}
