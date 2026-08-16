import Foundation

enum AccessibilityIdentifiers {
    static let welcomeWindow = "welcomeWindow"
    static let yippyWindow = "yippyWindow"
    static let helpWindow = "helpWindow"
    static let aboutWindow = "aboutWindow"

    static let statusItemButton = "statusItemButton"
    static let toggleWindowButton = "toggleWindowButton"
    static let launchAtLoginButton = "launchAtLoginButton"
    static let quitButton = "quitButton"
    static let helpButton = "helpButton"
    static let aboutButton = "aboutButton"
    static let preferencesButton = "preferencesButton"
    static let deleteSelectedButton = "deleteSelectedButton"
    static let clearHistoryButton = "clearHistoryButton"
    static let welcomeAllowAccessButton = "welcomeAllowAccessButton"

    static let positionButton = "positionButton"
    static let positionRightButton = "positionRightButton"
    static let positionLeftButton = "positionLeftButton"
    static let positionTopButton = "positionTopButton"
    static let positionBottomButton = "positionBottomButton"
    static let positionBottomSmall = "positionBottomButtonSmall"
    static let positionBottomLarge = "positionBottomButtonLarge"
    static let positionCenterExtraSmall = "positionCenterExtraSmall"
    static let positionCenterSmall = "positionCenterSmall"
    static let positionCenterMedium = "positionCenterMedium"
    static let positionCenterLarge = "positionCenterLarge"

    static let waitingForControlLabel = "waitingForControlLabel"
    static let howToUseLabel = "howToUseLabel"

    static let yippyTableView = "yippyTableView"
    static let panelSearchField = "panelSearchField"
    static let panelSearchClearButton = "panelSearchClearButton"
    static let quickPasteBadge = "quickPasteBadge"
    static let actionHintCue = "actionHintCue"
    static let actionsHint = "actionsHint"
    static let actionsHintDismissButton = "actionsHintDismissButton"
    static let yippyItemTextView = "YippyItemTextView"
    static let yippyTextCellView = "YippyTextCellView"
    static let yippyColorCellView = "YippyColorCellView"
    static let yippyTiffCellView = "YippyTiffCellView"
    static let yippyFileIconCellView = "YippyFileIconCellView"
    static let yippyFileThumbnailCellView = "YippyFileThumbnailCellView"
    static let yippyPdfCellView = "YippyPdfCellView"
    static let yippyRichTextCellView = "YippyRichTextCellView"

    static let previewWindow = "previewWindow"
    static let clipActionStrip = "clipActionStrip"
    static let clipActionTitle = "clipActionTitle"
    static func clipActionButton(_ actionID: String) -> String {
        "clipAction_\(actionID)"
    }
    static let debugHistoryCount = "debugHistoryCount"
}
