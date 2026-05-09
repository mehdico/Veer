import AppKit
import CoreGraphics

extension PanelPosition {
    func frame(for screen: NSScreen, horizontal: Bool) -> NSRect {
        Self.computeFrame(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            horizontal: horizontal,
            position: self
        )
    }

    static func computeFrame(
        screenFrame screen: NSRect,
        visibleFrame: NSRect,
        horizontal: Bool,
        position: PanelPosition
    ) -> NSRect {
        let menuHeight = horizontal ? Constants.Panel.horizontalHeight : Constants.Panel.verticalHeight
        let width = Constants.Panel.width

        switch position {
        case .right:
            return NSRect(x: screen.maxX - width, y: screen.minY, width: width, height: visibleFrame.height)
        case .left:
            return NSRect(x: screen.minX, y: screen.minY, width: width, height: visibleFrame.height)
        case .top:
            return NSRect(x: screen.minX, y: visibleFrame.maxY - menuHeight, width: screen.width, height: menuHeight)
        case .bottom:
            let h = floor(menuHeight * 1.7)
            return NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: h)
        case .bottomSmall:
            return NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: floor(menuHeight))
        case .bottomLarge:
            let h = floor(menuHeight * 2.4)
            return NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: h)
        case .centerExtraSmall:
            return centered(NSSize(width: screen.width / 3, height: screen.height / 3), in: screen)
        case .centerSmall:
            return centered(NSSize(width: screen.width / 2, height: screen.height / 2), in: screen)
        case .centerMedium:
            return centered(NSSize(width: screen.width * 0.7, height: screen.height * 0.7), in: screen)
        case .centerLarge:
            return centered(NSSize(width: screen.width * 0.85, height: screen.height * 0.85), in: screen)
        case .fullScreen:
            return screen
        }
    }

    private static func centered(_ size: NSSize, in rect: NSRect) -> NSRect {
        NSRect(
            x: (rect.width - size.width) / 2 + rect.minX,
            y: (rect.height - size.height) / 2 + rect.minY,
            width: size.width,
            height: size.height
        )
    }
}
