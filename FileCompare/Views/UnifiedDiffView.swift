import SwiftUI
import AppKit

/// Read-only git-style unified diff: one column, "+"/"-" prefixed lines.
/// Line numbers use the same plain-NSTextView gutter trick as `DiffTextView`
/// — see its header comment for why a custom `NSRulerView` isn't used.
struct UnifiedDiffView: NSViewRepresentable {
    var diffResult: DiffResult
    var revision: Int

    private let gutterWidth: CGFloat = 44

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isRichText = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width, .height]

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let gutterTextView = NSTextView()
        gutterTextView.isEditable = false
        gutterTextView.isSelectable = false
        gutterTextView.drawsBackground = true
        gutterTextView.backgroundColor = .controlBackgroundColor
        gutterTextView.textColor = .tertiaryLabelColor
        gutterTextView.font = textView.font
        gutterTextView.textContainerInset = textView.textContainerInset
        gutterTextView.textContainer?.lineFragmentPadding = 0
        gutterTextView.isHorizontallyResizable = false
        gutterTextView.textContainer?.widthTracksTextView = true
        gutterTextView.alignment = .right

        let gutterScroll = NSScrollView()
        gutterScroll.documentView = gutterTextView
        gutterScroll.hasVerticalScroller = false
        gutterScroll.hasHorizontalScroller = false
        gutterScroll.borderType = .noBorder
        gutterScroll.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(gutterScroll)
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            gutterScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gutterScroll.topAnchor.constraint(equalTo: container.topAnchor),
            gutterScroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            gutterScroll.widthAnchor.constraint(equalToConstant: gutterWidth),

            scrollView.leadingAnchor.constraint(equalTo: gutterScroll.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let gutterSync = ScrollSyncCoordinator()
        gutterSync.register(left: gutterScroll)
        gutterSync.register(right: scrollView)
        context.coordinator.gutterSync = gutterSync

        context.coordinator.textView = textView
        context.coordinator.gutterTextView = gutterTextView
        apply(to: textView, gutter: gutterTextView)
        context.coordinator.appliedRevision = revision
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard context.coordinator.appliedRevision != revision,
              let textView = context.coordinator.textView,
              let gutterTextView = context.coordinator.gutterTextView else { return }
        apply(to: textView, gutter: gutterTextView)
        context.coordinator.appliedRevision = revision
    }

    private func apply(to textView: NSTextView, gutter gutterTextView: NSTextView) {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let result = NSMutableAttributedString()
        var rowCount = 0

        for line in diffResult.lines {
            switch line.kind {
            case .unchanged:
                append(marker: "  ", text: line.leftText ?? "", background: nil, font: font, to: result)
                rowCount += 1
            case .added:
                append(marker: "+ ", text: line.rightText ?? "", background: DiffColors.lineBackground(for: .added), font: font, to: result)
                rowCount += 1
            case .removed:
                append(marker: "- ", text: line.leftText ?? "", background: DiffColors.lineBackground(for: .removed), font: font, to: result)
                rowCount += 1
            case .modified:
                rowCount += appendModified(line, font: font, to: result)
            }
        }

        textView.textStorage?.setAttributedString(result)
        let numbers = (1...max(1, rowCount)).map(String.init).joined(separator: "\n")
        if gutterTextView.string != numbers {
            gutterTextView.string = numbers
        }
    }

    private func append(marker: String, text: String, background: NSColor?, font: NSFont, to result: NSMutableAttributedString) {
        let line = NSMutableAttributedString(string: marker + text + "\n", attributes: [.font: font])
        if let background {
            line.addAttribute(.backgroundColor, value: background, range: NSRange(location: 0, length: line.length))
        }
        result.append(line)
    }

    /// Returns how many rows were appended (a modified line renders as two rows).
    private func appendModified(_ line: DiffLine, font: NSFont, to result: NSMutableAttributedString) -> Int {
        let background = DiffColors.lineBackground(for: .modified)
        var rows = 0
        if let leftText = line.leftText {
            let removedLine = NSMutableAttributedString(string: "- " + leftText + "\n", attributes: [.font: font])
            removedLine.addAttribute(.backgroundColor, value: background as Any, range: NSRange(location: 0, length: removedLine.length))
            applySegments(line.leftSegments, markerLength: 2, color: DiffColors.wordBackground(for: .left), to: removedLine)
            result.append(removedLine)
            rows += 1
        }
        if let rightText = line.rightText {
            let addedLine = NSMutableAttributedString(string: "+ " + rightText + "\n", attributes: [.font: font])
            addedLine.addAttribute(.backgroundColor, value: background as Any, range: NSRange(location: 0, length: addedLine.length))
            applySegments(line.rightSegments, markerLength: 2, color: DiffColors.wordBackground(for: .right), to: addedLine)
            result.append(addedLine)
            rows += 1
        }
        return rows
    }

    private func applySegments(_ segments: [DiffSegment]?, markerLength: Int, color: NSColor, to attributed: NSMutableAttributedString) {
        guard let segments else { return }
        var location = markerLength
        for segment in segments {
            let length = (segment.text as NSString).length
            if segment.changed, location + length <= attributed.length {
                attributed.addAttribute(.backgroundColor, value: color, range: NSRange(location: location, length: length))
            }
            location += length
        }
    }

    final class Coordinator {
        weak var textView: NSTextView?
        weak var gutterTextView: NSTextView?
        var gutterSync: ScrollSyncCoordinator?
        var appliedRevision = -1
    }
}
