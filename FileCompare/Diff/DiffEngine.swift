import Foundation

/// Orchestrates the two-pass diff: line-level first, then word-level only on
/// lines marked `.modified`. Safe to call off the main thread — `CompareViewModel`
/// always runs this in a background `Task`.
enum DiffEngine {
    static func compute(leftText: String, rightText: String, options: DiffOptions) -> DiffResult {
        let leftLines = LineDiffEngine.splitLines(leftText)
        let rightLines = LineDiffEngine.splitLines(rightText)

        let isLarge = leftText.utf8.count > options.largeFileByteThreshold
            || rightText.utf8.count > options.largeFileByteThreshold
            || leftLines.count > options.largeFileLineThreshold
            || rightLines.count > options.largeFileLineThreshold

        var (lines, summary) = LineDiffEngine.diff(left: leftLines, right: rightLines, options: options)

        if !isLarge {
            for index in lines.indices where lines[index].kind == .modified {
                guard let leftText = lines[index].leftText, let rightText = lines[index].rightText else { continue }
                let (leftSegments, rightSegments) = WordDiffEngine.diffSegments(left: leftText, right: rightText, options: options)
                lines[index].leftSegments = leftSegments
                lines[index].rightSegments = rightSegments
            }
        }

        let changeGroups = Self.changeGroups(for: lines)

        return DiffResult(lines: lines, summary: summary, changeGroups: changeGroups, wordDiffDisabled: isLarge)
    }

    private static func changeGroups(for lines: [DiffLine]) -> [ChangeGroup] {
        var groups: [ChangeGroup] = []
        var start: Int?
        for (index, line) in lines.enumerated() {
            if line.kind != .unchanged {
                if start == nil { start = index }
            } else if let groupStart = start {
                groups.append(ChangeGroup(range: groupStart..<index))
                start = nil
            }
        }
        if let groupStart = start {
            groups.append(ChangeGroup(range: groupStart..<lines.count))
        }
        return groups
    }
}
