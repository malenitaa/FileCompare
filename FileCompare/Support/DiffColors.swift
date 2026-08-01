import AppKit
import SwiftUI

enum PanelSide {
    case left
    case right
}

enum DiffColors {
    static func lineBackground(for kind: DiffLineKind) -> NSColor? {
        switch kind {
        case .unchanged: return nil
        case .added: return NSColor.systemGreen.withAlphaComponent(0.16)
        case .removed: return NSColor.systemRed.withAlphaComponent(0.16)
        case .modified: return NSColor.systemOrange.withAlphaComponent(0.16)
        }
    }

    static func wordBackground(for side: PanelSide) -> NSColor {
        switch side {
        case .left: return NSColor.systemRed.withAlphaComponent(0.4)
        case .right: return NSColor.systemGreen.withAlphaComponent(0.4)
        }
    }

    static func swiftUIBackground(for kind: DiffLineKind) -> Color? {
        switch kind {
        case .unchanged: return nil
        case .added: return Color.green.opacity(0.16)
        case .removed: return Color.red.opacity(0.16)
        case .modified: return Color.orange.opacity(0.16)
        }
    }
}
