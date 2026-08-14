import AppKit
import SwiftUI

struct IgnoredAppsTab: View {
    let env: AppEnvironment
    @Bindable var settings: SettingsStore

    @State private var appToAdd: String = ""
    @State private var addableApps: [InstallableApp] = []
    @State private var didLoadApps = false

    init(env: AppEnvironment) {
        self.env = env
        self.settings = env.settings
    }

    var body: some View {
        ScrollView {
            Form {
                Section {
                    Toggle("Ignore password managers", isOn: $settings.ignoresPasswordManagers)
                        .accessibilityIdentifier("settingsIgnorePasswordManagersToggle")

                    Picker("Add app", selection: $appToAdd) {
                        Text("Choose an app…").tag("")
                        ForEach(pickerApps) { app in
                            Text(app.name).tag(app.bundleId)
                        }
                    }
                    .accessibilityIdentifier("settingsIgnoredAppPicker")

                    if settings.ignoredAppBundleIds.isEmpty {
                        Text("No ignored apps — entries are recorded from every app.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(settings.ignoredAppBundleIds, id: \.self) { bundleId in
                            HStack {
                                Text(Self.displayName(for: bundleId))
                                Text(bundleId)
                                    .foregroundStyle(.secondary)
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
                } footer: {
                    Text("Clips copied from ignored apps are not recorded. While the toggle is on, password managers and Keychain Access are ignored by default — remove any you want Veer to record.")
                }
            }
            .formStyle(.grouped)
            .padding(8)
            .onAppear {
                loadInstalledAppsIfNeeded()
            }
            .onChange(of: appToAdd) { _, new in
                guard !new.isEmpty else { return }
                settings.addIgnoredApp(new)
                appToAdd = ""
            }
        }
    }

    private struct InstallableApp: Identifiable {
        let bundleId: String
        let name: String
        var id: String { bundleId }
    }

    private var pickerApps: [InstallableApp] {
        let ignored = Set(settings.ignoredAppBundleIds)
        return addableApps.filter { !ignored.contains($0.bundleId) }
    }

    private func loadInstalledAppsIfNeeded() {
        guard !didLoadApps else { return }
        didLoadApps = true
        let ownBundleId = Bundle.main.bundleIdentifier
        Task { @MainActor in
            let apps = await Task.detached(priority: .utility) {
                Self.scanInstalledApps(excluding: ownBundleId)
            }.value
            addableApps = apps
        }
    }

    private static let appSearchRoots: [URL] = [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
        URL(fileURLWithPath: "/System/Library/CoreServices", isDirectory: true),
    ]

    private static func scanInstalledApps(excluding ownBundleId: String?) -> [InstallableApp] {
        var roots = appSearchRoots
        if let userApps = try? FileManager.default.url(
            for: .applicationDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            roots.append(userApps)
        }
        var apps: [InstallableApp] = []
        var seen = Set<String>()
        for root in roots {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else { continue }
            for url in contents where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let bundleId = bundle.bundleIdentifier,
                      bundleId != ownBundleId,
                      seen.insert(bundleId).inserted
                else { continue }
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                apps.append(InstallableApp(bundleId: bundleId, name: name))
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func displayName(for bundleId: String) -> String {
        if let known = Constants.Privacy.defaultIgnoredApps.first(where: { $0.bundleId == bundleId }) {
            return known.name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return url.deletingPathExtension().lastPathComponent
        }
        return bundleId
    }
}
