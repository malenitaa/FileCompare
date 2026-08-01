import Foundation

/// Line-level diff built on Swift's standard-library `CollectionDifference`
/// (`difference(from:)`), which implements Myers' algorithm with Heckel-style
/// move detection in O(n·d) time, where d is the number of differing elements.
/// See DiffEngine.swift / README for the full rationale.
enum LineDiffEngine {
    static func diff(left: [String], right: [String], options: DiffOptions) -> (lines: [DiffLine], summary: DiffSummary) {
        let leftKeys = left.map { ComparableLine(line: $0, options: options) }
        let rightKeys = right.map { ComparableLine(line: $0, options: options) }
        let difference = rightKeys.difference(from: leftKeys)

        var removedOffsets = Set<Int>()
        var insertedOffsets = Set<Int>()
        for change in difference {
            switch change {
            case .remove(let offset, _, _):
                removedOffsets.insert(offset)
            case .insert(let offset, _, _):
                insertedOffsets.insert(offset)
            }
        }

        var lines: [DiffLine] = []
        lines.reserveCapacity(max(left.count, right.count))
        var summary = DiffSummary()
        var oldIndex = 0
        var newIndex = 0

        while oldIndex < left.count || newIndex < right.count {
            let isRemoved = oldIndex < left.count && removedOffsets.contains(oldIndex)
            let isInserted = newIndex < right.count && insertedOffsets.contains(newIndex)

            if isRemoved && isInserted {
                lines.append(DiffLine(
                    kind: .modified,
                    leftNumber: oldIndex + 1,
                    rightNumber: newIndex + 1,
                    leftText: left[oldIndex],
                    rightText: right[newIndex]
                ))
                summary.modified += 1
                oldIndex += 1
                newIndex += 1
            } else if isRemoved {
                lines.append(DiffLine(
                    kind: .removed,
                    leftNumber: oldIndex + 1,
                    rightNumber: nil,
                    leftText: left[oldIndex],
                    rightText: nil
                ))
                summary.removed += 1
                oldIndex += 1
            } else if isInserted {
                lines.append(DiffLine(
                    kind: .added,
                    leftNumber: nil,
                    rightNumber: newIndex + 1,
                    leftText: nil,
                    rightText: right[newIndex]
                ))
                summary.added += 1
                newIndex += 1
            } else {
                lines.append(DiffLine(
                    kind: .unchanged,
                    leftNumber: oldIndex + 1,
                    rightNumber: newIndex + 1,
                    leftText: left[oldIndex],
                    rightText: right[newIndex]
                ))
                oldIndex += 1
                newIndex += 1
            }
        }

        return (lines, summary)
    }

    /// Splits raw file text into lines for comparison, tolerating both "\n" and "\r\n".
    static func splitLines(_ text: String) -> [String] {
        if text.isEmpty { return [] }
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.hasSuffix("\r") ? String($0.dropLast()) : String($0) }
    }
}

private struct ComparableLine: Equatable {
    let key: String

    init(line: String, options: DiffOptions) {
        var k = line
        if options.ignoreCase {
            k = k.lowercased()
        }
        if options.ignoreWhitespace {
            k = k.trimmingCharacters(in: .whitespaces)
            while k.contains("\t") {
                k = k.replacingOccurrences(of: "\t", with: " ")
            }
            while k.contains("  ") {
                k = k.replacingOccurrences(of: "  ", with: " ")
            }
        }
        key = k
    }
}
