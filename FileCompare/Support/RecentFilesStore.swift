import Foundation

/// Remembers the last two files opened (one per panel) across launches.
enum RecentFilesStore {
    private static let leftKey = "RecentFilesStore.leftPath"
    private static let rightKey = "RecentFilesStore.rightPath"

    static func save(left: URL?, right: URL?) {
        let defaults = UserDefaults.standard
        defaults.set(left?.path, forKey: leftKey)
        defaults.set(right?.path, forKey: rightKey)
    }

    static func load() -> (left: URL?, right: URL?) {
        let defaults = UserDefaults.standard
        let left = (defaults.string(forKey: leftKey)).flatMap(url(from:))
        let right = (defaults.string(forKey: rightKey)).flatMap(url(from:))
        return (left, right)
    }

    private static func url(from path: String) -> URL? {
        FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
    }
}
