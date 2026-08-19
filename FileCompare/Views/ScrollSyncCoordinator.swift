import AppKit

/// Keeps two scroll views moving together by *equivalent line*, not by
/// fraction of scrollable height. A fraction-based sync drifts out of
/// alignment as soon as the two files have a different number of inserted or
/// removed lines above the current scroll position — e.g. a block inserted
/// near the top of the left file shifts everything below it out of sync with
/// the right file, even though most of the content past that point is
/// identical. Mapping through `anchors` (line pairs that exist on both
/// sides, from `DiffResult`) keeps unchanged/matched regions aligned exactly,
/// and interpolates linearly across the (usually short) unmatched regions
/// in between.
///
/// When `anchors` is empty (no diff computed yet, or this instance is used to
/// sync a gutter to its own code view — see `DiffTextView`, where line counts
/// are always identical 1:1 by construction), line mapping falls back to the
/// identity function, which is exactly correct for that 1:1 case.
final class ScrollSyncCoordinator {
    private weak var leftScrollView: NSScrollView?
    private weak var rightScrollView: NSScrollView?
    private weak var leftTextView: NSTextView?
    private weak var rightTextView: NSTextView?
    private var isSyncing = false
    private var observers: [NSObjectProtocol] = []

    /// (leftLine, rightLine) 1-based pairs, in ascending order, for every diff
    /// line present on both sides (`.unchanged` or `.modified` — `.added`/
    /// `.removed` lines only exist on one side and aren't valid anchors).
    var anchors: [(left: Int, right: Int)] = [] {
        didSet { anchors.sort { $0.left < $1.left } }
    }

    func register(left scrollView: NSScrollView) {
        leftScrollView = scrollView
        leftTextView = scrollView.documentView as? NSTextView
        observe(scrollView) { [weak self] in self?.sync(from: .left) }
    }

    func register(right scrollView: NSScrollView) {
        rightScrollView = scrollView
        rightTextView = scrollView.documentView as? NSTextView
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

    enum Side { case left, right }

    private func sync(from side: Side) {
        guard !isSyncing,
              let leftScrollView, let rightScrollView,
              let leftTextView, let rightTextView else { return }
        isSyncing = true
        defer { isSyncing = false }

        switch side {
        case .left:
            let line = Self.visibleLine(in: leftScrollView, textView: leftTextView)
            let mapped = Self.mappedLine(line, from: .left, anchors: anchors)
            Self.scroll(rightScrollView, textView: rightTextView, toLine: mapped)
        case .right:
            let line = Self.visibleLine(in: rightScrollView, textView: rightTextView)
            let mapped = Self.mappedLine(line, from: .right, anchors: anchors)
            Self.scroll(leftScrollView, textView: leftTextView, toLine: mapped)
        }
    }

    /// Maps a (possibly fractional) 1-based line position on `side` to the
    /// equivalent position on the other side, via the nearest anchor at or
    /// before `line` (or the first anchor, if `line` precedes every anchor),
    /// preserving the offset from that anchor. With no anchors, returns
    /// `line` unchanged (identity mapping).
    static func mappedLine(_ line: Double, from side: Side, anchors: [(left: Int, right: Int)]) -> Double {
        guard !anchors.isEmpty else { return line }

        var low = 0
        var high = anchors.count - 1
        var candidate = 0
        while low <= high {
            let mid = (low + high) / 2
            let midValue = side == .left ? anchors[mid].left : anchors[mid].right
            if Double(midValue) <= line {
                candidate = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        let anchor = anchors[candidate]
        let anchorSideValue = Double(side == .left ? anchor.left : anchor.right)
        let anchorOtherValue = Double(side == .left ? anchor.right : anchor.left)
        return anchorOtherValue + (line - anchorSideValue)
    }

    private static func lineHeight(for textView: NSTextView) -> Double {
        let font = textView.font ?? .systemFont(ofSize: 12)
        let height = textView.layoutManager?.defaultLineHeight(for: font) ?? font.boundingRectForFont.height
        return max(1, Double(height))
    }

    private static func visibleLine(in scrollView: NSScrollView, textView: NSTextView) -> Double {
        let topInset = Double(textView.textContainerInset.height)
        let offsetY = Double(scrollView.contentView.bounds.origin.y)
        return max(0, (offsetY - topInset) / lineHeight(for: textView)) + 1
    }

    private static func scroll(_ scrollView: NSScrollView, textView: NSTextView, toLine line: Double) {
        guard let documentView = scrollView.documentView else { return }
        let topInset = Double(textView.textContainerInset.height)
        let maxOffset = max(0, Double(documentView.frame.height - scrollView.contentView.bounds.height))
        let rawY = topInset + (line - 1) * lineHeight(for: textView)
        let clampedY = min(max(0, rawY), maxOffset)
        let origin = NSPoint(x: scrollView.contentView.bounds.origin.x, y: CGFloat(clampedY))
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
