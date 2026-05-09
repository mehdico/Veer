import SwiftUI

struct SettingsScene: View {
    let env: AppEnvironment

    var body: some View {
        TabView {
            GeneralTab(env: env)
                .tabItem { Label("General", systemImage: "gear") }
                .accessibilityIdentifier("settingsGeneralTab")
            HotkeysTab(env: env)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                .accessibilityIdentifier("settingsHotkeysTab")
        }
        .frame(width: 480, height: 360)
    }
}
