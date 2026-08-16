import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Using Veer")
                    .font(.largeTitle)
                Group {
                    Text("Veer keeps a history of everything you copy, ready to recall with a single keystroke.")
                    bullet("Open the panel with **⌘⇧V** anywhere.")
                    bullet("Use **↑ / ↓** (list) or **← / →** (cards) to move through history; **Return** pastes into the previous app.")
                    bullet("Type to filter the history with fuzzy search.")
                    bullet("Press **Space** to open a full-fidelity preview window.")
                    bullet("**⌃⌫** deletes the currently selected clip.")
                    bullet("**⌘1 … ⌘9** instantly pastes the first nine items.")
                    bullet("**→** (list) or **↓** (cards) reveals the actions for the selected clip; **↓** again or **↑** closes the strip.")
                    bullet("While the strip is open, **← / →** move between the actions (wrapping), and **↑** closes it.")
                    bullet("**Return** runs the highlighted action (or pastes, when no strip is open); **⌘↩** always runs the first detected action.")
                    bullet("**Esc** closes the action strip first, then clears search, then closes the panel.")
                    bullet("**⌃⌥⌘ + arrow keys** reposition the panel across edges of the screen.")
                }
                Text("Smart actions")
                    .font(.title2)
                    .padding(.top, 8)
                Text("When a clip is exactly a URL, email address, phone number, hex color, or one of the other recognized values, an action strip appears right on the clip — no separate window. Reveal it with **→** (list) or **↓** (cards), close it with **↓** or **↑**, and move between actions with **← / →**. Press **Return** to run the highlighted one. Mouse users can right-click a clip and pick from the Smart Actions menu instead. Running any action dismisses the panel; copy actions put the value on the clipboard and return you to your app, ready to paste.")
                Text("Permissions")
                    .font(.title2)
                    .padding(.top, 8)
                Text("Veer needs Accessibility access to register the global hotkey and to simulate the **⌘V** keystroke when pasting. Toggle Veer on under System Settings → Privacy & Security → Accessibility.")
            }
            .padding(28)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(minWidth: 560, minHeight: 380)
        .accessibilityIdentifier(AccessibilityIdentifiers.helpWindow)
    }

    private func bullet(_ markdown: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•")
            Text(markdown)
        }
    }
}
