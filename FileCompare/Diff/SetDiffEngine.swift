import Foundation

struct SetDiffResult {
    let onlyLeft: [String]
    let both: [String]
    let onlyRight: [String]
}

/// Treats each file as an unordered bag of lines instead of an ordered
/// sequence — for cases like comparing an Instagram "following" export
/// against a "followers" export, where the same person's entry can span a
/// different number of lines in each file (one has a blank line + URL, the
/// other doesn't), so a positional line diff never lines anything up.
enum SetDiffEngine {
    static func compute(leftText: String, rightText: String, options: DiffOptions) -> SetDiffResult {
        let leftKeys = extractKeys(from: leftText, options: options)
        let rightKeys = extractKeys(from: rightText, options: options)

        let onlyLeft = leftKeys.subtracting(rightKeys).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let both = leftKeys.intersection(rightKeys).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let onlyRight = rightKeys.subtracting(leftKeys).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return SetDiffResult(onlyLeft: onlyLeft, both: both, onlyRight: onlyRight)
    }

    static func extractKeys(from text: String, options: DiffOptions) -> Set<String> {
        var keys = Set<String>()
        for rawLine in LineDiffEngine.splitLines(text) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if options.ignoreNoiseLines {
                if isURL(line) || isTimestamp(line) { continue }
            }
            if !options.stripText.isEmpty {
                line = line.replacingOccurrences(of: options.stripText, with: "")
            }
            if options.ignoreCase {
                line = line.lowercased()
            }
            line = line.trimmingCharacters(in: .whitespaces)
            if !line.isEmpty {
                keys.insert(line)
            }
        }
        return keys
    }

    private static func isURL(_ line: String) -> Bool {
        line.hasPrefix("http://") || line.hasPrefix("https://")
    }

    /// Matches Meta/Instagram export timestamps like "Jul 13, 2026 8:33 am".
    private static let timestampRegex = try! NSRegularExpression(
        pattern: #"^[A-Za-z]{3} \d{1,2}, \d{4} \d{1,2}:\d{2}\s?(am|pm)$"#,
        options: .caseInsensitive
    )

    private static func isTimestamp(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..., in: line)
        return timestampRegex.firstMatch(in: line, range: range) != nil
    }
}
