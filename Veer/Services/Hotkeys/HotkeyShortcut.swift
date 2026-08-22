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
        if (kVK_ANSI_A...kVK_ANSI_Z).contains(Int(code)) {
            guard let scalar = UnicodeScalar(UInt32(65 + (Int(code) - Int(kVK_ANSI_A)))) else {
                return "?"
            }
            return String(Character(scalar))
        }
        if (kVK_ANSI_0...kVK_ANSI_9).contains(Int(code)) {
            return String(Int(code) - Int(kVK_ANSI_0))
        }
        switch Int(code) {
        case kVK_ANSI_V: return "V"
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
