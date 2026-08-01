import AppKit

/// Keeps two scroll views moving together proportionally (by fraction of
/// scrollable height, not raw pixel offset) since the two files being
/// compared rarely have the same number of lines.
final class ScrollSyncCoordinator {
    private weak var left: NSScrollView?
    private weak var right: NSScrollView?
    private var isSyncing = false
    private var observers: [NSObjectProtocol] = []

    func register(left scrollView: NSScrollView) {
        left = scrollView
        observe(scrollView) { [weak self] in self?.sync(from: .left) }
    }

    func register(right scrollView: NSScrollView) {
        right = scrollView
        observe(scrollView) { [weak self] in self?.sync(from: .right) }
    }

    private func observe(_ scrollView: NSScrollView, _ handler: @escaping () -> Void) {
        scrollView.contentView.postsBoundsChangedNotifications = true
        let observer = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { _ in handler() }
        observers.append(observer)
    }

    private enum Side { case left, right }

    private func sync(from side: Side) {
        guard !isSyncing, let left, let right else { return }
        isSyncing = true
        defer { isSyncing = false }

        switch side {
        case .left:
            let fraction = Self.scrollFraction(of: left)
            Self.apply(fraction: fraction, to: right)
        case .right:
            let fraction = Self.scrollFraction(of: right)
            Self.apply(fraction: fraction, to: left)
        }
    }

    private static func scrollFraction(of scrollView: NSScrollView) -> CGFloat {
        guard let documentView = scrollView.documentView else { return 0 }
        let maxOffset = max(1, documentView.frame.height - scrollView.contentView.bounds.height)
        return max(0, min(1, scrollView.contentView.bounds.origin.y / maxOffset))
    }

    private static func apply(fraction: CGFloat, to scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView else { return }
        let maxOffset = max(0, documentView.frame.height - scrollView.contentView.bounds.height)
        let origin = NSPoint(x: scrollView.contentView.bounds.origin.x, y: fraction * maxOffset)
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
