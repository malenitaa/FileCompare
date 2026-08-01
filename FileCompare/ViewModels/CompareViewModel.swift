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

    private var debounceTask: Task<Void, Never>?
    private var computeTask: Task<Void, Never>?

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

    func toggleIgnoreCase() {
        options.ignoreCase.toggle()
        scheduleDiff(debounce: false)
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
        switch side {
        case .left: rightText = leftText
        case .right: leftText = rightText
        }
        scheduleDiff(debounce: false)
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
