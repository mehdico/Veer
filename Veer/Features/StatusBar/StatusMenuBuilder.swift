import AppKit

@MainActor
enum StatusMenuBuilder {
    static func build(target: StatusMenuActions) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(makeItem(
            title: "Show Veer",
            action: #selector(StatusMenuActions.togglePanel(_:)),
            keyEquivalent: "V",
            identifier: AccessibilityIdentifiers.toggleWindowButton,
            target: target
        ))

        let positionItem = makeItem(
            title: "Position",
            action: nil,
            identifier: AccessibilityIdentifiers.positionButton,
            target: nil
        )
        positionItem.submenu = makePositionSubmenu(target: target)
        menu.addItem(positionItem)

        menu.addItem(.separator())

        let deleteItem = makeItem(
            title: "Delete clip",
            action: #selector(StatusMenuActions.deleteSelected(_:)),
            keyEquivalent: String(Character(UnicodeScalar(NSDeleteCharacter)!)),
            identifier: AccessibilityIdentifiers.deleteSelectedButton,
            target: target
        )
        deleteItem.keyEquivalentModifierMask = .control
        deleteItem.isEnabled = false
        menu.addItem(deleteItem)

        menu.addItem(makeItem(
            title: "Clear history…",
            action: #selector(StatusMenuActions.clearHistory(_:)),
            identifier: AccessibilityIdentifiers.clearHistoryButton,
            target: target
        ))

        menu.addItem(.separator())

        menu.addItem(makeItem(
            title: "Open at login",
            action: #selector(StatusMenuActions.toggleLaunchAtLogin(_:)),
            identifier: AccessibilityIdentifiers.launchAtLoginButton,
            target: target
        ))

        menu.addItem(makeItem(
            title: "Settings…",
            action: #selector(StatusMenuActions.showPreferences(_:)),
            keyEquivalent: ",",
            identifier: AccessibilityIdentifiers.preferencesButton,
            target: target
        ))

        menu.addItem(.separator())

        menu.addItem(makeItem(
            title: "Help",
            action: #selector(StatusMenuActions.showHelp(_:)),
            identifier: AccessibilityIdentifiers.helpButton,
            target: target
        ))

        menu.addItem(makeItem(
            title: "About Veer",
            action: #selector(StatusMenuActions.showAbout(_:)),
            identifier: AccessibilityIdentifiers.aboutButton,
            target: target
        ))

        menu.addItem(.separator())

        menu.addItem(makeItem(
            title: "Quit Veer",
            action: #selector(StatusMenuActions.quit(_:)),
            keyEquivalent: "q",
            identifier: AccessibilityIdentifiers.quitButton,
            target: target
        ))

        #if DEBUG
        menu.addItem(.separator())
        menu.addItem(makeItem(
            title: "Debug: history 0",
            action: nil,
            identifier: AccessibilityIdentifiers.debugHistoryCount,
            target: nil
        ))
        #endif

        return menu
    }

    static func makePositionSubmenu(target: StatusMenuActions) -> NSMenu {
        let submenu = NSMenu(title: "Position")
        for position in PanelPosition.menuOrder {
            let item = makeItem(
                title: position.title,
                action: #selector(StatusMenuActions.selectPosition(_:)),
                identifier: position.accessibilityIdentifier,
                target: target
            )
            item.tag = position.rawValue
            submenu.addItem(item)
        }
        return submenu
    }

    private static func makeItem(
        title: String,
        action: Selector?,
        keyEquivalent: String = "",
        identifier: String,
        target: StatusMenuActions?
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        item.setAccessibilityIdentifier(identifier)
        return item
    }
}
