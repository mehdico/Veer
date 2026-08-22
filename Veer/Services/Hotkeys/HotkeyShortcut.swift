import Carbon.HIToolbox
import Foundation

enum HotkeyShortcut: String, CaseIterable, Sendable {
    case togglePanel
    case positionLeft
    case positionRight
    case positionTop
    case positionBottom

    var keyCode: UInt32 {
        switch self {
        case .togglePanel: return UInt32(kVK_ANSI_V)
        case .positionLeft: return UInt32(kVK_LeftArrow)
        case .positionRight: return UInt32(kVK_RightArrow)
        case .positionTop: return UInt32(kVK_UpArrow)
        case .positionBottom: return UInt32(kVK_DownArrow)
        }
    }

    var modifiers: UInt32 {
        switch self {
        case .togglePanel:
            return UInt32(cmdKey | shiftKey)
        case .positionLeft, .positionRight, .positionTop, .positionBottom:
            return UInt32(cmdKey | optionKey | controlKey)
        }
    }

    var positionTarget: PanelPosition? {
        switch self {
        case .togglePanel: return nil
        case .positionLeft: return .left
        case .positionRight: return .right
        case .positionTop: return .top
        case .positionBottom: return .bottom
        }
    }

    /// The raw Carbon key code + modifier mask this shortcut resolves to,
    /// honoring any user override stored in settings.
    var `default`: HotkeyBinding {
        HotkeyBinding(keyCode: keyCode, modifiers: modifiers)
    }

    func resolvedBinding(using custom: [String: [Int]]) -> HotkeyBinding {
        guard let pair = custom[rawValue], pair.count == 2 else { return `default` }
        return HotkeyBinding(keyCode: UInt32(pair[0]), modifiers: UInt32(pair[1]))
    }
}

/// A resolved hotkey: a key code and a Carbon modifier mask.
struct HotkeyBinding: Sendable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
}

/// Renders a key code + Carbon modifier mask as a human-readable combo
/// (⌘⇧V), shared by the settings recorder and its display.
enum HotkeyFormatter {
    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    static func keyName(for code: UInt32) -> String {
        switch Int(code) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Return: return "↩"
        case kVK_Space: return "Space"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "⌫"
        case kVK_Tab: return "⇥"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: return String(format: "0x%02X", code)
        }
    }
}
