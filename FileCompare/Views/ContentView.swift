import SwiftUI

enum DiffViewMode: String, CaseIterable, Identifiable {
    case sideBySide
    case unified
    case sets
    var id: String { rawValue }

    func label(_ t: Strings) -> String {
        switch self {
        case .sideBySide: return t.sideBySide
        case .unified: return t.unified
        case .sets: return t.sets
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = CompareViewModel()
    @ObservedObject private var l10n = L10n.shared
    @State private var mode: DiffViewMode = .sideBySide

    private var t: Strings { l10n.t }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.diffResult.wordDiffDisabled {
                largeFileBanner
            }
            if let error = viewModel.activeError {
                errorBanner(error)
            }

            Group {
                switch mode {
                case .sideBySide:
                    SideBySideDiffView(viewModel: viewModel, t: t)
                case .unified:
                    UnifiedDiffView(diffResult: viewModel.diffResult, revision: viewModel.diffRevision)
                case .sets:
                    SetDiffView(
                        result: SetDiffEngine.compute(leftText: viewModel.leftText, rightText: viewModel.rightText, options: viewModel.options),
                        leftTitle: viewModel.leftURL?.lastPathComponent ?? t.leftTitle,
                        rightTitle: viewModel.rightURL?.lastPathComponent ?? t.rightTitle,
                        t: t
                    )
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Picker(t.viewPicker, selection: $mode) {
                    ForEach(DiffViewMode.allCases) { option in
                        Text(option.label(t)).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

                Toggle(t.ignoreWhitespace, isOn: Binding(
                    get: { viewModel.options.ignoreWhitespace },
                    set: { _ in viewModel.toggleIgnoreWhitespace() }
                ))
                Toggle(t.ignoreCase, isOn: Binding(
                    get: { viewModel.options.ignoreCase },
                    set: { _ in viewModel.toggleIgnoreCase() }
                ))

                if mode == .sets {
                    Toggle(t.ignoreNoise, isOn: Binding(
                        get: { viewModel.options.ignoreNoiseLines },
                        set: { _ in viewModel.toggleIgnoreNoiseLines() }
                    ))
                    .help(t.ignoreNoiseHelp)
                }

                TextField(t.stripPlaceholder, text: Binding(
                    get: { viewModel.options.stripText },
                    set: { viewModel.setStripText($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .help(t.stripHelp)

                Button { viewModel.sortLines() } label: {
                    Image(systemName: viewModel.isSortAscending ? "arrow.up" : "arrow.down")
                }
                .accessibilityLabel(t.sortLabel)
                .help(viewModel.isSortAscending ? t.sortAscHelp : t.sortDescHelp)

                Button { viewModel.goToPreviousChange() } label: {
                    Image(systemName: "chevron.up")
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .help(t.previousChangeHelp)

                Button { viewModel.goToNextChange() } label: {
                    Image(systemName: "chevron.down")
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .help(t.nextChangeHelp)

                summaryView

                Button { viewModel.copy(from: .left) } label: {
                    Image(systemName: "arrow.right")
                }
                .help(t.copyLeftToRightHelp)

                Button { viewModel.copy(from: .right) } label: {
                    Image(systemName: "arrow.left")
                }
                .help(t.copyRightToLeftHelp)

                Menu {
                    Button(t.saveLeftPanel) { viewModel.save(side: .left) }
                    Button(t.saveRightPanel) { viewModel.save(side: .right) }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help(t.saveHelp)

                Menu {
                    Picker(t.language, selection: $l10n.setting) {
                        ForEach(LanguageSetting.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "globe")
                }
                .help(t.language)
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
        Label(t.largeFileBanner, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))
    }

    private func errorBanner(_ error: CompareError) -> some View {
        HStack {
            Label(error.message(t), systemImage: "xmark.octagon.fill")
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
            Button(t.ok) { viewModel.activeError = nil }
        }
        .padding(6)
        .background(Color.red.opacity(0.1))
    }
}
