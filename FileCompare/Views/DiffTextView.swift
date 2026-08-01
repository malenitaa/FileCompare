import SwiftUI
import AppKit

/// One editable code panel: a line-number gutter (a second, plain read-only
/// `NSTextView`, kept in scroll-sync) next to the main editable `NSTextView`,
/// with diff background coloring painted via text-storage attributes.
///
/// Line numbers are deliberately NOT drawn via a custom `NSRulerView`. On this
/// AppKit version, overriding `NSRulerView.drawHashMarksAndLabels` with
/// anything beyond an empty body corrupts the *sibling* code view's own
/// rendering — its glyphs stop painting entirely, even though layout
/// geometry inspected via the debugger looks completely valid. A second,
/// ordinary `NSTextView` showing "1\n2\n3…" sidesteps that: plain NSTextViews
/// are proven to render fine here. Word wrap is disabled on the code view so
/// one logical line always equals one visual row, keeping the two views in
/// lockstep (long lines scroll horizontally instead).
struct DiffTextView: NSViewRepresentable {
    @Binding var text: String
    var panelLines: [PanelLineInfo]
    var revision: Int
    var side: PanelSide
    var isEditable: Bool
    var syncCoordinator: ScrollSyncCoordinator
    var onFileDropped: (URL) -> Void
    var onTextViewReady: (NSTextView) -> Void = { _ in }
    @Binding var scrollRequestLine: Int?

    private let gutterWidth: CGFloat = 44

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSView {
        let codeTextView = CodeTextView()
        codeTextView.delegate = context.coordinator
        codeTextView.isEditable = isEditable
        codeTextView.isRichText = false
        codeTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        codeTextView.isAutomaticQuoteSubstitutionEnabled = false
        codeTextView.isAutomaticDashSubstitutionEnabled = false
        codeTextView.isAutomaticTextReplacementEnabled = false
        codeTextView.isAutomaticSpellingCorrectionEnabled = false
        codeTextView.isAutomaticDataDetectionEnabled = false
        codeTextView.textContainerInset = NSSize(width: 4, height: 6)
        codeTextView.isHorizontallyResizable = true
        codeTextView.isVerticallyResizable = true
        codeTextView.textContainer?.widthTracksTextView = false
        codeTextView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        codeTextView.autoresizingMask = [.width, .height]
        codeTextView.string = text
        codeTextView.onFileDropped = onFileDropped
        codeTextView.registerForDraggedTypes(codeTextView.registeredDraggedTypes + [.fileURL])
        codeTextView.allowsUndo = true

        let codeScroll = NSScrollView()
        codeScroll.documentView = codeTextView
        codeScroll.hasVerticalScroller = true
        codeScroll.hasHorizontalScroller = true
        codeScroll.autohidesScrollers = true
        codeScroll.borderType = .noBorder
        codeScroll.translatesAutoresizingMaskIntoConstraints = false

        let gutterTextView = NSTextView()
        gutterTextView.isEditable = false
        gutterTextView.isSelectable = false
        gutterTextView.drawsBackground = true
        gutterTextView.backgroundColor = .controlBackgroundColor
        gutterTextView.textColor = .tertiaryLabelColor
        gutterTextView.font = codeTextView.font
        gutterTextView.textContainerInset = codeTextView.textContainerInset
        gutterTextView.textContainer?.lineFragmentPadding = 0
        gutterTextView.isHorizontallyResizable = false
        gutterTextView.textContainer?.widthTracksTextView = true
        gutterTextView.alignment = .right
        gutterTextView.string = Self.numbersString(for: panelLines.count)

        let gutterScroll = NSScrollView()
        gutterScroll.documentView = gutterTextView
        gutterScroll.hasVerticalScroller = false
        gutterScroll.hasHorizontalScroller = false
        gutterScroll.borderType = .noBorder
        gutterScroll.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(gutterScroll)
        container.addSubview(codeScroll)
        NSLayoutConstraint.activate([
            gutterScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gutterScroll.topAnchor.constraint(equalTo: container.topAnchor),
            gutterScroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            gutterScroll.widthAnchor.constraint(equalToConstant: gutterWidth),

            codeScroll.leadingAnchor.constraint(equalTo: gutterScroll.trailingAnchor),
            codeScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            codeScroll.topAnchor.constraint(equalTo: container.topAnchor),
            codeScroll.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Gutter and code always have the same line count and line height
        // (no wrap), so the existing fraction-based sync lands pixel-exact.
        let gutterSync = ScrollSyncCoordinator()
        gutterSync.register(left: gutterScroll)
        gutterSync.register(right: codeScroll)

        switch side {
        case .left: syncCoordinator.register(left: codeScroll)
        case .right: syncCoordinator.register(right: codeScroll)
        }

        context.coordinator.codeTextView = codeTextView
        context.coordinator.gutterTextView = gutterTextView
        context.coordinator.gutterSync = gutterSync
        applyDiffAttributes(to: codeTextView)
        context.coordinator.appliedRevision = revision
        onTextViewReady(codeTextView)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let textView = context.coordinator.codeTextView,
              let gutterTextView = context.coordinator.gutterTextView else { return }

        if textView.string != text {
            let ranges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = ranges
        }
        textView.isEditable = isEditable

        let numbers = Self.numbersString(for: panelLines.count)
        if gutterTextView.string != numbers {
            gutterTextView.string = numbers
        }

        if context.coordinator.appliedRevision != revision {
            applyDiffAttributes(to: textView)
            context.coordinator.appliedRevision = revision
        }

        if let line = scrollRequestLine {
            scrollToLine(line, in: textView)
            DispatchQueue.main.async { scrollRequestLine = nil }
        }
    }

    private static func numbersString(for count: Int) -> String {
        guard count > 0 else { return "1" }
        return (1...count).map(String.init).joined(separator: "\n")
    }

    private func scrollToLine(_ lineNumber: Int, in textView: NSTextView) {
        let content = textView.string as NSString
        var index = 0
        var currentLine = 1
        while currentLine < lineNumber, index < content.length {
            let lineRange = content.lineRange(for: NSRange(location: index, length: 0))
            index = NSMaxRange(lineRange)
            currentLine += 1
            if lineRange.length == 0 { break }
        }
        textView.scrollRangeToVisible(NSRange(location: min(index, content.length), length: 0))
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
        weak var codeTextView: NSTextView?
        weak var gutterTextView: NSTextView?
        var gutterSync: ScrollSyncCoordinator?
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
