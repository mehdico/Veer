import SwiftUI

struct GeneralTab: View {
    let env: AppEnvironment
    @Bindable var settings: SettingsStore

    @State private var launchAtLogin: Bool

    init(env: AppEnvironment) {
        self.env = env
        self.settings = env.settings
        self._launchAtLogin = State(initialValue: env.launcher.isEnabled)
    }

    var body: some View {
        Form {
            Section("History") {
                Picker("Clips to keep", selection: $settings.maxHistoryItems) {
                    ForEach(Constants.History.options, id: \.self) { option in
                        Text("\(option)").tag(option)
                    }
                }
                .accessibilityIdentifier("settingsMaxItemsPicker")
            }

            Section("Appearance") {
                Toggle("Show formatted text in clips", isOn: $settings.showsRichText)
                    .accessibilityIdentifier("settingsShowsRichTextToggle")
                Toggle("Use horizontal card layout", isOn: $settings.useHorizontalLayout)
                    .accessibilityIdentifier("settingsHorizontalToggle")
            }

            Section("Pasting") {
                Toggle("Keep formatting when pasting", isOn: $settings.pastesRichText)
                    .accessibilityIdentifier("settingsPastesRichTextToggle")
            }

            Section("Startup") {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .accessibilityIdentifier("settingsLaunchAtLoginToggle")
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .onChange(of: settings.maxHistoryItems) { _, new in
            try? env.repository.setMaxItems(new)
        }
        .onChange(of: settings.useHorizontalLayout) { _, new in
            env.panel.horizontal = new
        }
        .onChange(of: launchAtLogin) { _, new in
            try? env.launcher.setEnabled(new)
            launchAtLogin = env.launcher.isEnabled
        }
    }
}
