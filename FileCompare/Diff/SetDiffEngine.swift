import Foundation

struct SetDiffResult {
    let onlyLeft: [String]
    let both: [String]
    let onlyRight: [String]
}

/// Treats each file as an unordered bag of lines instead of an ordered
/// sequence — useful whenever the same "item" can span a different number of
/// lines in each file (e.g. one export includes a blank line + URL per entry
/// that the other doesn't), which makes a positional line diff never line
/// anything up. Nothing here is tied to any particular file format or
/// service — "ignoreNoiseLines" only drops lines that are blank, a bare URL,
/// or (per macOS's own system date detector, the same one Mail/Messages use)
/// almost entirely a date/time — whatever's left is the comparison key.
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

    /// Apple's own date/time recognizer (what Mail, Messages, and Calendar
    /// use to turn "next Tuesday at 3pm" into a tappable event) — it
    /// understands a wide range of date and time formats out of the box, so
    /// this isn't limited to any one export's particular timestamp style.
    /// A line only counts as "just a timestamp" if the detected date/time
    /// span covers essentially the whole line, not a date mentioned in
    /// passing inside a longer sentence.
    private static let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

    private static func isTimestamp(_ line: String) -> Bool {
        guard let dateDetector else { return false }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = dateDetector.firstMatch(in: line, options: [], range: range) else { return false }
        let lineLength = (line as NSString).length
        guard lineLength > 0 else { return false }
        return Double(match.range.length) / Double(lineLength) >= 0.6
    }
}
