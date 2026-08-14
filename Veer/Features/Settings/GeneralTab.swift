import AppKit
import SwiftUI

struct GeneralTab: View {
    let env: AppEnvironment
    @Bindable var settings: SettingsStore

    @State private var launchAtLogin: Bool
    @State private var appToAdd: String = ""

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

                ignoredAppsSection

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
            .onChange(of: appToAdd) { _, new in
                guard !new.isEmpty else { return }
                settings.addIgnoredApp(new)
                appToAdd = ""
            }
        }
    }

    @ViewBuilder
    private var ignoredAppsSection: some View {
        Section {
            if settings.ignoredAppBundleIds.isEmpty {
                Text("No ignored apps — entries are recorded from every app.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(settings.ignoredAppBundleIds, id: \.self) { bundleId in
                    HStack {
                        Text(Self.displayName(for: bundleId))
                        Spacer()
                        Button {
                            settings.removeIgnoredApp(bundleId)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settingsRemoveIgnoredApp_\(bundleId)")
                        .help("Stop ignoring this app")
                    }
                }
            }

            Picker("Add app", selection: $appToAdd) {
                Text("Choose a running app…").tag("")
                ForEach(addableRunningApps) { app in
                    Text(app.name).tag(app.bundleId)
                }
            }
            .accessibilityIdentifier("settingsIgnoredAppPicker")
        } header: {
            Text("Ignored apps")
        } footer: {
            Text("Clips copied from ignored apps are not recorded.")
        }
    }

    private struct RunningApp: Identifiable {
        let bundleId: String
        let name: String
        var id: String { bundleId }
    }

    private var addableRunningApps: [RunningApp] {
        let ownBundleId = Bundle.main.bundleIdentifier
        let ignored = Set(settings.ignoredAppBundleIds)
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningApp? in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName,
                      bundleId != ownBundleId,
                      !ignored.contains(bundleId)
                else { return nil }
                return RunningApp(bundleId: bundleId, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func displayName(for bundleId: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return url.deletingPathExtension().lastPathComponent
        }
        return bundleId
    }
}
