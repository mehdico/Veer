import SwiftUI

@MainActor
enum PanelKeyHandler {
    static func handle(_ press: KeyPress, viewModel: HistoryListViewModel) -> KeyPress.Result {
        let key = press.key
        let mods = press.modifiers
        let chars = press.characters

        if isBackspace(press) {
            if !viewModel.searchText.isEmpty {
                viewModel.searchText = String(viewModel.searchText.dropLast())
            }
            return .handled
        }

        switch key {
        case .upArrow, .leftArrow:
            viewModel.navigateUp()
            return .handled
        case .downArrow, .rightArrow:
            viewModel.navigateDown()
            return .handled
        case .pageUp:
            viewModel.navigateUp(by: 10)
            return .handled
        case .pageDown:
            viewModel.navigateDown(by: 10)
            return .handled
        case .return:
            Task { await viewModel.pasteSelected() }
            return .handled
        case .escape:
            if !viewModel.searchText.isEmpty {
                viewModel.searchText = ""
            } else {
                viewModel.panel.hide()
            }
            return .handled
        case .tab:
            return .ignored
        default:
            break
        }

        if mods.contains(.command),
           let first = chars.unicodeScalars.first,
           let digit = Int(String(first)),
           (0...9).contains(digit)
        {
            let absolute = viewModel.quickPasteBase + digit
            Task { await viewModel.selectAndPaste(quickIndex: absolute) }
            return .handled
        }

        if mods.contains(.command) && chars.lowercased() == "y" {
            viewModel.togglePreview()
            return .handled
        }

        let suppressedMods: EventModifiers = [.command, .control, .option]
        guard mods.intersection(suppressedMods).isEmpty else { return .ignored }

        let printable = String(chars.filter(Self.isPrintable))
        if !printable.isEmpty {
            viewModel.searchText += printable
            return .handled
        }
        return .ignored
    }

    static func isBackspace(_ press: KeyPress) -> Bool {
        if press.key == .delete { return true }
        return press.characters.unicodeScalars.contains { $0.value == 0x08 || $0.value == 0x7F }
    }

    static func isPrintable(_ ch: Character) -> Bool {
        guard let scalar = ch.unicodeScalars.first else { return false }
        let v = scalar.value
        if v < 0x20 { return false }   // C0 control chars
        if v == 0x7F { return false }  // DEL
        if v >= 0x80 && v < 0xA0 { return false } // C1 control chars
        // Filter Unicode control categories
        let category = scalar.properties.generalCategory
        switch category {
        case .control, .format, .unassigned, .privateUse:
            return false
        default:
            return true
        }
    }
}
