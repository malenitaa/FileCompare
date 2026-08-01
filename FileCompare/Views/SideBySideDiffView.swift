import SwiftUI

struct SideBySideDiffView: View {
    @ObservedObject var viewModel: CompareViewModel
    @State private var syncCoordinator = ScrollSyncCoordinator()

    var body: some View {
        HSplitView {
            panel(
                side: .left,
                title: viewModel.leftURL?.lastPathComponent ?? "Panel izquierdo",
                text: $viewModel.leftText,
                scrollLine: $viewModel.scrollRequestLeftLine
            )
            panel(
                side: .right,
                title: viewModel.rightURL?.lastPathComponent ?? "Panel derecho",
                text: $viewModel.rightText,
                scrollLine: $viewModel.scrollRequestRightLine
            )
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
                Spacer()
                Button {
                    viewModel.openFile(into: side)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("Abrir archivo…")
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
                    scrollRequestLine: scrollLine
                )
                .onChange(of: text.wrappedValue) { _ in
                    viewModel.textDidChange(side: side)
                }

                if text.wrappedValue.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                        Text("Arrastrá un archivo, usá el botón de carpeta o pegá texto acá")
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
