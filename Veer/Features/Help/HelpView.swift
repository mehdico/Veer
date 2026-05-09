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
                    bullet("Use **↑ / ↓** to move through history; **Return** pastes into the previous app.")
                    bullet("Type to filter the history with fuzzy search.")
                    bullet("Press **Space** to open a full-fidelity preview window.")
                    bullet("**⌃⌫** deletes the currently selected clip.")
                    bullet("**⌘0 … ⌘9** instantly pastes the first ten items.")
                    bullet("**⌃⌥⌘ + arrow keys** reposition the panel across edges of the screen.")
                }
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
