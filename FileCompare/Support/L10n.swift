import Foundation
import Combine

enum LanguageSetting: String, CaseIterable, Identifiable {
    case auto
    case en
    case es

    var id: String { rawValue }

    /// What the selector shows for this option.
    var label: String { rawValue.uppercased() }
}

/// Every user-visible string, as a plain struct: both language values below
/// use the memberwise initializer, so a missing translation is a compile
/// error, not a runtime fallback.
struct Strings {
    let viewPicker: String
    let sideBySide: String
    let unified: String
    let sets: String

    let ignoreWhitespace: String
    let ignoreCase: String
    let ignoreNoise: String
    let ignoreNoiseHelp: String
    let stripPlaceholder: String
    let stripHelp: String

    let sortLabel: String
    let sortAscHelp: String
    let sortDescHelp: String
    let previousChangeHelp: String
    let nextChangeHelp: String
    let copyLeftToRightHelp: String
    let copyRightToLeftHelp: String
    let saveLeftPanel: String
    let saveRightPanel: String
    let saveHelp: String

    let leftPanel: String
    let rightPanel: String
    let leftTitle: String
    let rightTitle: String
    let openFileHelp: String
    let dropHint: String

    let onlyHereSuffix: String
    let inBoth: String
    let empty: String
    let copyListHelp: String

    let largeFileBanner: String
    let fileOver50MB: String
    let notTextError: String
    let ok: String
    let cancel: String
    let saveAsUTF8Title: String
    /// `%@` is the file's original encoding.
    let saveAsUTF8Message: String
    let saveAsUTF8Button: String

    let undoSortAsc: String
    let undoSortDesc: String
    let undoCopy: String

    let language: String
}

extension Strings {
    static let en = Strings(
        viewPicker: "View",
        sideBySide: "Side by side",
        unified: "Unified",
        sets: "Sets",
        ignoreWhitespace: "Ignore whitespace",
        ignoreCase: "Ignore case",
        ignoreNoise: "Ignore URLs/dates/blanks",
        ignoreNoiseHelp: "For Instagram-style exports where each entry has a different number of lines (URL, date) — only the username matters.",
        stripPlaceholder: "Strip text before comparing…",
        stripHelp: "Text removed from every line only for comparing (e.g. \"instagram.com/\"), without touching what's shown.",
        sortLabel: "Sort",
        sortAscHelp: "Sort A to Z / lowest to highest",
        sortDescHelp: "Sort Z to A / highest to lowest",
        previousChangeHelp: "Previous change (⌘↑)",
        nextChangeHelp: "Next change (⌘↓)",
        copyLeftToRightHelp: "Copy left → right",
        copyRightToLeftHelp: "Copy right → left",
        saveLeftPanel: "Save left panel",
        saveRightPanel: "Save right panel",
        saveHelp: "Save",
        leftPanel: "Left panel",
        rightPanel: "Right panel",
        leftTitle: "Left",
        rightTitle: "Right",
        openFileHelp: "Open file…",
        dropHint: "Drop a file here, use the folder button, or paste text",
        onlyHereSuffix: "Only here",
        inBoth: "In both",
        empty: "Empty",
        copyListHelp: "Copy list",
        largeFileBanner: "Large file: word-level highlighting was disabled to keep the app responsive.",
        fileOver50MB: "The file is over 50MB; the app may become slow.",
        notTextError: "The file doesn't look like plain text (unrecognized encoding).",
        ok: "OK",
        cancel: "Cancel",
        saveAsUTF8Title: "Save as UTF-8?",
        saveAsUTF8Message: "The text has characters that can't be saved in the file's original encoding (%@).",
        saveAsUTF8Button: "Save as UTF-8",
        undoSortAsc: "Sort A-Z",
        undoSortDesc: "Sort Z-A",
        undoCopy: "Copy",
        language: "Language"
    )

    static let es = Strings(
        viewPicker: "Vista",
        sideBySide: "Lado a lado",
        unified: "Unificado",
        sets: "Conjuntos",
        ignoreWhitespace: "Ignorar espacios",
        ignoreCase: "Ignorar mayúsc/minúsc",
        ignoreNoise: "Ignorar URLs/fechas/vacíos",
        ignoreNoiseHelp: "Para exportaciones tipo Instagram donde cada entrada tiene distinta cantidad de líneas (URL, fecha) — sólo importa el nombre de usuario.",
        stripPlaceholder: "Quitar texto antes de comparar…",
        stripHelp: "Texto que se elimina de cada línea sólo para compararla (ej: \"instagram.com/\"), sin tocar lo que se muestra.",
        sortLabel: "Ordenar",
        sortAscHelp: "Ordenar de A a Z / menor a mayor",
        sortDescHelp: "Ordenar de Z a A / mayor a menor",
        previousChangeHelp: "Cambio anterior (⌘↑)",
        nextChangeHelp: "Siguiente cambio (⌘↓)",
        copyLeftToRightHelp: "Copiar izquierda → derecha",
        copyRightToLeftHelp: "Copiar derecha → izquierda",
        saveLeftPanel: "Guardar panel izquierdo",
        saveRightPanel: "Guardar panel derecho",
        saveHelp: "Guardar",
        leftPanel: "Panel izquierdo",
        rightPanel: "Panel derecho",
        leftTitle: "Izquierda",
        rightTitle: "Derecha",
        openFileHelp: "Abrir archivo…",
        dropHint: "Arrastrá un archivo, usá el botón de carpeta o pegá texto acá",
        onlyHereSuffix: "Solo acá",
        inBoth: "En ambos",
        empty: "Vacío",
        copyListHelp: "Copiar lista",
        largeFileBanner: "Archivo grande: el resaltado por palabra se desactivó para mantener la app responsiva.",
        fileOver50MB: "El archivo supera 50MB; la app puede volverse lenta.",
        notTextError: "El archivo no parece ser texto plano (encoding no reconocido).",
        ok: "OK",
        cancel: "Cancelar",
        saveAsUTF8Title: "¿Guardar como UTF-8?",
        saveAsUTF8Message: "El texto tiene caracteres que no se pueden guardar en el encoding original del archivo (%@).",
        saveAsUTF8Button: "Guardar como UTF-8",
        undoSortAsc: "Ordenar A-Z",
        undoSortDesc: "Ordenar Z-A",
        undoCopy: "Copiar",
        language: "Idioma"
    )
}

/// Language selection: "auto" follows the system language, "en"/"es" force
/// one. Persisted in UserDefaults; observed by the UI so a change applies
/// instantly, no relaunch.
final class L10n: ObservableObject {
    static let shared = L10n()
    private static let defaultsKey = "language"

    @Published var setting: LanguageSetting {
        didSet { UserDefaults.standard.set(setting.rawValue, forKey: Self.defaultsKey) }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey)
        setting = stored.flatMap(LanguageSetting.init(rawValue:)) ?? .auto
    }

    var t: Strings {
        resolvedIsSpanish ? .es : .en
    }

    private var resolvedIsSpanish: Bool {
        switch setting {
        case .en: return false
        case .es: return true
        case .auto:
            return (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es")
        }
    }
}
