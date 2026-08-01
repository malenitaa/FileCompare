import SwiftUI

enum DiffViewMode: String, CaseIterable, Identifiable {
    case sideBySide = "Lado a lado"
    case unified = "Unificado"
    case sets = "Conjuntos"
    var id: String { rawValue }
}

struct ContentView: View {
    @StateObject private var viewModel = CompareViewModel()
    @State private var mode: DiffViewMode = .sideBySide

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.diffResult.wordDiffDisabled {
                largeFileBanner
            }
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            Group {
                switch mode {
                case .sideBySide:
                    SideBySideDiffView(viewModel: viewModel)
                case .unified:
                    UnifiedDiffView(diffResult: viewModel.diffResult, revision: viewModel.diffRevision)
                case .sets:
                    SetDiffView(
                        result: SetDiffEngine.compute(leftText: viewModel.leftText, rightText: viewModel.rightText, options: viewModel.options),
                        leftTitle: viewModel.leftURL?.lastPathComponent ?? "Izquierda",
                        rightTitle: viewModel.rightURL?.lastPathComponent ?? "Derecha"
                    )
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Picker("Vista", selection: $mode) {
                    ForEach(DiffViewMode.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

                Toggle("Ignorar espacios", isOn: Binding(
                    get: { viewModel.options.ignoreWhitespace },
                    set: { _ in viewModel.toggleIgnoreWhitespace() }
                ))
                Toggle("Ignorar mayúsc/minúsc", isOn: Binding(
                    get: { viewModel.options.ignoreCase },
                    set: { _ in viewModel.toggleIgnoreCase() }
                ))

                if mode == .sets {
                    Toggle("Ignorar URLs/fechas/vacíos", isOn: Binding(
                        get: { viewModel.options.ignoreNoiseLines },
                        set: { _ in viewModel.toggleIgnoreNoiseLines() }
                    ))
                    .help("Para exportaciones tipo Instagram donde cada entrada tiene distinta cantidad de líneas (URL, fecha) — sólo importa el nombre de usuario.")
                }

                TextField("Quitar texto antes de comparar…", text: Binding(
                    get: { viewModel.options.stripText },
                    set: { viewModel.setStripText($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .help("Texto que se elimina de cada línea sólo para compararla (ej: \"instagram.com/\"), sin tocar lo que se muestra.")

                Button { viewModel.sortLines() } label: {
                    Image(systemName: viewModel.isSortAscending ? "arrow.up" : "arrow.down")
                }
                .accessibilityLabel("Ordenar")
                .help(viewModel.isSortAscending ? "Ordenar de A a Z / menor a mayor" : "Ordenar de Z a A / mayor a menor")

                Button { viewModel.goToPreviousChange() } label: {
                    Image(systemName: "chevron.up")
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .help("Cambio anterior (⌘↑)")

                Button { viewModel.goToNextChange() } label: {
                    Image(systemName: "chevron.down")
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .help("Siguiente cambio (⌘↓)")

                summaryView

                Button { viewModel.copy(from: .left) } label: {
                    Image(systemName: "arrow.right")
                }
                .help("Copiar izquierda → derecha")

                Button { viewModel.copy(from: .right) } label: {
                    Image(systemName: "arrow.left")
                }
                .help("Copiar derecha → izquierda")

                Menu {
                    Button("Guardar panel izquierdo") { viewModel.save(side: .left) }
                    Button("Guardar panel derecho") { viewModel.save(side: .right) }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Guardar")
            }
        }
        .frame(minWidth: 900, minHeight: 500)
    }

    private var summaryView: some View {
        HStack(spacing: 10) {
            Label("\(viewModel.diffResult.summary.added)", systemImage: "plus.circle.fill")
                .foregroundStyle(.green)
            Label("\(viewModel.diffResult.summary.removed)", systemImage: "minus.circle.fill")
                .foregroundStyle(.red)
            Label("\(viewModel.diffResult.summary.modified)", systemImage: "pencil.circle.fill")
                .foregroundStyle(.orange)
        }
        .font(.caption)
        .monospacedDigit()
    }

    private var largeFileBanner: some View {
        Label("Archivo grande: el resaltado por palabra se desactivó para mantener la app responsiva.", systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
            Button("OK") { viewModel.errorMessage = nil }
        }
        .padding(6)
        .background(Color.red.opacity(0.1))
    }
}
