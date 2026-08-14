import Carbon.HIToolbox
import CoreGraphics

@MainActor
final class CGEventPaster: PasteSimulating {
    func simulatePaste() {
        // Use combinedSessionState so the event carries our explicit flags only;
        // post at the session tap so the user's currently-held physical modifiers
        // (e.g. Shift on a ⌘⇧V hotkey) aren't merged in and turned into Paste-and-Match-Style.
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let v = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        // Post the key-up slightly later instead of blocking the main thread with usleep.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(5)) {
            up.post(tap: .cgSessionEventTap)
        }
    }
}
