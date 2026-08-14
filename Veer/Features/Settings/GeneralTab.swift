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
        ScrollView {
            Form {
                Section("History") {
                    Picker("Clips to keep", selection: $settings.maxHistoryItems) {
                        ForEach(Constants.History.options, id: \.self) { option in
                            Text("\(option)")
                                .tag(option)
                        }
                    }
                    .accessibilityIdentifier("settingsMaxItemsPicker")
                }

                Section {
                    Toggle("Only store text", isOn: $settings.textOnlyHistory)
                        .accessibilityIdentifier("settingsTextOnlyToggle")
                } footer: {
                    Text("All files are skipped when on — even text files. Only text in any format (plain, rich, HTML) is saved.")
                }

                Section("Appearance") {
                    Toggle("Show formatted text in clips", isOn: $settings.showsRichText)
                        .accessibilityIdentifier("settingsShowsRichTextToggle")
                    Toggle("Show clips as cards", isOn: $settings.showAsCards)
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
            .onChange(of: settings.showAsCards) { _, new in
                env.panel.horizontal = new
            }
            .onChange(of: launchAtLogin) { _, new in
                try? env.launcher.setEnabled(new)
                launchAtLogin = env.launcher.isEnabled
            }
        }
    }
}
