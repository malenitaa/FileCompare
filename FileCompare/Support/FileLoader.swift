import Foundation

// Rendered by the UI via CompareError/Strings so the message follows the
// in-app language selector — no LocalizedError text hardcoded here.
enum FileLoaderError: Error, Equatable {
    case notText
}

enum FileLoader {
    /// Tries UTF-16 (BOM or NUL pattern), then UTF-8, then falls back to a
    /// handful of common single-byte encodings.
    static func readText(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> String {
        // UTF-16 is NOT self-validating without a BOM: almost any even-length
        // byte pair is *some* valid UTF-16 code unit, and Foundation silently
        // drops a trailing odd byte rather than failing. Decoding as UTF-16
        // without a BOM can turn ordinary Latin-1 text into garbage (verified:
        // bytes 0xE9 0xE8 0xE0, plain "éèà" in Latin-1, silently decode as a
        // single wrong UTF-16 character if tried here) — so only take this
        // path when a real BOM says the bytes are actually UTF-16, or when the
        // NUL pattern below does.
        if hasUTF16BOM(data), let text = String(data: data, encoding: .utf16) {
            return text
        }
        // NUL is valid UTF-8, so this check has to run *before* trusting
        // UTF-8: otherwise BOM-less UTF-16 or a NUL-filled binary decodes as
        // "UTF-8" text full of NULs. Real text files never contain NUL, so a
        // NUL means BOM-less UTF-16 (recognisable by where the NULs fall) or
        // not text at all.
        if data.contains(0) {
            if let encoding = bomlessUTF16Encoding(data),
               let text = String(data: data, encoding: encoding) {
                return text
            }
            throw FileLoaderError.notText
        }
        // UTF-8 is self-validating (its multi-byte structure makes false
        // positives on arbitrary bytes vanishingly unlikely) — trust it outright.
        if let text = String(data: data, encoding: .utf8) { return text }

        // .isoLatin1/.windowsCP1252 map every possible byte value to *some*
        // character, so they never fail to decode — which means, unguarded,
        // they'll happily turn a PNG or a compiled binary into text-shaped
        // garbage instead of reporting notText. Reject anything that looks
        // binary (a heavy concentration of control bytes; NULs were already
        // handled above) before trying them.
        if looksBinary(data) {
            throw FileLoaderError.notText
        }
        if let text = String(data: data, encoding: .isoLatin1) { return text }
        if let text = String(data: data, encoding: .windowsCP1252) { return text }
        throw FileLoaderError.notText
    }

    private static func hasUTF16BOM(_ data: Data) -> Bool {
        guard data.count >= 2 else { return false }
        let first2 = data.prefix(2)
        return first2.elementsEqual([0xFF, 0xFE]) || first2.elementsEqual([0xFE, 0xFF])
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

    static func write(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func fileSize(at url: URL) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int
    }
}
