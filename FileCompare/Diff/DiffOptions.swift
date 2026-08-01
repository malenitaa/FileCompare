import Foundation

struct DiffOptions: Equatable {
    var ignoreWhitespace: Bool = false
    var ignoreCase: Bool = false

    /// Text removed from every line before comparing (but not from what's
    /// displayed) — e.g. stripping "instagram.com/" so a "seguidores" export
    /// that has bare usernames lines up with a "seguidos" export that has full
    /// profile URLs, instead of every line showing as changed.
    var stripText: String = ""

    /// For "Conjuntos" mode: drop blank lines, bare URLs, and Meta/Instagram-
    /// style timestamps ("Jul 13, 2026 8:33 am") before comparing — needed
    /// because a "following" export and a "followers" export list the same
    /// person's entry with a different number of lines (one has a blank line
    /// + profile URL, the other doesn't), so only the username line is ever
    /// common ground between them.
    var ignoreNoiseLines: Bool = false

    /// Files larger than this (in bytes) or with more lines than `largeFileLineThreshold`
    /// are still diffed at the line level, but word-level highlighting is skipped to keep
    /// the UI responsive.
    var largeFileByteThreshold: Int = 5 * 1024 * 1024
    var largeFileLineThreshold: Int = 50_000
}
