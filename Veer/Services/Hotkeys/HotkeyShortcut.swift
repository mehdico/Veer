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
}
