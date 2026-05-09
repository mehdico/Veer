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
        #expect(store.useHorizontalLayout == true)
    }

    @Test func mutationsPersistAcrossInstances() {
        let defaults = makeDefaults()
        let first = SettingsStore(defaults: defaults)
        first.maxHistoryItems = 200
        first.showsRichText = false
        first.pastesRichText = false
        first.useHorizontalLayout = false

        let second = SettingsStore(defaults: defaults)
        #expect(second.maxHistoryItems == 200)
        #expect(second.showsRichText == false)
        #expect(second.pastesRichText == false)
        #expect(second.useHorizontalLayout == false)
    }

    @Test func snapshotMatchesCurrentValues() {
        let store = SettingsStore(defaults: makeDefaults())
        store.maxHistoryItems = 750
        let snap = store.snapshot
        #expect(snap.maxHistoryItems == 750)
        #expect(snap.showsRichText == true)
    }

    @Test func corruptStoredDataFallsBackToDefaults() {
        let defaults = makeDefaults()
        defaults.set(Data([0x01, 0x02, 0x03]), forKey: SettingsStore.userDefaultsKey)
        let store = SettingsStore(defaults: defaults)
        #expect(store.maxHistoryItems == Constants.History.defaultMax)
    }
}
