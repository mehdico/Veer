import SwiftUI

struct WelcomeView: View {
    let access: any AccessChecking
    let onTrusted: () -> Void

    @State private var trusted = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 18) {
            Text("Welcome to Veer")
                .font(.largeTitle)

            Text("Veer needs Accessibility access to register the global hotkey and paste into other applications.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .accessibilityIdentifier(AccessibilityIdentifiers.howToUseLabel)

            Button("Allow Accessibility access") {
                access.requestTrust()
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    openURL(url)
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.welcomeAllowAccessButton)
            .controlSize(.large)

            if trusted {
                Button("Continue") { onTrusted() }
                    .controlSize(.large)
            } else {
                Text("Waiting for permission…")
                    .foregroundStyle(.tertiary)
                    .accessibilityIdentifier(AccessibilityIdentifiers.waitingForControlLabel)
            }
        }
        .padding(40)
        .frame(width: 480, height: 320)
        .task {
            while !trusted {
                if access.isTrusted() {
                    trusted = true
                    break
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
