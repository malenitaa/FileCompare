import Foundation
import AppKit

@MainActor
final class CompareViewModel: ObservableObject {
    @Published var leftText: String = ""
    @Published var rightText: String = ""
    @Published var leftURL: URL?
    @Published var rightURL: URL?
    @Published var options = DiffOptions()
    @Published private(set) var diffResult: DiffResult = .empty
    @Published private(set) var diffRevision: Int = 0
    @Published private(set) var isComputing = false
    @Published var errorMessage: String?
    @Published var currentChangeIndex: Int = -1
    @Published var scrollRequestLeftLine: Int?
    @Published var scrollRequestRightLine: Int?
    /// Direction the *next* "Ordenar" click will use — it alternates, like a
    /// spreadsheet column-sort arrow, instead of always re-sorting ascending
    /// (which looks like nothing happened on a second click).
    @Published private(set) var isSortAscending = true

    private var debounceTask: Task<Void, Never>?
    private var computeTask: Task<Void, Never>?
    private weak var leftTextView: NSTextView?
    private weak var rightTextView: NSTextView?

    init() {
        let recent = RecentFilesStore.load()
        if let left = recent.left { loadFile(left, into: .left) }
        if let right = recent.right { loadFile(right, into: .right) }
        scheduleDiff(debounce: false)
    }

    var leftLineCount: Int { LineDiffEngine.splitLines(leftText).count }
    var rightLineCount: Int { LineDiffEngine.splitLines(rightText).count }

    func leftPanelLines() -> [PanelLineInfo] { diffResult.panelLines(for: .left, count: leftLineCount) }
    func rightPanelLines() -> [PanelLineInfo] { diffResult.panelLines(for: .right, count: rightLineCount) }

    /// Lets a panel's own `NSTextView` (and its undo manager) register itself,
    /// so that programmatic edits we make here — sort, copy — become undoable
    /// with ⌘Z through the exact same stack as normal typing in that panel.
    func registerTextView(_ textView: NSTextView, for side: PanelSide) {
        switch side {
        case .left: leftTextView = textView
        case .right: rightTextView = textView
        }
    }

    func textDidChange(side: PanelSide) {
        scheduleDiff(debounce: true)
    }

    func toggleIgnoreWhitespace() {
        options.ignoreWhitespace.toggle()
        scheduleDiff(debounce: false)
    }

    func setStripText(_ text: String) {
        options.stripText = text
        scheduleDiff(debounce: true)
    }

    /// Only affects "Conjuntos" mode (see SetDiffEngine) — doesn't touch the
    /// positional line diff, so no need to recompute that.
    func toggleIgnoreNoiseLines() {
        options.ignoreNoiseLines.toggle()
    }

    func toggleIgnoreCase() {
        options.ignoreCase.toggle()
        scheduleDiff(debounce: false)
    }

    /// Sorts both panels' lines, once — not a continuous option, since
    /// re-sorting on every keystroke while someone is mid-edit would keep
    /// yanking their cursor to a different line. Alternates A→Z / Z→A on each
    /// click, like a spreadsheet's sort arrow.
    func sortLines() {
        let oldLeft = leftText
        let oldRight = rightText
        let ascending = isSortAscending
        leftText = Self.sortedText(leftText, ascending: ascending)
        rightText = Self.sortedText(rightText, ascending: ascending)
        isSortAscending.toggle()
        scheduleDiff(debounce: false)
        registerUndo(previousLeft: oldLeft, previousRight: oldRight, actionName: ascending ? "Ordenar A-Z" : "Ordenar Z-A")
        focus(.left)
    }

    private static func sortedText(_ text: String, ascending: Bool) -> String {
        var lines = LineDiffEngine.splitLines(text)
        if lines.last == "" {
            lines.removeLast()
        }
        lines.sort { left, right in
            let order = left.localizedStandardCompare(right)
            return ascending ? order == .orderedAscending : order == .orderedDescending
        }
        return lines.joined(separator: "\n")
    }

    /// Cmd+Z only does anything if a panel's own text view is first responder
    /// (that's whose undo manager we registered with). After a toolbar button
    /// changes text programmatically, focus is usually still on the button,
    /// so ⌘Z right afterwards would silently do nothing — move focus into a
    /// panel so it's immediately undoable.
    private func focus(_ side: PanelSide) {
        let textView = side == .left ? leftTextView : rightTextView
        guard let textView, let window = textView.window else { return }
        window.makeFirstResponder(textView)
    }

    /// Registers ⌘Z support for a programmatic change to one or both panels,
    /// on each affected panel's own text-view undo manager (the same one that
    /// already undoes regular typing there).
    private func registerUndo(previousLeft: String, previousRight: String, actionName: String) {
        if previousLeft != leftText {
            registerLeftUndo(restoringTo: previousLeft, actionName: actionName)
        }
        if previousRight != rightText {
            registerRightUndo(restoringTo: previousRight, actionName: actionName)
        }
    }

    private func registerLeftUndo(restoringTo value: String, actionName: String) {
        guard let undoManager = leftTextView?.undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            let redoValue = target.leftText
            target.leftText = value
            target.scheduleDiff(debounce: false)
            target.registerLeftUndo(restoringTo: redoValue, actionName: actionName)
        }
        undoManager.setActionName(actionName)
    }

    private func registerRightUndo(restoringTo value: String, actionName: String) {
        guard let undoManager = rightTextView?.undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            let redoValue = target.rightText
            target.rightText = value
            target.scheduleDiff(debounce: false)
            target.registerRightUndo(restoringTo: redoValue, actionName: actionName)
        }
        undoManager.setActionName(actionName)
    }

    func scheduleDiff(debounce: Bool) {
        debounceTask?.cancel()
        if debounce {
            debounceTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await self?.recompute()
            }
        } else {
            Task { await recompute() }
        }
    }

    private func recompute() async {
        computeTask?.cancel()
        isComputing = true
        let left = leftText
        let right = rightText
        let opts = options

        let workTask = Task.detached(priority: .userInitiated) { () -> DiffResult in
            DiffEngine.compute(leftText: left, rightText: right, options: opts)
        }
        let applyTask = Task { [weak self] in
            let result = await workTask.value
            guard let self, !Task.isCancelled else { return }
            self.diffResult = result
            self.diffRevision += 1
            self.isComputing = false
            self.currentChangeIndex = -1
        }
        computeTask = applyTask
        await applyTask.value
    }

    // MARK: - File operations

    func openFile(into side: PanelSide) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            loadFile(url, into: side)
            scheduleDiff(debounce: false)
        }
    }

    func loadFile(_ url: URL, into side: PanelSide) {
        if let size = FileLoader.fileSize(at: url), size > 50 * 1024 * 1024 {
            errorMessage = "El archivo supera 50MB; la app puede volverse lenta."
        }
        let text: String
        do {
            text = try FileLoader.readText(from: url)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        switch side {
        case .left:
            leftText = text
            leftURL = url
        case .right:
            rightText = text
            rightURL = url
        }
        persistRecents()
    }

    func handleDrop(url: URL, side: PanelSide) {
        loadFile(url, into: side)
        scheduleDiff(debounce: false)
    }

    func save(side: PanelSide) {
        switch side {
        case .left:
            guard let url = leftURL else { saveAs(side: side); return }
            write(leftText, to: url)
        case .right:
            guard let url = rightURL else { saveAs(side: side); return }
            write(rightText, to: url)
        }
    }

    func saveAs(side: PanelSide) {
        let panel = NSSavePanel()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        switch side {
        case .left:
            write(leftText, to: url)
            leftURL = url
        case .right:
            write(rightText, to: url)
            rightURL = url
        }
        persistRecents()
    }

    private func write(_ text: String, to url: URL) {
        do {
            try FileLoader.write(text, to: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copy(from side: PanelSide) {
        let oldLeft = leftText
        let oldRight = rightText
        switch side {
        case .left: rightText = leftText
        case .right: leftText = rightText
        }
        scheduleDiff(debounce: false)
        registerUndo(previousLeft: oldLeft, previousRight: oldRight, actionName: "Copiar")
        focus(side == .left ? .right : .left)
    }

    private func persistRecents() {
        RecentFilesStore.save(left: leftURL, right: rightURL)
    }

    // MARK: - Change navigation

    func goToNextChange() {
        guard !diffResult.changeGroups.isEmpty else { return }
        currentChangeIndex = (currentChangeIndex + 1) % diffResult.changeGroups.count
        jumpToCurrentChange()
    }

    func goToPreviousChange() {
        guard !diffResult.changeGroups.isEmpty else { return }
        currentChangeIndex = currentChangeIndex <= 0 ? diffResult.changeGroups.count - 1 : currentChangeIndex - 1
        jumpToCurrentChange()
    }

    private func jumpToCurrentChange() {
        guard diffResult.changeGroups.indices.contains(currentChangeIndex) else { return }
        let group = diffResult.changeGroups[currentChangeIndex]
        let firstLine = diffResult.lines[group.range.lowerBound]
        scrollRequestLeftLine = firstLine.leftNumber ?? firstLine.rightNumber
        scrollRequestRightLine = firstLine.rightNumber ?? firstLine.leftNumber
    }
}
