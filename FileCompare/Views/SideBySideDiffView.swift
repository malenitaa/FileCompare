import SwiftUI

struct SideBySideDiffView: View {
    @ObservedObject var viewModel: CompareViewModel
    var t: Strings
    @State private var syncCoordinator = ScrollSyncCoordinator()

    var body: some View {
        HSplitView {
            panel(
                side: .left,
                title: viewModel.leftURL?.lastPathComponent ?? t.leftPanel,
                text: $viewModel.leftText,
                scrollLine: $viewModel.scrollRequestLeftLine
            )
            panel(
                side: .right,
                title: viewModel.rightURL?.lastPathComponent ?? t.rightPanel,
                text: $viewModel.rightText,
                scrollLine: $viewModel.scrollRequestRightLine
            )
        }
        // Keeps the cross-panel scroll sync mapping current with the latest
        // diff — see ScrollSyncCoordinator's line-based mapping.
        .onChange(of: viewModel.diffRevision) { _ in updateSyncAnchors() }
        .onAppear { updateSyncAnchors() }
    }

    private func updateSyncAnchors() {
        syncCoordinator.anchors = viewModel.diffResult.lines.compactMap { line in
            guard let left = line.leftNumber, let right = line.rightNumber else { return nil }
            return (left: left, right: right)
        }
    }

    @ViewBuilder
    private func panel(side: PanelSide, title: String, text: Binding<String>, scrollLine: Binding<Int?>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if viewModel.loadingSides.contains(side) {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button {
                    viewModel.openFile(into: side)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help(t.openFileHelp)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.bar)

            Divider()

            ZStack {
                DiffTextView(
                    text: text,
                    panelLines: side == .left ? viewModel.leftPanelLines() : viewModel.rightPanelLines(),
                    revision: viewModel.diffRevision,
                    side: side,
                    isEditable: true,
                    syncCoordinator: syncCoordinator,
                    onFileDropped: { url in viewModel.handleDrop(url: url, side: side) },
                    onTextViewReady: { textView in viewModel.registerTextView(textView, for: side) },
                    scrollRequestLine: scrollLine,
                    sharedUndoManager: viewModel.sharedUndoManager
                )
                .onChange(of: text.wrappedValue) { _ in
                    viewModel.textDidChange(side: side)
                }

                if text.wrappedValue.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                        Text(t.dropHint)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 260)
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(minWidth: 320)
    }
}
