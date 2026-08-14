import Foundation
import Testing
@testable import Veer

@MainActor
struct SettingsStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "veer.test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test func defaultValuesMatchVeerSettingsDefaults() {
        let store = SettingsStore(defaults: makeDefaults())
        #expect(store.maxHistoryItems == Constants.History.defaultMax)
        #expect(store.showsRichText == true)
        #expect(store.pastesRichText == true)
        #expect(store.showAsCards == true)
        #expect(store.textOnlyHistory == false)
        #expect(store.ignoredAppBundleIds.isEmpty)
        #expect(store.panelSizeByPosition.isEmpty)
    }

    @Test func mutationsPersistAcrossInstances() {
        let defaults = makeDefaults()
        let first = SettingsStore(defaults: defaults)
        first.maxHistoryItems = 200
        first.showsRichText = false
        first.pastesRichText = false
        first.showAsCards = false
        first.textOnlyHistory = true
        first.setPanelSize(CGSize(width: 123, height: 456), for: 3, onScreenOfSize: CGSize(width: 1440, height: 900))

        let second = SettingsStore(defaults: defaults)
        #expect(second.maxHistoryItems == 200)
        #expect(second.showsRichText == false)
        #expect(second.pastesRichText == false)
        #expect(second.showAsCards == false)
        #expect(second.textOnlyHistory == true)
        #expect(second.panelSize(for: 3, matchingScreenSize: CGSize(width: 1440, height: 900)) == CGSize(width: 123, height: 456))
    }

    @Test func snapshotMatchesCurrentValues() {
        let store = SettingsStore(defaults: makeDefaults())
        store.maxHistoryItems = 750
        store.setPanelSize(CGSize(width: 111, height: 222), for: PanelPosition.bottom.rawValue, onScreenOfSize: CGSize(width: 1512, height: 982))
        let snap = store.snapshot
        #expect(snap.maxHistoryItems == 750)
        #expect(snap.showsRichText == true)
        #expect(snap.panelSizeByPosition[PanelPosition.bottom.rawValue] == PanelSize(width: 111, height: 222, screenWidth: 1512, screenHeight: 982))
    }

    @Test func panelSizeIsHonoredOnMatchingScreenAndIgnoredOnDifferentScreen() {
        let store = SettingsStore(defaults: makeDefaults())
        store.setPanelSize(CGSize(width: 1512, height: 220), for: PanelPosition.bottom.rawValue, onScreenOfSize: CGSize(width: 1512, height: 982))
        #expect(store.panelSize(for: PanelPosition.bottom.rawValue, matchingScreenSize: CGSize(width: 1512, height: 982)) == CGSize(width: 1512, height: 220))
        #expect(store.panelSize(for: PanelPosition.bottom.rawValue, matchingScreenSize: CGSize(width: 1800, height: 1169)) == nil)
    }

    @Test func legacyPanelSizeWithoutScreenInfoIsIgnored() {
        let defaults = makeDefaults()
        var settings = VeerSettings()
        settings.panelSizeByPosition = [PanelPosition.bottom.rawValue: PanelSize(width: 1512, height: 220)]
        defaults.set(try! JSONEncoder().encode(settings), forKey: SettingsStore.userDefaultsKey)
        let store = SettingsStore(defaults: defaults)
        #expect(store.panelSize(for: PanelPosition.bottom.rawValue, matchingScreenSize: CGSize(width: 1512, height: 982)) == nil)
    }

    @Test func corruptStoredDataFallsBackToDefaults() {
        let defaults = makeDefaults()
        defaults.set(Data([0x01, 0x02, 0x03]), forKey: SettingsStore.userDefaultsKey)
        let store = SettingsStore(defaults: defaults)
        #expect(store.maxHistoryItems == Constants.History.defaultMax)
    }

    @Test func settingsSavedBeforeTextOnlyFieldExistedKeepOtherValues() {
        let defaults = makeDefaults()
        let legacyJSON = """
        {"maxHistoryItems":200,"showsRichText":false,"pastesRichText":false,"showAsCards":false,"panelSizeByPosition":{}}
        """
        defaults.set(Data(legacyJSON.utf8), forKey: SettingsStore.userDefaultsKey)
        let store = SettingsStore(defaults: defaults)
        #expect(store.maxHistoryItems == 200)
        #expect(store.showsRichText == false)
        #expect(store.pastesRichText == false)
        #expect(store.showAsCards == false)
        #expect(store.textOnlyHistory == false)
        #expect(store.ignoredAppBundleIds.isEmpty)
    }

    @Test func ignoredAppsCanBeAddedRemovedAndPersist() {
        let defaults = makeDefaults()
        let first = SettingsStore(defaults: defaults)
        first.addIgnoredApp("com.example.one")
        first.addIgnoredApp("com.example.two")
        first.addIgnoredApp("com.example.one") // duplicate is ignored
        #expect(first.ignoredAppBundleIds == ["com.example.one", "com.example.two"])
        first.removeIgnoredApp("com.example.one")

        let second = SettingsStore(defaults: defaults)
        #expect(second.ignoredAppBundleIds == ["com.example.two"])
        second.addIgnoredApp("")
        #expect(second.ignoredAppBundleIds == ["com.example.two"])
    }
}
