import AppKit
import Carbon.HIToolbox
import SwiftUI

struct HotkeysTab: View {
    let env: AppEnvironment

    var body: some View {
        Form {
            Section("Open the panel") {
                row(title: "Show or hide Veer", shortcut: .togglePanel)
            }
            Section("Move the panel") {
                row(title: "Left edge", shortcut: .positionLeft)
                row(title: "Right edge", shortcut: .positionRight)
                row(title: "Top edge", shortcut: .positionTop)
                row(title: "Bottom edge", shortcut: .positionBottom)
            }
            Section("While the panel is open") {
                staticRow(keys: "↓ / →", description: "Open the action strip (↓ cards, → list)")
                staticRow(keys: "← →", description: "Step between actions while the strip is open")
                staticRow(keys: "↑ / ↓", description: "Close the action strip")
                staticRow(keys: "← → / ↑ ↓", description: "Navigate clips (strip closed; axis by layout)")
                staticRow(keys: "Page Up / Down", description: "Jump a page")
                staticRow(keys: "Return", description: "Paste / run highlighted action")
                staticRow(keys: "Esc", description: "Close strip, search, panel")
                staticRow(keys: "Space", description: "Toggle preview")
                staticRow(keys: "⌃⌫", description: "Delete selected clip")
                staticRow(keys: "⌘1 … ⌘9", description: "Paste by number")
                staticRow(keys: "⌘↩", description: "Run first detected action")
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    @ViewBuilder
    private func staticRow(keys: String, description: String) -> some View {
        HStack {
            Text(description)
            Spacer()
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private func row(title: String, shortcut: HotkeyShortcut) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(displayString(for: shortcut))
                .font(.system(.body, design: .monospaced))
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityIdentifier("settingsHotkey_\(shortcut.rawValue)")
        }
    }

    private func displayString(for shortcut: HotkeyShortcut) -> String {
        var parts: [String] = []
        let mods = shortcut.modifiers
        if mods & UInt32(controlKey) != 0 { parts.append("⌃") }
        if mods & UInt32(optionKey) != 0 { parts.append("⌥") }
        if mods & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if mods & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyName(for: shortcut.keyCode))
        return parts.joined()
    }

    private func keyName(for code: UInt32) -> String {
        switch Int(code) {
        case kVK_ANSI_V: return "V"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: return String(format: "0x%02X", code)
        }
    }
}
