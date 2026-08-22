import AppKit
import Carbon.HIToolbox
import SwiftUI

struct HotkeysTab: View {
    let env: AppEnvironment

    var body: some View {
        Form {
            Section("Open the panel") {
                recorderRow(title: "Show or hide Veer", shortcut: .togglePanel)
            }
            Section("Move the panel") {
                recorderRow(title: "Left edge", shortcut: .positionLeft)
                recorderRow(title: "Right edge", shortcut: .positionRight)
                recorderRow(title: "Top edge", shortcut: .positionTop)
                recorderRow(title: "Bottom edge", shortcut: .positionBottom)
            }
            Section("While the panel is open") {
                staticRow(keys: "↓ / →", description: "Open the action strip (↓ cards, → list)")
                staticRow(keys: "← →", description: "Step between actions while the strip is open")
                staticRow(keys: "↑ / ↓", description: "Close the action strip")
                staticRow(keys: "← → / ↑ ↓", description: "Navigate clips (strip closed; axis by layout)")
                staticRow(keys: "Page Up / Down", description: "Jump a page")
                staticRow(keys: "Return", description: "Paste / run highlighted action")
                staticRow(keys: "⌥↩", description: "Paste as plain text")
                staticRow(keys: "⌘C", description: "Copy selected clip without pasting")
                staticRow(keys: "Esc", description: "Close strip, search, panel")
                staticRow(keys: "Space", description: "Toggle preview")
                staticRow(keys: "⌃⌫", description: "Delete selected clip")
                staticRow(keys: "⌘1 … ⌘9", description: "Paste by number")
                staticRow(keys: "⌘↩", description: "Run first detected action")
                staticRow(keys: "⌥← →", description: "Move the caret while searching")
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    private func recorderRow(title: String, shortcut: HotkeyShortcut) -> some View {
        HotkeyRecorderRow(title: title, shortcut: shortcut, env: env)
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
}

/// A settings row that shows the current binding for a shortcut and, when
/// clicked, captures the next key press as a new binding. The captured combo is
/// written to settings and applied live via `AppEnvironment.registerHotkeys()`.
private struct HotkeyRecorderRow: View {
    let title: String
    let shortcut: HotkeyShortcut
    let env: AppEnvironment

    @State private var isCapturing = false
    @State private var controller = HotkeyCaptureController()

    private var binding: HotkeyBinding {
        shortcut.resolvedBinding(using: env.settings.customHotkeys)
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if env.settings.customHotkeys[shortcut.rawValue] != nil {
                Button(action: reset) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
                .accessibilityIdentifier("settingsHotkeyReset_\(shortcut.rawValue)")
            }
            Button(action: toggleCapture) {
                Text(isCapturing
                      ? "Press keys…"
                      : HotkeyFormatter.displayString(keyCode: binding.keyCode, modifiers: binding.modifiers))
                    .frame(minWidth: 90)
            }
            .accessibilityIdentifier("settingsHotkeyRecord_\(shortcut.rawValue)")
        }
        .onDisappear(perform: stopCapture)
    }

    private func toggleCapture() {
        if controller.isCapturing { stopCapture() } else { startCapture() }
    }

    private func startCapture() {
        controller.start(shortcut: shortcut, env: env) { isCapturing = false }
        isCapturing = true
    }

    private func stopCapture() {
        controller.stop()
        isCapturing = false
    }

    private func reset() {
        env.settings.customHotkeys[shortcut.rawValue] = nil
        env.registerHotkeys()
    }
}

/// Owns the local event monitor used while recording a hotkey. A reference
/// type so the escaping monitor closure can mutate its own state (remove
/// itself) without fighting SwiftUI's value-type `@State` capture rules.
private final class HotkeyCaptureController {
    var monitor: Any?
    var isCapturing = false

    func start(shortcut: HotkeyShortcut, env: AppEnvironment, onStop: @escaping () -> Void) {
        guard monitor == nil else { return }
        isCapturing = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if HotkeyRecorderRow.isModifierKey(event.keyCode) { return event }
            var consumed = false
            MainActor.assumeIsolated {
                if event.keyCode == UInt16(kVK_Escape) {
                    self.stop()
                    onStop()
                    consumed = true
                    return
                }
                let modifiers: UInt32 =
                    (event.modifierFlags.contains(.command) ? UInt32(cmdKey) : 0)
                    | (event.modifierFlags.contains(.shift) ? UInt32(shiftKey) : 0)
                    | (event.modifierFlags.contains(.option) ? UInt32(optionKey) : 0)
                    | (event.modifierFlags.contains(.control) ? UInt32(controlKey) : 0)
                env.settings.customHotkeys[shortcut.rawValue] = [Int(event.keyCode), Int(modifiers)]
                env.registerHotkeys()
                self.stop()
                onStop()
                consumed = true
            }
            return consumed ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        self.monitor = nil
        isCapturing = false
    }
}

private extension HotkeyRecorderRow {
    static func isModifierKey(_ keyCode: UInt16) -> Bool {
        [kVK_Command, kVK_Shift, kVK_CapsLock, kVK_Option, kVK_Control,
         kVK_RightCommand, kVK_RightShift, kVK_RightOption, kVK_RightControl]
            .contains(Int(keyCode))
    }
}
