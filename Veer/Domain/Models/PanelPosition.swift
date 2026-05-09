import AppKit

enum PanelPosition: Int, Codable, CaseIterable, Sendable {
    case right = 0
    case left = 1
    case top = 2
    case bottom = 3
    case bottomSmall = 9
    case bottomLarge = 10
    case centerExtraSmall = 8
    case centerSmall = 4
    case centerMedium = 5
    case centerLarge = 6
    case fullScreen = 7

    var title: String {
        switch self {
        case .right: "Right"
        case .left: "Left"
        case .top: "Top"
        case .bottom: "Bottom"
        case .bottomSmall: "Bottom"
        case .bottomLarge: "Bottom"
        case .centerExtraSmall: "Center"
        case .centerSmall: "Center"
        case .centerMedium: "Center"
        case .centerLarge: "Center"
        case .fullScreen: "Full Screen"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .right: AccessibilityIdentifiers.positionRightButton
        case .left: AccessibilityIdentifiers.positionLeftButton
        case .top: AccessibilityIdentifiers.positionTopButton
        case .bottom: AccessibilityIdentifiers.positionBottomButton
        case .bottomSmall: AccessibilityIdentifiers.positionBottomSmall
        case .bottomLarge: AccessibilityIdentifiers.positionBottomLarge
        case .centerExtraSmall: AccessibilityIdentifiers.positionCenterExtraSmall
        case .centerSmall: AccessibilityIdentifiers.positionCenterSmall
        case .centerMedium: AccessibilityIdentifiers.positionCenterMedium
        case .centerLarge: AccessibilityIdentifiers.positionCenterLarge
        case .fullScreen: AccessibilityIdentifiers.positionFullScreen
        }
    }

    static let menuOrder: [PanelPosition] = [
        .right, .left, .top, .bottom, .centerMedium,
        .fullScreen,
    ]
}

extension PanelPosition {
    var baseForSizing: PanelPosition {
        switch self {
        case .bottomSmall, .bottom, .bottomLarge:
            return .bottom
        case .centerExtraSmall, .centerSmall, .centerMedium, .centerLarge:
            return .centerMedium
        case .left, .right, .top, .fullScreen:
            return self
        }
    }
}
