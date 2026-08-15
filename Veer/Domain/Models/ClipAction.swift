import Foundation

/// A smart action derived from the detected content of a text clip.
enum ClipAction: Identifiable, Hashable, Sendable {
    case openURL(URL)
    case copyMarkdownLink(URL)
    case composeEmail(String)
    case callPhone(String)
    case copySwiftColor(hex: String)

    var id: String {
        switch self {
        case .openURL: "openURL"
        case .copyMarkdownLink: "copyMarkdownLink"
        case .composeEmail: "composeEmail"
        case .callPhone: "callPhone"
        case .copySwiftColor: "copySwiftColor"
        }
    }

    var title: String {
        switch self {
        case .openURL: "Open in Browser"
        case .copyMarkdownLink: "Copy Markdown Link"
        case .composeEmail: "Compose Email"
        case .callPhone: "Call with FaceTime"
        case .copySwiftColor: "Copy Swift Color"
        }
    }

    var systemImage: String {
        switch self {
        case .openURL: "safari"
        case .copyMarkdownLink: "link"
        case .composeEmail: "envelope"
        case .callPhone: "phone"
        case .copySwiftColor: "swatchpalette"
        }
    }

    /// Launching actions hand off to another app, which activates itself.
    /// Copy actions dismiss the panel and return the user to the previous app
    /// so an immediate ⌘V lands there.
    var restoresPreviousApp: Bool {
        switch self {
        case .openURL, .composeEmail, .callPhone: false
        case .copyMarkdownLink, .copySwiftColor: true
        }
    }
}
