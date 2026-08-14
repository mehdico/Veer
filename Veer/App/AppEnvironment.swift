import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppEnvironment {
    let isUITesting: Bool

    let repository: any ClipRepository
    let ingestor: ClipIngestor
    let access: any AccessChecking
    let hotkeys: any HotkeyService
    let panel: PanelCoordinator
    let preview: PreviewCoordinator
    let paster: any PasteSimulating
    let pasteboardWriter: any PasteboardWriting
    let historyViewModel: HistoryListViewModel
    let settings: SettingsStore
    let launcher: any LaunchAtLoginService
    let alerter: any Alerting

    init(
        isUITesting: Bool,
        repository: any ClipRepository,
        ingestor: ClipIngestor,
        access: any AccessChecking,
        hotkeys: any HotkeyService,
        panel: PanelCoordinator,
        preview: PreviewCoordinator,
        paster: any PasteSimulating,
        pasteboardWriter: any PasteboardWriting,
        historyViewModel: HistoryListViewModel,
        settings: SettingsStore,
        launcher: any LaunchAtLoginService,
        alerter: any Alerting
    ) {
        self.isUITesting = isUITesting
        self.repository = repository
        self.ingestor = ingestor
        self.access = access
        self.hotkeys = hotkeys
        self.panel = panel
        self.preview = preview
        self.paster = paster
        self.pasteboardWriter = pasteboardWriter
        self.historyViewModel = historyViewModel
        self.settings = settings
        self.launcher = launcher
        self.alerter = alerter
    }

    static func live() -> AppEnvironment {
        let alerter = NSAlerter()
        let container: ModelContainer
        do {
            container = try VeerStore.live()
        } catch {
            VeerLogger(category: .repository).error("Live store failed: \(String(describing: error)). Falling back to in-memory; history will not persist across launches.")
            alerter.presentWarning(
                message: "Veer could not open its history store",
                informativeText: "Falling back to an in-memory store — clipboard history will not persist across launches. Underlying error: \(error.localizedDescription)"
            )
            do {
                container = try VeerStore.inMemory()
            } catch {
                alerter.presentError(error)
                fatalError("Veer could not initialize any model store: \(error)")
            }
        }
        return makeEnvironment(
            container: container,
            isUITesting: false,
            access: AXAccessChecker(),
            hotkeys: CarbonHotkeyService(),
            paster: CGEventPaster(),
            pasteboardWriter: LivePasteboardWriter(),
            settings: SettingsStore(),
            launcher: SMAppServiceLauncher(),
            alerter: alerter
        )
    }

    static func uiTest() -> AppEnvironment {
        let container = try! VeerStore.inMemory()
        let mockAccess = StaticAccessChecker(trusted: LaunchArguments.mockAccessibilityTrusted)
        let testDefaults = UserDefaults(suiteName: "veer.uitests.\(UUID().uuidString)") ?? .standard
        let env = makeEnvironment(
            container: container,
            isUITesting: true,
            access: mockAccess,
            hotkeys: NoopHotkeyService(),
            paster: CountingPaster(),
            pasteboardWriter: LivePasteboardWriter(),
            settings: SettingsStore(defaults: testDefaults),
            launcher: NoopLaunchAtLoginService(),
            alerter: SilentAlerter()
        )
        if let fixture = LaunchArguments.seedFixture {
            Seeder.seed(fixture, into: env.repository)
            env.historyViewModel.refresh()
        }
        return env
    }

    private static func makeEnvironment(
        container: ModelContainer,
        isUITesting: Bool,
        access: any AccessChecking,
        hotkeys: any HotkeyService,
        paster: any PasteSimulating,
        pasteboardWriter: LivePasteboardWriter,
        settings: SettingsStore,
        launcher: any LaunchAtLoginService,
        alerter: any Alerting
    ) -> AppEnvironment {
        let repository = ClipRepositoryLive(container: container, maxItems: settings.maxHistoryItems)
        let source = LivePasteboardSource()
        let frontmost = LiveFrontmostAppProvider()
        let monitor = PasteboardMonitor(source: source, frontmost: frontmost)
        pasteboardWriter.onWrite = { [weak monitor] count in
            monitor?.acknowledge(changeCount: count)
        }
        let ingestor = ClipIngestor(monitor: monitor, repository: repository, textOnlyHistory: { settings.textOnlyHistory })
        let panel = PanelCoordinator()
        panel.horizontal = settings.showAsCards
        let preview = PreviewCoordinator()
        let viewModel = HistoryListViewModel(
            repository: repository,
            paster: paster,
            pasteboardWriter: pasteboardWriter,
            panel: panel,
            settings: settings,
            access: access,
            alerter: alerter
        )
        viewModel.preview = preview
        return AppEnvironment(
            isUITesting: isUITesting,
            repository: repository,
            ingestor: ingestor,
            access: access,
            hotkeys: hotkeys,
            panel: panel,
            preview: preview,
            paster: paster,
            pasteboardWriter: pasteboardWriter,
            historyViewModel: viewModel,
            settings: settings,
            launcher: launcher,
            alerter: alerter
        )
    }
}

@MainActor
final class StaticAccessChecker: AccessChecking {
    private let trustedValue: Bool
    init(trusted: Bool) { self.trustedValue = trusted }
    func isTrusted() -> Bool { trustedValue }
    func requestTrust() {}
}

@MainActor
final class NoopHotkeyService: HotkeyService {
    func register(_ shortcut: HotkeyShortcut, handler: @escaping () -> Void) {}
    func unregisterAll() {}
}

@MainActor
final class CountingPaster: PasteSimulating {
    private(set) var pasteCount = 0
    func simulatePaste() { pasteCount += 1 }
}

@MainActor
final class NoopLaunchAtLoginService: LaunchAtLoginService {
    private var enabled = false
    var isEnabled: Bool { enabled }
    func setEnabled(_ value: Bool) throws { enabled = value }
}
