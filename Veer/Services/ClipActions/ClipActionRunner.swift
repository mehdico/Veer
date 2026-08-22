import AppKit
import CoreImage
import Foundation
import Translation

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
    private let downloadsDirectory: URL

    init(
        pasteboardWriter: any PasteboardWriting,
        workspace: NSWorkspace = .shared,
        downloadsDirectory: URL? = nil
    ) {
        self.pasteboardWriter = pasteboardWriter
        self.workspace = workspace
        self.downloadsDirectory = downloadsDirectory ?? Self.defaultDownloadsDirectory()
    }

    func run(_ action: ClipAction) {
        switch action {
        // Web & contact
        case .openURL(let url):
            workspace.open(url)
        case .copyMarkdownLink(let url):
            if url.isFileURL {
                copyText("[\(url.lastPathComponent)](\(url.path))")
            } else {
                copyText("[\(url.absoluteString)](\(url.absoluteString))")
            }
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

        // Files & folders
        case .revealInFinder(let url):
            workspace.activateFileViewerSelecting([url])
        case .openFile(let url):
            workspace.open(url)
        case .copyPath(let url):
            copyText(url.path)
        case .copyFile(let url):
            pasteboardWriter.write(typed: [
                NSPasteboard.PasteboardType.fileURL.rawValue: Data(url.absoluteString.utf8),
                NSPasteboard.PasteboardType.string.rawValue: Data(url.path.utf8),
            ])
        case .openInTerminal(let url):
            let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            openInApp(url, application: terminal, fallbackToDefault: true)
        case .openInXcode(let url):
            let xcode = URL(fileURLWithPath: "/Applications/Xcode.app")
            openInApp(url, application: xcode, fallbackToDefault: true)

        // Text & data
        case .openInMaps(let latitude, let longitude):
            var components = URLComponents()
            components.scheme = "http"
            components.host = "maps.apple.com"
            components.queryItems = [URLQueryItem(name: "ll", value: "\(latitude),\(longitude)")]
            if let url = components.url {
                workspace.open(url)
            }
        case .copyMathResult(let result):
            copyText(result)
        case .copyPrettyJSON(let json), .copyMinifiedJSON(let json):
            copyText(json)
        case .copyEpochSeconds(let epoch):
            copyText(epoch)
        case .copyGitCloneURL(let cloneURL):
            copyText(cloneURL)
        case .openGitHub(let url):
            workspace.open(url)
        case .searchWeb(let query):
            var components = URLComponents()
            components.scheme = "https"
            components.host = "www.google.com"
            components.path = "/search"
            components.queryItems = [URLQueryItem(name: "q", value: query)]
            if let url = components.url {
                workspace.open(url)
            }
        case .translate(let text, let sourceLanguage):
            // Translation is async and may need to download a language pack;
            // the result is copied to the pasteboard when it arrives.
            Task { await Self.translateAndCopy(
                text,
                sourceLanguage: sourceLanguage,
                pasteboardWriter: pasteboardWriter
            ) }

        // Rich media
        case .saveToDownloads(let source, let fileExtension, let suggestedName):
            saveToDownloads(source: source, fileExtension: fileExtension, suggestedName: suggestedName)
        case .copyAsPNG(let source):
            copyAsPNG(source: source)
        case .copyPlainText(let text):
            copyText(text)
        case .copyHexColor(let hex):
            copyText(hex)
        case .copyCSSRGB(let red, let green, let blue):
            copyText("rgb(\(red), \(green), \(blue))")
        case .copyUIColor(let red, let green, let blue, let alpha):
            copyText(Self.uiColorSnippet(red: red, green: green, blue: blue, alpha: alpha))
        case .copyQR(let text):
            copyQRCode(text)
        case .pin, .unpin:
            // Pinning is handled by the view model (re-sorts history) and never
            // reaches the action runner.
            break
        }
    }

    // MARK: - Helpers

    private func copyText(_ text: String) {
        pasteboardWriter.write(typed: [NSPasteboard.PasteboardType.string.rawValue: Data(text.utf8)])
    }

    private func openInApp(_ url: URL, application appURL: URL, fallbackToDefault: Bool) {
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            if fallbackToDefault {
                workspace.open(url)
            }
            return
        }
        workspace.open([url], withApplicationAt: appURL, configuration: .init()) { _, error in
            if let error {
                VeerLogger(category: .general).error("Open with \(appURL.lastPathComponent) failed", error)
            }
        }
    }

    private func saveToDownloads(source: ClipContentSource, fileExtension: String, suggestedName: String?) {
        let data: Data?
        switch source {
        case .data(let inline): data = inline
        case .file(let url): data = try? Data(contentsOf: url)
        }
        guard let data else { return }
        let base: String
        if let suggestedName, !suggestedName.isEmpty {
            base = suggestedName
        } else {
            base = "Veer clip"
        }
        var url = downloadsDirectory.appendingPathComponent("\(base).\(fileExtension)")
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = downloadsDirectory.appendingPathComponent("\(base) \(counter).\(fileExtension)")
            counter += 1
        }
        do {
            // Atomic: a crash or full disk mid-write must not leave a truncated
            // file that satisfies the existence check above and blocks retries.
            try data.write(to: url, options: .atomic)
            VeerLogger(category: .general).info("Saved clip to \(url.path)")
        } catch {
            VeerLogger(category: .general).error("Save to Downloads failed", error)
        }
    }

    private func copyAsPNG(source: ClipContentSource) {
        let data: Data?
        switch source {
        case .data(let inline): data = inline
        case .file(let url): data = try? Data(contentsOf: url)
        }
        guard let data,
              let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return }
        pasteboardWriter.write(typed: [NSPasteboard.PasteboardType.png.rawValue: png])
    }

    /// Translates text and writes the result to the pasteboard. Runs on the
    /// main actor; failures are logged and leave the pasteboard untouched.
    /// The action is only offered for installed language packs, but this stays
    /// defensive: unsupported pairs and machines where packs can't be
    /// downloaded fail gracefully instead of crashing.
    private static func translateAndCopy(
        _ text: String,
        sourceLanguage: String,
        pasteboardWriter: any PasteboardWriting
    ) async {
        guard #available(macOS 26.0, *) else {
            VeerLogger(category: .general).warning("Translation requires macOS 26")
            return
        }
        let source = Locale.Language(identifier: sourceLanguage)
        let target = Locale.Language(identifier: "en")
        let status = await LanguageAvailability().status(from: source, to: target)
        guard status != .unsupported else {
            VeerLogger(category: .general).warning("Translation unsupported for \(sourceLanguage)")
            return
        }
        let session = TranslationSession(installedSource: source, target: target)
        do {
            if status == .supported {
                // Model not installed; some systems can download it on demand.
                try await session.prepareTranslation()
            }
            let response = try await session.translate(text)
            pasteboardWriter.write(
                typed: [NSPasteboard.PasteboardType.string.rawValue: Data(response.targetText.utf8)]
            )
        } catch {
            VeerLogger(category: .general).error(
                "Translation failed (pack for \(sourceLanguage) not installed?)", error
            )
        }
    }

    private static func defaultDownloadsDirectory() -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
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

    /// Renders RGBA components as a `UIColor` snippet for iOS code.
    static func uiColorSnippet(red: Double, green: Double, blue: Double, alpha: Double) -> String {
        String(
            format: "UIColor(red: %.3f, green: %.3f, blue: %.3f, alpha: %.3f)",
            locale: Locale(identifier: "en_US_POSIX"), red, green, blue, alpha
        )
    }

    /// Builds a QR code PNG for `text` and copies it to the pasteboard, so the
    /// clip's content can be scanned from a phone or shared as an image.
    private func copyQRCode(_ text: String) {
        guard let png = Self.qrPNG(from: text) else { return }
        pasteboardWriter.write(typed: [NSPasteboard.PasteboardType.png.rawValue: png])
    }

    /// Renders `text` to a QR code and returns a scaled, opaque PNG. Returns nil
    /// when CoreImage can't build the generator (e.g. empty input).
    static func qrPNG(from text: String) -> Data? {
        guard !text.isEmpty,
              let data = text.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator")
        else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = ciImage.transformed(by: transform)
        let rep = NSBitmapImageRep(ciImage: scaled)
        return rep.representation(using: .png, properties: [:])
    }
}
