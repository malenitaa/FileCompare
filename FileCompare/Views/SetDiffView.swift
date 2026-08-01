import SwiftUI
import AppKit

/// Three-column set comparison — "A Only / A ∩ B / B Only" — for comparing
/// two files as unordered lists of items rather than line-by-line (see
/// `SetDiffEngine`). Read-only; each column can be copied to the clipboard.
struct SetDiffView: View {
    let result: SetDiffResult
    let leftTitle: String
    let rightTitle: String

    var body: some View {
        HStack(spacing: 0) {
            column(title: "\(leftTitle) — Solo acá", items: result.onlyLeft, color: .blue)
            Divider()
            column(title: "En ambos", items: result.both, color: .purple)
            Divider()
            column(title: "\(rightTitle) — Solo acá", items: result.onlyRight, color: .red)
        }
    }

    @ViewBuilder
    private func column(title: String, items: [String], color: Color) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                    .lineLimit(1)
                Spacer()
                Text("\(items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    copyToClipboard(items)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copiar lista")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            if items.isEmpty {
                Spacer()
                Text("Vacío")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(items, id: \.self) { item in
                    Text(item)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 200, maxWidth: .infinity)
    }

    private func copyToClipboard(_ items: [String]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(items.joined(separator: "\n"), forType: .string)
    }
}
