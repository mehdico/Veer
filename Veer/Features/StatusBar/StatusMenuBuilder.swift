import AppKit

@MainActor
enum StatusMenuBuilder {
    static func build(target: StatusMenuActions) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let toggleItem = makeItem(
            symbol: "rectangle.portrait.on.rectangle.portrait",
            title: "Show Veer",
            action: #selector(StatusMenuActions.togglePanel(_:)),
            keyEquivalent: "V",
            identifier: AccessibilityIdentifiers.toggleWindowButton,
            target: target
        )
        // Display the real global hotkey (⌘⇧V) next to the item.
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(toggleItem)

        let positionItem = makeItem(
            symbol: "rectangle.3.group",
            title: "Position",
            action: nil,
            identifier: AccessibilityIdentifiers.positionButton,
            target: nil
        )
        positionItem.submenu = makePositionSubmenu(target: target)
        menu.addItem(positionItem)

        menu.addItem(.separator())

        let deleteItem = makeItem(
            symbol: "trash",
            title: "Delete clip",
            action: #selector(StatusMenuActions.deleteSelected(_:)),
            keyEquivalent: String(Character(UnicodeScalar(NSDeleteCharacter)!)),
            identifier: AccessibilityIdentifiers.deleteSelectedButton,
            target: target
        )
        deleteItem.keyEquivalentModifierMask = .control
        // Enabled live while the panel is open (StatusBarController updates it
        // in menuWillOpen); deleting with the panel hidden would target an
        // invisible clip.
        menu.addItem(deleteItem)

        menu.addItem(makeItem(
            symbol: "trash.slash",
            title: "Clear history…",
            action: #selector(StatusMenuActions.clearHistory(_:)),
            identifier: AccessibilityIdentifiers.clearHistoryButton,
            target: target
        ))

        menu.addItem(.separator())

        menu.addItem(makeItem(
            symbol: "square.and.arrow.up",
            title: "Export History…",
            action: #selector(StatusMenuActions.exportHistory(_:)),
            identifier: AccessibilityIdentifiers.exportHistoryButton,
            target: target
        ))
        menu.addItem(makeItem(
            symbol: "square.and.arrow.down",
            title: "Import History…",
            action: #selector(StatusMenuActions.importHistory(_:)),
            identifier: AccessibilityIdentifiers.importHistoryButton,
            target: target
        ))

        menu.addItem(.separator())

        menu.addItem(makeItem(
            symbol: "power",
            title: "Open at login",
            action: #selector(StatusMenuActions.toggleLaunchAtLogin(_:)),
            identifier: AccessibilityIdentifiers.launchAtLoginButton,
            target: target
        ))

        menu.addItem(makeItem(
            symbol: "gearshape",
            title: "Settings…",
            action: #selector(StatusMenuActions.showPreferences(_:)),
            keyEquivalent: ",",
            identifier: AccessibilityIdentifiers.preferencesButton,
            target: target
        ))

        menu.addItem(.separator())

        menu.addItem(makeItem(
            symbol: "questionmark.circle",
            title: "Help",
            action: #selector(StatusMenuActions.showHelp(_:)),
            identifier: AccessibilityIdentifiers.helpButton,
            target: target
        ))

        menu.addItem(makeItem(
            symbol: "info.circle",
            title: "About Veer",
            action: #selector(StatusMenuActions.showAbout(_:)),
            identifier: AccessibilityIdentifiers.aboutButton,
            target: target
        ))

        menu.addItem(.separator())

        menu.addItem(makeItem(
            symbol: "power.circle",
            title: "Quit Veer",
            action: #selector(StatusMenuActions.quit(_:)),
            keyEquivalent: "q",
            identifier: AccessibilityIdentifiers.quitButton,
            target: target
        ))

        #if DEBUG
        menu.addItem(.separator())
        menu.addItem(makeItem(
            symbol: "ladybug",
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
                symbol: position.menuGlyph,
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
        symbol: String? = nil,
        title: String,
        action: Selector?,
        keyEquivalent: String = "",
        identifier: String,
        target: StatusMenuActions?
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        item.target = target
        item.setAccessibilityIdentifier(identifier)
        return item
    }
}

private extension PanelPosition {
    var menuGlyph: String {
        switch self {
        case .right: "rectangle.righthalf.inset.filled"
        case .left: "rectangle.lefthalf.inset.filled"
        case .top: "rectangle.tophalf.inset.filled"
        case .bottom, .bottomSmall, .bottomLarge: "rectangle.bottomhalf.inset.filled"
        case .centerExtraSmall, .centerSmall, .centerMedium, .centerLarge: "rectangle.center.inset.filled"
        }
    }
}
