import Foundation

/// Orchestrates the two-pass diff: line-level first, then word-level only on
/// lines marked `.modified`. Safe to call off the main thread — `CompareViewModel`
/// always runs this in a background `Task`.
enum DiffEngine {
    /// Throws `CancellationError` (via `Task.checkCancellation()`) as soon as
    /// the enclosing task is cancelled, checked between phases and, for the
    /// per-line word-diff pass, on every iteration — so a superseded compute
    /// (e.g. the user toggled two options in a row on a large pair of files)
    /// stops doing work almost immediately instead of running to completion
    /// only to have its result discarded. Outside of a `Task` context (e.g.
    /// called directly from a test) `Task.checkCancellation()` is a no-op.
    ///
    /// One exception: `LineDiffEngine.diff`'s call into the standard library's
    /// `CollectionDifference.difference(from:)` is a single atomic call and
    /// can't be interrupted mid-way — for two large, mostly-disjoint files
    /// that call is an unavoidable cost floor no cancellation check can skip.
    static func compute(leftText: String, rightText: String, options: DiffOptions) throws -> DiffResult {
        try Task.checkCancellation()
        let leftLines = LineDiffEngine.splitLines(leftText)
        let rightLines = LineDiffEngine.splitLines(rightText)

        let isLarge = leftText.utf8.count > options.largeFileByteThreshold
            || rightText.utf8.count > options.largeFileByteThreshold
            || leftLines.count > options.largeFileLineThreshold
            || rightLines.count > options.largeFileLineThreshold

        try Task.checkCancellation()
        var (lines, summary) = LineDiffEngine.diff(left: leftLines, right: rightLines, options: options)
        try Task.checkCancellation()

        if !isLarge {
            for index in lines.indices where lines[index].kind == .modified {
                try Task.checkCancellation()
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
