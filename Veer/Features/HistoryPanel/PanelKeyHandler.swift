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
        handle(
            key: press.key,
            characters: press.characters,
            modifiers: press.modifiers,
            phase: press.phase,
            viewModel: viewModel
        )
    }

    /// Value-level variant so tests can drive the handler without a real
    /// KeyPress (which has no public initializer).
    static func handle(
        key: KeyEquivalent,
        characters: String,
        modifiers mods: EventModifiers,
        phase: KeyPress.Phases,
        viewModel: HistoryListViewModel
    ) -> KeyPress.Result {
        let chars = characters

        if key == .delete || chars.unicodeScalars.contains(where: { $0.value == 0x08 || $0.value == 0x7F }) {
            // Documented as ⌃⌫; ⌘⌫ kept working for existing muscle memory.
            if mods.intersection([.command, .control]) != [],
               !phase.contains(.repeat)
            {
                viewModel.deleteSelected()
                return .handled
            }
            // Plain backspace edits the search field natively (caret, selection).
            return .ignored
        }

        // While searching, ⌥←/→ moves the caret word-wise inside the query
        // instead of navigating (plain arrows always navigate).
        if mods.contains(.option),
           !viewModel.searchText.isEmpty,
           key == .leftArrow || key == .rightArrow
        {
            return .ignored
        }

        switch key {
        case .upArrow:
            if viewModel.actionsExpanded {
                // Strip open: ↑ exits it.
                if !phase.contains(.repeat) {
                    viewModel.closeActionStrip()
                }
            } else if !viewModel.panel.horizontal {
                // Strip closed, vertical list: ↑ moves up through history.
                if navigationRepeatGate.shouldAccept(phase: phase, direction: .up) {
                    viewModel.navigateUp()
                }
            }
            return .handled
        case .downArrow:
            if viewModel.actionsExpanded {
                // Strip open (both layouts): ↓ closes it.
                if !phase.contains(.repeat) {
                    viewModel.closeActionStrip()
                }
            } else if viewModel.panel.horizontal {
                // Strip closed, cards: ↓ reveals the action strip.
                if !phase.contains(.repeat) {
                    viewModel.stepActions()
                }
            } else {
                // Strip closed, vertical list: ↓ moves down through history.
                if navigationRepeatGate.shouldAccept(phase: phase, direction: .down) {
                    viewModel.navigateDown()
                }
            }
            return .handled
        case .leftArrow:
            if viewModel.actionsExpanded {
                // Strip open: ← steps the highlight backward (wraps).
                viewModel.stepActionsBackward()
            } else if viewModel.panel.horizontal {
                // Strip closed, cards: ← moves up through history.
                if navigationRepeatGate.shouldAccept(phase: phase, direction: .up) {
                    viewModel.navigateUp()
                }
            }
            return .handled
        case .rightArrow:
            if viewModel.actionsExpanded {
                // Strip open: → steps the highlight forward (wraps).
                viewModel.stepActions()
            } else if viewModel.panel.horizontal {
                // Strip closed, cards: → moves down through history.
                if navigationRepeatGate.shouldAccept(phase: phase, direction: .down) {
                    viewModel.navigateDown()
                }
            } else {
                // Strip closed, vertical list: → reveals the action strip,
                // mirroring ↓ in the cards layout.
                if !phase.contains(.repeat) {
                    viewModel.stepActions()
                }
            }
            return .handled
        case .pageUp:
            viewModel.navigateUp(by: 10)
            return .handled
        case .pageDown:
            viewModel.navigateDown(by: 10)
            return .handled
        case .return:
            if mods.contains(.option) {
                Task { await viewModel.pasteSelected(asPlainText: true) }
            } else if mods.contains(.command) {
                viewModel.runPrimaryAction()
            } else if viewModel.actionsExpanded {
                viewModel.runHighlightedAction()
            } else {
                Task { await viewModel.pasteSelected() }
            }
            return .handled
        case .escape:
            if viewModel.actionsExpanded {
                viewModel.closeActionStrip()
            } else if !viewModel.searchText.isEmpty {
                viewModel.searchText = ""
            } else {
                viewModel.panel.hide()
            }
            return .handled
        case .space:
            if viewModel.searchText.isEmpty {
                viewModel.togglePreview()
                return .handled
            }
            // Searching: let the field insert the space natively.
            return .ignored
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

        // ⌘C copies the selected clip to the pasteboard without pasting (and
        // without leaving the panel), mirroring the system-wide copy reflex.
        if mods.contains(.command) && chars.lowercased() == "c" {
            viewModel.copySelected()
            return .handled
        }

        let suppressedMods: EventModifiers = [.command, .control, .option]
        guard mods.intersection(suppressedMods).isEmpty else { return .ignored }

        // Everything else (printables, backspace editing, ⌥←/→ word-jumps in
        // the field when it holds the caret) goes to the focused search field.
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
