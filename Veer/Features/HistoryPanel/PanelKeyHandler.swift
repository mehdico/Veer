import SwiftUI

@MainActor
struct PanelNavigationRepeatGate {
    private var lastAccepted: ContinuousClock.Instant?
    private var repeatCount = 0
    private var lastDirection: Direction?

    enum Direction {
        case up, down
    }

    static func repeatInterval(afterRepeatCount count: Int) -> Duration {
        if count < 3 { return .milliseconds(150) }
        if count < 12 { return .milliseconds(100) }
        return .milliseconds(65)
    }

    mutating func shouldAccept(phase: KeyPress.Phases, direction: Direction) -> Bool {
        if !phase.contains(.repeat) {
            if phase.contains(.down) {
                lastDirection = direction
                repeatCount = 0
                lastAccepted = ContinuousClock.now
            }
            return true
        }
        if lastDirection != direction {
            lastDirection = direction
            repeatCount = 0
            lastAccepted = nil
        }
        let now = ContinuousClock.now
        let interval = Self.repeatInterval(afterRepeatCount: repeatCount)
        if let last = lastAccepted, now - last < interval {
            return false
        }
        lastAccepted = now
        repeatCount += 1
        return true
    }
}

@MainActor
enum PanelKeyHandler {
    private static var navigationRepeatGate = PanelNavigationRepeatGate()

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
            if navigationRepeatGate.shouldAccept(phase: press.phase, direction: .up) {
                viewModel.navigateUp()
            }
            return .handled
        case .downArrow, .rightArrow:
            if navigationRepeatGate.shouldAccept(phase: press.phase, direction: .down) {
                viewModel.navigateDown()
            }
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
           (1...9).contains(digit)
        {
            let absolute = viewModel.quickPasteBase + digit - 1
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
