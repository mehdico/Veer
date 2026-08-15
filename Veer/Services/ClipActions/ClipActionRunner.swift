import AppKit
import Foundation

@MainActor
protocol ClipActionRunning: AnyObject {
    func run(_ action: ClipAction)
}

/// Executes smart actions: hands off to other apps via NSWorkspace for
/// launching actions, and writes transformed text to the pasteboard for copy
/// actions. Copy writes go through the injected `PasteboardWriting` so the
/// pasteboard monitor acknowledges them and doesn't re-ingest them as clips.
@MainActor
final class LiveClipActionRunner: ClipActionRunning {
    private let pasteboardWriter: any PasteboardWriting
    private let workspace: NSWorkspace

    init(pasteboardWriter: any PasteboardWriting, workspace: NSWorkspace = .shared) {
        self.pasteboardWriter = pasteboardWriter
        self.workspace = workspace
    }

    func run(_ action: ClipAction) {
        switch action {
        case .openURL(let url):
            workspace.open(url)
        case .copyMarkdownLink(let url):
            copyText("[\(url.absoluteString)](\(url.absoluteString))")
        case .composeEmail(let address):
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = address
            if let url = components.url {
                workspace.open(url)
            }
        case .callPhone(let raw):
            let digits = raw.filter(\.isNumber)
            let normalized = raw.hasPrefix("+") ? "+\(digits)" : digits
            if let url = URL(string: "tel:\(normalized)") {
                workspace.open(url)
            }
        case .copySwiftColor(let hex):
            copyText(Self.swiftColorSnippet(hex: hex))
        }
    }

    private func copyText(_ text: String) {
        pasteboardWriter.write(typed: [NSPasteboard.PasteboardType.string.rawValue: Data(text.utf8)])
    }

    /// Renders a hex color (3, 6 or 8 digits) as a SwiftUI `Color` snippet,
    /// e.g. `FF5733` → `Color(red: 1.000, green: 0.341, blue: 0.200)`.
    static func swiftColorSnippet(hex: String) -> String {
        let core: String = hex.count == 3 ? hex.map { "\($0)\($0)" }.joined() : hex
        guard core.count == 6 || core.count == 8 else { return hex }
        func component(_ offset: Int) -> Double {
            let start = core.index(core.startIndex, offsetBy: offset)
            let end = core.index(start, offsetBy: 2)
            let byte = Int(core[start..<end], radix: 16) ?? 0
            return Double(byte) / 255.0
        }
        let r = component(0)
        let g = component(2)
        let b = component(4)
        if core.count == 8 {
            let a = component(6)
            return String(
                format: "Color(red: %.3f, green: %.3f, blue: %.3f, opacity: %.3f)",
                locale: Locale(identifier: "en_US_POSIX"), r, g, b, a
            )
        }
        return String(
            format: "Color(red: %.3f, green: %.3f, blue: %.3f)",
            locale: Locale(identifier: "en_US_POSIX"), r, g, b
        )
    }
}
