import Foundation

// Rendered by the UI via CompareError/Strings so the message follows the
// in-app language selector — no LocalizedError text hardcoded here.
enum FileLoaderError: Error, Equatable {
    case notText
}

enum FileLoader {
    /// Tries UTF-8 first, then falls back to a handful of common encodings.
    static func readText(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> String {
        // UTF-8 is self-validating (its multi-byte structure makes false
        // positives on arbitrary bytes vanishingly unlikely) — trust it outright.
        if let text = String(data: data, encoding: .utf8) { return text }
        // UTF-16 is NOT self-validating without a BOM: almost any even-length
        // byte pair is *some* valid UTF-16 code unit, and Foundation silently
        // drops a trailing odd byte rather than failing. Decoding as UTF-16
        // without a BOM can turn ordinary Latin-1 text into garbage (verified:
        // bytes 0xE9 0xE8 0xE0, plain "éèà" in Latin-1, silently decode as a
        // single wrong UTF-16 character if tried here) — so only take this
        // path when a real BOM says the bytes are actually UTF-16.
        if hasUTF16BOM(data), let text = String(data: data, encoding: .utf16) {
            return text
        }

        // .isoLatin1/.windowsCP1252 map every possible byte value to *some*
        // character, so they never fail to decode — which means, unguarded,
        // they'll happily turn a PNG or a compiled binary into text-shaped
        // garbage instead of reporting notText. Reject anything that looks
        // binary (a NUL byte, or a heavy concentration of control bytes)
        // before trying them.
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

    private static func looksBinary(_ data: Data) -> Bool {
        if data.contains(0) { return true }
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
