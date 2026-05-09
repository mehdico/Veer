import AppKit
import CoreGraphics

extension PanelPosition {
    func frame(for screen: NSScreen, horizontal: Bool, overrideSize: NSSize? = nil) -> NSRect {
        Self.computeFrame(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            horizontal: horizontal,
            position: self,
            overrideSize: overrideSize
        )
    }

    static func computeFrame(
        screenFrame screen: NSRect,
        visibleFrame: NSRect,
        horizontal: Bool,
        position: PanelPosition,
        overrideSize: NSSize? = nil
    ) -> NSRect {
        let menuHeight = horizontal ? Constants.Panel.horizontalHeight : Constants.Panel.verticalHeight
        let width = Constants.Panel.width

        switch position {
        case .right:
            let w = overrideSize?.width ?? width
            let h = overrideSize?.height ?? visibleFrame.height
            return NSRect(x: screen.maxX - w, y: screen.minY, width: w, height: min(h, visibleFrame.height))
        case .left:
            let w = overrideSize?.width ?? width
            let h = overrideSize?.height ?? visibleFrame.height
            return NSRect(x: screen.minX, y: screen.minY, width: w, height: min(h, visibleFrame.height))
        case .top:
            let h = overrideSize?.height ?? menuHeight
            let w = overrideSize?.width ?? screen.width
            return NSRect(x: screen.minX, y: visibleFrame.maxY - min(h, visibleFrame.height), width: min(w, screen.width), height: min(h, visibleFrame.height))
        case .bottom:
            let h = floor(menuHeight * 1.7)
            let useH = overrideSize?.height ?? h
            let useW = overrideSize?.width ?? screen.width
            return NSRect(x: screen.minX, y: screen.minY, width: min(useW, screen.width), height: min(useH, visibleFrame.height))
        case .bottomSmall:
            let h = floor(menuHeight)
            let useH = overrideSize?.height ?? h
            let useW = overrideSize?.width ?? screen.width
            return NSRect(x: screen.minX, y: screen.minY, width: min(useW, screen.width), height: min(useH, visibleFrame.height))
        case .bottomLarge:
            let h = floor(menuHeight * 2.4)
            let useH = overrideSize?.height ?? h
            let useW = overrideSize?.width ?? screen.width
            return NSRect(x: screen.minX, y: screen.minY, width: min(useW, screen.width), height: min(useH, visibleFrame.height))
        case .centerExtraSmall:
            let size = overrideSize ?? NSSize(width: screen.width / 3, height: screen.height / 3)
            return centered(size, in: screen)
        case .centerSmall:
            let size = overrideSize ?? NSSize(width: screen.width / 2, height: screen.height / 2)
            return centered(size, in: screen)
        case .centerMedium:
            let size = overrideSize ?? NSSize(width: screen.width * 0.7, height: screen.height * 0.7)
            return centered(size, in: screen)
        case .centerLarge:
            let size = overrideSize ?? NSSize(width: screen.width * 0.85, height: screen.height * 0.85)
            return centered(size, in: screen)
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
