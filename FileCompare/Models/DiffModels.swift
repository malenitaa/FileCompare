import Foundation

enum DiffLineKind: Equatable {
    case unchanged
    case added
    case removed
    case modified
}

struct DiffSegment: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let changed: Bool
}

struct DiffLine: Identifiable, Equatable {
    let id = UUID()
    let kind: DiffLineKind
    let leftNumber: Int?
    let rightNumber: Int?
    let leftText: String?
    let rightText: String?
    var leftSegments: [DiffSegment]?
    var rightSegments: [DiffSegment]?
}

struct ChangeGroup: Identifiable {
    let id = UUID()
    /// Range of indices into `DiffResult.lines` that make up one contiguous run of changes.
    let range: Range<Int>
}

struct DiffSummary: Equatable {
    var added: Int = 0
    var removed: Int = 0
    var modified: Int = 0

    var hasChanges: Bool { added > 0 || removed > 0 || modified > 0 }
}

struct PanelLineInfo {
    let kind: DiffLineKind
    let segments: [DiffSegment]?

    static let unchanged = PanelLineInfo(kind: .unchanged, segments: nil)
}

struct DiffResult {
    let lines: [DiffLine]
    let summary: DiffSummary
    let changeGroups: [ChangeGroup]
    /// True when the inputs were large enough that word-level highlighting was skipped for performance.
    let wordDiffDisabled: Bool

    static let empty = DiffResult(lines: [], summary: DiffSummary(), changeGroups: [], wordDiffDisabled: false)

    /// Per-line diff info for one panel, indexed by that panel's own line number (0-based).
    /// `count` should be the number of lines currently in that panel's text buffer, so the
    /// array stays index-safe even if the buffer has changed since this result was computed.
    func panelLines(for side: PanelSide, count: Int) -> [PanelLineInfo] {
        var infos = [PanelLineInfo](repeating: .unchanged, count: count)
        for line in lines {
            switch side {
            case .left:
                guard let number = line.leftNumber, number - 1 < count else { continue }
                infos[number - 1] = PanelLineInfo(kind: line.kind, segments: line.leftSegments)
            case .right:
                guard let number = line.rightNumber, number - 1 < count else { continue }
                infos[number - 1] = PanelLineInfo(kind: line.kind, segments: line.rightSegments)
            }
        }
        return infos
    }
}
