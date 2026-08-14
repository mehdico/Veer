import SwiftUI

struct SettingsScene: View {
    let env: AppEnvironment

    var body: some View {
        TabView {
            GeneralTab(env: env)
                .tabItem { Label("General", systemImage: "gear") }
                .accessibilityIdentifier("settingsGeneralTab")
            IgnoredAppsTab(env: env)
                .tabItem { Label("Ignored Apps", systemImage: "eye.slash") }
                .accessibilityIdentifier("settingsIgnoredAppsTab")
            HotkeysTab(env: env)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                .accessibilityIdentifier("settingsHotkeysTab")
        }
        .frame(width: 480, height: 440)
    }
}
