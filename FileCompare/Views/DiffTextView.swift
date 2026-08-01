import SwiftUI
import AppKit

/// One editable panel: an `NSTextView` with a line-number ruler and diff
/// background coloring painted on top via text-storage attributes.
struct DiffTextView: NSViewRepresentable {
    @Binding var text: String
    var panelLines: [PanelLineInfo]
    var revision: Int
    var side: PanelSide
    var isEditable: Bool
    var syncCoordinator: ScrollSyncCoordinator
    var onFileDropped: (URL) -> Void
    @Binding var scrollRequestLine: Int?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = CodeTextView()
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.string = text
        textView.onFileDropped = onFileDropped
        textView.registerForDraggedTypes(textView.registeredDraggedTypes + [.fileURL])
        textView.allowsUndo = true

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        switch side {
        case .left: syncCoordinator.register(left: scrollView)
        case .right: syncCoordinator.register(right: scrollView)
        }

        context.coordinator.textView = textView
        applyDiffAttributes(to: textView)
        context.coordinator.appliedRevision = revision
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let ranges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = ranges
        }
        textView.isEditable = isEditable

        if context.coordinator.appliedRevision != revision {
            applyDiffAttributes(to: textView)
            context.coordinator.appliedRevision = revision
        }

        if let line = scrollRequestLine {
            scrollToLine(line, in: textView)
            DispatchQueue.main.async { scrollRequestLine = nil }
        }
    }

    private func scrollToLine(_ lineNumber: Int, in textView: NSTextView) {
        guard let layoutManager = textView.layoutManager, let container = textView.textContainer else { return }
        let content = textView.string as NSString
        var index = 0
        var currentLine = 1
        while currentLine < lineNumber, index < content.length {
            let lineRange = content.lineRange(for: NSRange(location: index, length: 0))
            index = NSMaxRange(lineRange)
            currentLine += 1
            if lineRange.length == 0 { break }
        }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: min(index, content.length), length: 0), actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: container)
        textView.scrollToVisible(rect.insetBy(dx: 0, dy: -80))
    }

    private func applyDiffAttributes(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.removeAttribute(.backgroundColor, range: fullRange)

        let nsString = storage.string as NSString
        if nsString.length == 0 {
            storage.endEditing()
            return
        }

        var searchLocation = 0
        var lineIndex = 0

        while searchLocation <= nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: searchLocation, length: 0))
            guard lineIndex < panelLines.count else { break }
            let info = panelLines[lineIndex]

            if let lineColor = DiffColors.lineBackground(for: info.kind) {
                storage.addAttribute(.backgroundColor, value: lineColor, range: lineRange)
            }

            if info.kind == .modified, let segments = info.segments {
                var segmentLocation = lineRange.location
                let lineEnd = NSMaxRange(lineRange)
                for segment in segments {
                    let length = (segment.text as NSString).length
                    let clampedLength = max(0, min(length, lineEnd - segmentLocation))
                    if segment.changed, clampedLength > 0 {
                        storage.addAttribute(
                            .backgroundColor,
                            value: DiffColors.wordBackground(for: side),
                            range: NSRange(location: segmentLocation, length: clampedLength)
                        )
                    }
                    segmentLocation += length
                }
            }

            lineIndex += 1
            if lineRange.length == 0 { break }
            searchLocation = NSMaxRange(lineRange)
        }

        storage.endEditing()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DiffTextView
        weak var textView: NSTextView?
        var appliedRevision = -1

        init(_ parent: DiffTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
