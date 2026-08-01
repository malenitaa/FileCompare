import AppKit

/// Draws line numbers in the scroll view's ruler, reading directly from the
/// text view's layout manager so only the currently visible lines are measured.
final class LineNumberRulerView: NSRulerView {
    private weak var codeTextView: NSTextView?
    private var observers: [NSObjectProtocol] = []

    init(textView: NSTextView) {
        self.codeTextView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 44

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSText.didChangeNotification, object: textView, queue: .main) { [weak self] _ in
            self?.needsDisplay = true
        })
        observers.append(center.addObserver(forName: NSView.frameDidChangeNotification, object: textView, queue: .main) { [weak self] _ in
            self?.needsDisplay = true
        })
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = codeTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        NSColor.controlBackgroundColor.setFill()
        rect.fill()

        let visibleRect = textView.enclosingScrollView?.contentView.documentVisibleRect ?? textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let content = textView.string as NSString
        guard content.length > 0 || charRange.location == 0 else { return }

        var lineNumber = content.substring(to: min(charRange.location, content.length)).components(separatedBy: "\n").count
        var index = charRange.location
        let inset = textView.textContainerInset

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        while true {
            let lineRange = content.length == 0 ? NSRange(location: 0, length: 0) : content.lineRange(for: NSRange(location: min(index, content.length), length: 0))
            let glyphRangeForLine = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRangeForLine, in: container)
            lineRect.origin.y += inset.height

            let numberString = "\(lineNumber)" as NSString
            let size = numberString.size(withAttributes: attrs)
            let y = lineRect.origin.y - visibleRect.origin.y
            numberString.draw(
                at: NSPoint(x: ruleThickness - size.width - 8, y: y + (lineRect.height - size.height) / 2),
                withAttributes: attrs
            )

            if content.length == 0 || NSMaxRange(lineRange) >= NSMaxRange(charRange) || NSMaxRange(lineRange) >= content.length {
                break
            }
            lineNumber += 1
            index = NSMaxRange(lineRange)
        }
    }
}
