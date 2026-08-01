import AppKit

/// Plain NSTextView with one addition: dropping a file onto it loads that
/// file instead of inserting its path as text.
final class CodeTextView: NSTextView {
    var onFileDropped: ((URL) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if containsFileURL(sender) { return .copy }
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if containsFileURL(sender) { return .copy }
        return super.draggingUpdated(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let url = fileURL(from: sender) {
            onFileDropped?(url)
            return true
        }
        return super.performDragOperation(sender)
    }

    private func containsFileURL(_ sender: NSDraggingInfo) -> Bool {
        fileURL(from: sender) != nil
    }

    private func fileURL(from sender: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return nil
        }
        return urls.first
    }
}
