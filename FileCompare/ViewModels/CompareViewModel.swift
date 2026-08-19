import Foundation
import AppKit

/// User-visible errors as cases (not strings), so the banner text can follow
/// the in-app language selector instead of freezing whatever language was
/// active when the error happened.
enum CompareError: Equatable {
    case fileOver50MB
    case notText
    case system(String)

    func message(_ t: Strings) -> String {
        switch self {
        case .fileOver50MB: return t.fileOver50MB
        case .notText: return t.notTextError
        case .system(let description): return description
        }
    }
}

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
    @Published var activeError: CompareError?
    @Published var currentChangeIndex: Int = -1
    @Published var scrollRequestLeftLine: Int?
    @Published var scrollRequestRightLine: Int?
    /// Direction the *next* "Ordenar" click will use — it alternates, like a
    /// spreadsheet column-sort arrow, instead of always re-sorting ascending
    /// (which looks like nothing happened on a second click).
    @Published private(set) var isSortAscending = true

    /// One shared manager for both panels (handed to each `NSTextView` via
    /// `NSTextViewDelegate.undoManager(for:)`, see DiffTextView.Coordinator),
    /// instead of letting each `NSTextView` keep its own private undo stack.
    /// Operations like "Ordenar", which edit both panels in one call, need a
    /// single ⌘Z to undo both sides atomically — two independent per-panel
    /// managers left the panel that didn't have focus stuck in its new state.
    let sharedUndoManager = UndoManager()

    private var debounceTask: Task<Void, Never>?
    private var computeTask: Task<Void, Never>?
    /// The actual background compute, tracked separately from `computeTask`
    /// (the thin wrapper that awaits it) so it can be cancelled directly —
    /// see the comment in `recompute()`.
    private var workTask: Task<DiffResult?, Never>?
    private weak var leftTextView: NSTextView?
    private weak var rightTextView: NSTextView?

    init() {
        // Reads the last-opened files off the main actor: `loadFile(_:into:)`
        // (used by the open panel / drag-and-drop, where a brief synchronous
        // read alongside an already-modal or already-in-flight user action is
        // unnoticeable) does its disk read inline. Doing that inline here too
        // would block window creation itself on disk I/O whenever the last
        // panel remembered a large file.
        let recent = RecentFilesStore.load()
        Task { [weak self] in
            if let left = recent.left { await self?.loadFileOffMainActor(left, into: .left) }
            guard let self, !Task.isCancelled else { return }
            if let right = recent.right { await self.loadFileOffMainActor(right, into: .right) }
            guard !Task.isCancelled else { return }
            self.scheduleDiff(debounce: false)
        }
    }

    private func loadFileOffMainActor(_ url: URL, into side: PanelSide) async {
        if let size = FileLoader.fileSize(at: url), size > 50 * 1024 * 1024 {
            activeError = .fileOver50MB
        }
        let result = await Task.detached(priority: .userInitiated) { () -> Result<String, Error> in
            Result { try FileLoader.readText(from: url) }
        }.value
        applyLoadResult(result, url: url, side: side)
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
        registerUndo(previousLeft: oldLeft, previousRight: oldRight, actionName: ascending ? L10n.shared.t.undoSortAsc : L10n.shared.t.undoSortDesc)
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
    /// as a single atomic entry on `sharedUndoManager` — one undo restores
    /// both `leftText` and `rightText` together, so "Ordenar" (which sorts
    /// both panels in one call) can't be half-undone.
    private func registerUndo(previousLeft: String, previousRight: String, actionName: String) {
        guard previousLeft != leftText || previousRight != rightText else { return }
        sharedUndoManager.registerUndo(withTarget: self) { target in
            let redoLeft = target.leftText
            let redoRight = target.rightText
            target.leftText = previousLeft
            target.rightText = previousRight
            target.scheduleDiff(debounce: false)
            target.registerUndo(previousLeft: redoLeft, previousRight: redoRight, actionName: actionName)
        }
        sharedUndoManager.setActionName(actionName)
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
        // Cancelling `computeTask` alone used to leave the actual work running:
        // it only cancelled the thin wrapper awaiting `workTask.value`, never
        // `workTask` itself — so toggling an option twice in a row on a large
        // file queued up multiple full-cost background computes that all ran
        // to completion, wasting CPU on results that were about to be thrown
        // away anyway. Cancelling `workTask` directly lets `DiffEngine.compute`'s
        // own `Task.checkCancellation()` checks bail out early instead.
        workTask?.cancel()
        computeTask?.cancel()
        isComputing = true
        let left = leftText
        let right = rightText
        let opts = options

        let newWorkTask = Task.detached(priority: .userInitiated) { () -> DiffResult? in
            try? DiffEngine.compute(leftText: left, rightText: right, options: opts)
        }
        workTask = newWorkTask
        let applyTask = Task { [weak self] in
            guard let result = await newWorkTask.value else { return }
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
            activeError = .fileOver50MB
        }
        let result = Result { try FileLoader.readText(from: url) }
        applyLoadResult(result, url: url, side: side)
    }

    private func applyLoadResult(_ result: Result<String, Error>, url: URL, side: PanelSide) {
        let text: String
        switch result {
        case .success(let value):
            text = value
        case .failure(let error):
            activeError = (error as? FileLoaderError) == .notText ? .notText : .system(error.localizedDescription)
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
            activeError = .system(error.localizedDescription)
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
        registerUndo(previousLeft: oldLeft, previousRight: oldRight, actionName: L10n.shared.t.undoCopy)
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
