import Foundation

/// What happens to the panel and the previous app after an action runs.
enum ActionDismissal: Sendable {
    /// The action hands off to another app that activates itself (browser,
    /// Mail, Finder, Terminal, …).
    case launchApp
    /// The action put something on the pasteboard; return the user to the
    /// previous app so an immediate ⌘V lands there.
    case restorePreviousApp
    /// The action finished in the background (e.g. saved a file) without
    /// activating anything; the panel just closes.
    case justHide
}

/// Where an action's content comes from: inline pasteboard data, or a file
/// still on disk (read lazily when the action actually runs, so building the
/// action list never touches big files).
enum ClipContentSource: Hashable, Sendable {
    case data(Data)
    case file(URL)
}

/// A smart action derived from the detected content of a clip.
enum ClipAction: Identifiable, Hashable, Sendable {
    // Web & contact
    case openURL(URL)
    case copyMarkdownLink(URL)
    case composeEmail(String)
    case callPhone(String)
    case copySwiftColor(hex: String)

    // Files & folders
    case revealInFinder(URL)
    case openFile(URL)
    case copyPath(URL)
    case copyFile(URL)
    case openInTerminal(URL)
    case openInXcode(URL)

    // Text & data
    case openInMaps(latitude: Double, longitude: Double)
    case copyMathResult(String)
    case copyPrettyJSON(String)
    case copyMinifiedJSON(String)
    case copyEpochSeconds(String)
    case copyGitCloneURL(String)
    case openGitHub(URL)
    case searchWeb(String)
    case translate(text: String, sourceLanguage: String)

    // Rich media
    case saveToDownloads(source: ClipContentSource, fileExtension: String, suggestedName: String?)
    case copyAsPNG(source: ClipContentSource)
    case copyPlainText(String)
    case copyHexColor(String)
    case copyCSSRGB(red: Int, green: Int, blue: Int)
    case copyUIColor(red: Double, green: Double, blue: Double, alpha: Double)
    case copyQR(text: String)

    // Organization
    case pin(id: UUID)
    case unpin(id: UUID)

    var id: String {
        switch self {
        case .openURL: "openURL"
        case .copyMarkdownLink: "copyMarkdownLink"
        case .composeEmail: "composeEmail"
        case .callPhone: "callPhone"
        case .copySwiftColor: "copySwiftColor"
        case .revealInFinder: "revealInFinder"
        case .openFile: "openFile"
        case .copyPath: "copyPath"
        case .copyFile: "copyFile"
        case .openInTerminal: "openInTerminal"
        case .openInXcode: "openInXcode"
        case .openInMaps: "openInMaps"
        case .copyMathResult: "copyMathResult"
        case .copyPrettyJSON: "copyPrettyJSON"
        case .copyMinifiedJSON: "copyMinifiedJSON"
        case .copyEpochSeconds: "copyEpochSeconds"
        case .copyGitCloneURL: "copyGitCloneURL"
        case .openGitHub: "openGitHub"
        case .searchWeb: "searchWeb"
        case .translate: "translate"
        case .saveToDownloads: "saveToDownloads"
        case .copyAsPNG: "copyAsPNG"
        case .copyPlainText: "copyPlainText"
        case .copyHexColor: "copyHexColor"
        case .copyCSSRGB: "copyCSSRGB"
        case .copyUIColor: "copyUIColor"
        case .copyQR: "copyQR"
        case .pin: "pin"
        case .unpin: "unpin"
        }
    }

    var title: String {
        switch self {
        case .openURL:
            return "Open in Browser"
        case .copyMarkdownLink(let url):
            return url.isFileURL ? "Copy as Markdown Link" : "Copy Markdown Link"
        case .composeEmail:
            return "Compose Email"
        case .callPhone:
            return "Call with FaceTime"
        case .copySwiftColor:
            return "Copy Swift Color"
        case .revealInFinder:
            return "Reveal in Finder"
        case .openFile(let url):
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                return "Open in Finder"
            }
            return "Open"
        case .copyPath:
            return "Copy Path"
        case .copyFile:
            return "Copy File"
        case .openInTerminal:
            return "Open in Terminal"
        case .openInXcode:
            return "Open in Xcode"
        case .openInMaps:
            return "Open in Maps"
        case .copyMathResult:
            return "Copy Result"
        case .copyPrettyJSON:
            return "Pretty-Print JSON"
        case .copyMinifiedJSON:
            return "Minify JSON"
        case .copyEpochSeconds:
            return "Copy Epoch Seconds"
        case .copyGitCloneURL:
            return "Copy git clone URL"
        case .openGitHub:
            return "Open Repository"
        case .searchWeb:
            return "Search the Web"
        case .translate:
            return "Translate to English"
        case .saveToDownloads:
            return "Save to Downloads"
        case .copyAsPNG:
            return "Copy as PNG"
        case .copyPlainText:
            return "Copy as Plain Text"
        case .copyHexColor:
            return "Copy as Hex"
        case .copyCSSRGB:
            return "Copy as CSS rgb()"
        case .copyUIColor:
            return "Copy as UIColor"
        case .copyQR:
            return "Copy QR Code"
        case .pin:
            return "Pin to top"
        case .unpin:
            return "Unpin"
        }
    }

    var systemImage: String {
        switch self {
        case .openURL: "safari"
        case .copyMarkdownLink: "link"
        case .composeEmail: "envelope"
        case .callPhone: "phone"
        case .copySwiftColor: "swatchpalette"
        case .revealInFinder: "magnifyingglass"
        case .openFile: "arrow.up.forward.app"
        case .copyPath: "text.cursor"
        case .copyFile: "doc.on.doc"
        case .openInTerminal: "terminal"
        case .openInXcode: "hammer"
        case .openInMaps: "map"
        case .copyMathResult: "function"
        case .copyPrettyJSON, .copyMinifiedJSON: "curlybraces"
        case .copyEpochSeconds: "clock"
        case .copyGitCloneURL: "arrow.triangle.branch"
        case .openGitHub: "arrow.up.right.square"
        case .searchWeb: "globe"
        case .translate: "character.bubble"
        case .saveToDownloads: "square.and.arrow.down"
        case .copyAsPNG: "photo"
        case .copyPlainText: "doc.plaintext"
        case .copyHexColor: "number"
        case .copyCSSRGB: "paintbrush.pointed"
        case .copyUIColor: "paintbrush"
        case .copyQR: "qrcode"
        case .pin: "pin"
        case .unpin: "pin.slash"
        }
    }
    }

    /// How the panel behaves after running this action. Launching actions hand
    /// off to another app, which activates itself; copy actions dismiss the
    /// panel and return the user to the previous app so an immediate ⌘V lands
    /// there; background actions (saving a file) just close the panel.
    var dismissal: ActionDismissal {
        switch self {
        case .openURL, .composeEmail, .callPhone, .revealInFinder, .openFile,
             .openInTerminal, .openInXcode, .openInMaps, .openGitHub, .searchWeb:
            .launchApp
        case .copyMarkdownLink, .copySwiftColor, .copyPath, .copyFile,
             .copyMathResult, .copyPrettyJSON, .copyMinifiedJSON, .copyEpochSeconds,
             .copyGitCloneURL, .translate, .copyAsPNG, .copyPlainText,
             .copyHexColor, .copyCSSRGB, .copyUIColor, .copyQR:
            .restorePreviousApp
        case .saveToDownloads, .pin, .unpin:
            .justHide
        }
    }
}
