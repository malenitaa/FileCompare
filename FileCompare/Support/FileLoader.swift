import Foundation

enum FileLoaderError: LocalizedError {
    case notText

    var errorDescription: String? {
        switch self {
        case .notText:
            return "El archivo no parece ser texto plano (encoding no reconocido)."
        }
    }
}

enum FileLoader {
    /// Tries UTF-8 first, then falls back to a handful of common encodings.
    static func readText(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> String {
        for encoding in [String.Encoding.utf8, .isoLatin1, .windowsCP1252, .utf16] {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        throw FileLoaderError.notText
    }

    static func write(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func fileSize(at url: URL) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int
    }
}
