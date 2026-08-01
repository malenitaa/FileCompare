import SwiftUI
import AppKit

/// Read-only git-style unified diff: one column, "+"/"-" prefixed lines.
struct UnifiedDiffView: NSViewRepresentable {
    var diffResult: DiffResult
    var revision: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isRichText = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        apply(to: textView)
        context.coordinator.appliedRevision = revision
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard context.coordinator.appliedRevision != revision,
              let textView = scrollView.documentView as? NSTextView else { return }
        apply(to: textView)
        context.coordinator.appliedRevision = revision
    }

    private func apply(to textView: NSTextView) {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let result = NSMutableAttributedString()

        for line in diffResult.lines {
            switch line.kind {
            case .unchanged:
                append(marker: "  ", text: line.leftText ?? "", background: nil, font: font, to: result)
            case .added:
                append(marker: "+ ", text: line.rightText ?? "", background: DiffColors.lineBackground(for: .added), font: font, to: result)
            case .removed:
                append(marker: "- ", text: line.leftText ?? "", background: DiffColors.lineBackground(for: .removed), font: font, to: result)
            case .modified:
                appendModified(line, font: font, to: result)
            }
        }

        textView.textStorage?.setAttributedString(result)
    }

    private func append(marker: String, text: String, background: NSColor?, font: NSFont, to result: NSMutableAttributedString) {
        let line = NSMutableAttributedString(string: marker + text + "\n", attributes: [.font: font])
        if let background {
            line.addAttribute(.backgroundColor, value: background, range: NSRange(location: 0, length: line.length))
        }
        result.append(line)
    }

    private func appendModified(_ line: DiffLine, font: NSFont, to result: NSMutableAttributedString) {
        let background = DiffColors.lineBackground(for: .modified)
        if let leftText = line.leftText {
            let removedLine = NSMutableAttributedString(string: "- " + leftText + "\n", attributes: [.font: font])
            removedLine.addAttribute(.backgroundColor, value: background as Any, range: NSRange(location: 0, length: removedLine.length))
            applySegments(line.leftSegments, markerLength: 2, color: DiffColors.wordBackground(for: .left), to: removedLine)
            result.append(removedLine)
        }
        if let rightText = line.rightText {
            let addedLine = NSMutableAttributedString(string: "+ " + rightText + "\n", attributes: [.font: font])
            addedLine.addAttribute(.backgroundColor, value: background as Any, range: NSRange(location: 0, length: addedLine.length))
            applySegments(line.rightSegments, markerLength: 2, color: DiffColors.wordBackground(for: .right), to: addedLine)
            result.append(addedLine)
        }
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
        var appliedRevision = -1
    }
}
