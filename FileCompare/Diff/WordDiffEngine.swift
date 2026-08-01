import Foundation

/// Intra-line (word/character-run) diff, run only on lines the line-level pass
/// already marked as `.modified` — never on the whole file — so its cost stays
/// proportional to the size of the change, not the size of the document.
enum WordDiffEngine {
    static func diffSegments(left: String, right: String, options: DiffOptions) -> (left: [DiffSegment], right: [DiffSegment]) {
        let leftTokens = tokenize(left)
        let rightTokens = tokenize(right)

        let leftKeys = leftTokens.map { TokenKey(token: $0, options: options) }
        let rightKeys = rightTokens.map { TokenKey(token: $0, options: options) }
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

        let leftSegments = merge(tokens: leftTokens, changed: removedOffsets)
        let rightSegments = merge(tokens: rightTokens, changed: insertedOffsets)
        return (leftSegments, rightSegments)
    }

    /// Splits a line into whitespace runs, word runs (letters/digits/underscore),
    /// and individual punctuation characters, preserving every character in order.
    static func tokenize(_ line: String) -> [String] {
        guard !line.isEmpty else { return [] }
        var tokens: [String] = []
        var current = ""
        var currentKind: TokenClass?

        func flush() {
            if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }

        for char in line {
            let kind = TokenClass(of: char)
            if kind == .word, currentKind == .word {
                current.append(char)
            } else if kind == .whitespace, currentKind == .whitespace {
                current.append(char)
            } else {
                flush()
                current.append(char)
                currentKind = kind
            }
        }
        flush()
        return tokens
    }

    private enum TokenClass: Equatable {
        case word
        case whitespace
        case other

        init(of char: Character) {
            if char.isWhitespace {
                self = .whitespace
            } else if char.isLetter || char.isNumber || char == "_" {
                self = .word
            } else {
                self = .other
            }
        }
    }

    private static func merge(tokens: [String], changed: Set<Int>) -> [DiffSegment] {
        var segments: [DiffSegment] = []
        var currentText = ""
        var currentChanged: Bool?

        for (index, token) in tokens.enumerated() {
            let isChanged = changed.contains(index)
            if currentChanged == isChanged {
                currentText += token
            } else {
                if let currentChanged {
                    segments.append(DiffSegment(text: currentText, changed: currentChanged))
                }
                currentText = token
                currentChanged = isChanged
            }
        }
        if let currentChanged {
            segments.append(DiffSegment(text: currentText, changed: currentChanged))
        }
        return segments
    }
}

private struct TokenKey: Equatable {
    let key: String

    init(token: String, options: DiffOptions) {
        key = options.ignoreCase ? token.lowercased() : token
    }
}
