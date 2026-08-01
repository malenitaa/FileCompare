import Foundation

struct DiffOptions: Equatable {
    var ignoreWhitespace: Bool = false
    var ignoreCase: Bool = false

    /// Files larger than this (in bytes) or with more lines than `largeFileLineThreshold`
    /// are still diffed at the line level, but word-level highlighting is skipped to keep
    /// the UI responsive.
    var largeFileByteThreshold: Int = 5 * 1024 * 1024
    var largeFileLineThreshold: Int = 50_000
}
