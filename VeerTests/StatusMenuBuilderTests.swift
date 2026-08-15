import AppKit
import Testing
@testable import Veer

@MainActor
struct StatusMenuBuilderTests {
    final class StubActions: NSObject, StatusMenuActions {
        var lastPositionTag: Int?
        var quitCalled = false
        func showAbout(_ sender: Any?) {}
        func showHelp(_ sender: Any?) {}
        func showPreferences(_ sender: Any?) {}
        func togglePanel(_ sender: Any?) {}
        func toggleLaunchAtLogin(_ sender: Any?) {}
        func deleteSelected(_ sender: Any?) {}
        func clearHistory(_ sender: Any?) {}
        func selectPosition(_ sender: NSMenuItem) { lastPositionTag = sender.tag }
        func quit(_ sender: Any?) { quitCalled = true }
    }

    @Test func topLevelMenuStructure() {
        let target = StubActions()
        let menu = StatusMenuBuilder.build(target: target)

        var expected = [
            "Show Veer",
            "Position",
            "",
            "Delete clip",
            "Clear history…",
            "",
            "Open at login",
            "Settings…",
            "",
            "Help",
            "About Veer",
            "",
            "Quit Veer",
        ]
        #if DEBUG
        expected += ["", "Debug: history 0"]
        #endif

        let titles = menu.items.map(\.title)
        #expect(titles == expected)
    }

    @Test func accessibilityIdentifiersOnTopLevelItems() {
        let menu = StatusMenuBuilder.build(target: StubActions())
        #expect(menu.item(withTitle: "About Veer")?.accessibilityIdentifier() == AccessibilityIdentifiers.aboutButton)
        #expect(menu.item(withTitle: "Help")?.accessibilityIdentifier() == AccessibilityIdentifiers.helpButton)
        #expect(menu.item(withTitle: "Settings…")?.accessibilityIdentifier() == AccessibilityIdentifiers.preferencesButton)
        #expect(menu.item(withTitle: "Show Veer")?.accessibilityIdentifier() == AccessibilityIdentifiers.toggleWindowButton)
        #expect(menu.item(withTitle: "Open at login")?.accessibilityIdentifier() == AccessibilityIdentifiers.launchAtLoginButton)
        #expect(menu.item(withTitle: "Delete clip")?.accessibilityIdentifier() == AccessibilityIdentifiers.deleteSelectedButton)
        #expect(menu.item(withTitle: "Clear history…")?.accessibilityIdentifier() == AccessibilityIdentifiers.clearHistoryButton)
        #expect(menu.item(withTitle: "Position")?.accessibilityIdentifier() == AccessibilityIdentifiers.positionButton)
        #expect(menu.item(withTitle: "Quit Veer")?.accessibilityIdentifier() == AccessibilityIdentifiers.quitButton)
    }

    @Test func positionSubmenuContainsAllElevenCases() {
        let menu = StatusMenuBuilder.build(target: StubActions())
        let submenu = menu.item(withTitle: "Position")?.submenu
        #expect(submenu != nil)
        #expect(submenu?.items.count == 11)

        let identifiers = submenu?.items.map { $0.accessibilityIdentifier() }
        #expect(identifiers == PanelPosition.menuOrder.map(\.accessibilityIdentifier))

        let tags = submenu?.items.map(\.tag)
        #expect(tags == PanelPosition.menuOrder.map(\.rawValue))
    }

    @Test func toggleWindowKeyEquivalent() {
        let menu = StatusMenuBuilder.build(target: StubActions())
        let toggle = menu.item(withTitle: "Show Veer")
        #expect(toggle?.keyEquivalent == "V")
    }

    @Test func deleteSelectedIsDisabledByDefaultWithControlModifier() {
        let menu = StatusMenuBuilder.build(target: StubActions())
        let delete = menu.item(withTitle: "Delete clip")
        #expect(delete?.isEnabled == false)
        #expect(delete?.keyEquivalentModifierMask == .control)
    }

    @Test func everyTopLevelItemHasTemplateIcon() {
        let menu = StatusMenuBuilder.build(target: StubActions())
        let titles = [
            "Show Veer", "Position", "Delete clip", "Clear history…",
            "Open at login", "Settings…", "Help", "About Veer", "Quit Veer",
        ]
        for title in titles {
            let item = menu.item(withTitle: title)
            #expect(item != nil, "missing item \(title)")
            #expect(item?.image != nil, "missing icon on \(title)")
            #expect(item?.image?.isTemplate == true, "icon not template on \(title)")
        }
    }

    @Test func positionSubmenuItemsHaveTemplateIcons() {
        let menu = StatusMenuBuilder.build(target: StubActions())
        let submenu = menu.item(withTitle: "Position")?.submenu
        #expect(submenu != nil)
        for item in submenu?.items ?? [] {
            #expect(item.image != nil)
            #expect(item.image?.isTemplate == true)
        }
    }

    @Test func selectPositionMenuItemDispatchesToTarget() {
        let target = StubActions()
        let menu = StatusMenuBuilder.build(target: target)
        let positionItem = menu.item(withTitle: "Position")?.submenu?.item(at: 2)
        #expect(positionItem != nil)
        positionItem?.target?.perform(positionItem!.action!, with: positionItem!)
        #expect(target.lastPositionTag == positionItem?.tag)
    }
}
