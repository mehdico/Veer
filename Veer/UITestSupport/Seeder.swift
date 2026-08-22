import AppKit
import Foundation

@MainActor
enum Seeder {
    static func seed(_ fixture: String, into repository: any ClipRepository) {
        switch fixture {
        case "mixed":
            insertText(repository: repository)
            insertRichText(repository: repository)
            insertImage(repository: repository)
            insertColor(repository: repository)
            insertFile(repository: repository)
            insertPdf(repository: repository)
        case "smartActions":
            insertText(repository: repository, text: "https://example.com/veer")
            insertText(repository: repository, text: "hello@example.com")
            insertText(repository: repository, text: "#FF5733")
        case "many":
            // Enough clips that the horizontal card strip can be scrolled well
            // past the first nine (where ⌘N badges would otherwise run out), so
            // UI tests can exercise the leading-card tracking fix.
            for i in 1...40 {
                insertText(repository: repository, text: "Clip number \(i)")
            }
        default:
            return
        }
    }

    private static func insertText(repository: any ClipRepository, text: String = "Plain text fixture") {
        let payload = ClipPayload(typed: [
            NSPasteboard.PasteboardType.string.rawValue: Data(text.utf8),
        ])
        _ = try? repository.insert(payload: payload, sourceBundleId: "com.apple.TextEdit")
    }

    private static func insertRichText(repository: any ClipRepository) {
        let attr = NSMutableAttributedString(string: "Bold rich text", attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
        guard let rtf = try? attr.data(
            from: NSRange(location: 0, length: attr.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else { return }
        let payload = ClipPayload(typed: [NSPasteboard.PasteboardType.rtf.rawValue: rtf])
        _ = try? repository.insert(payload: payload, sourceBundleId: "com.apple.TextEdit")
    }

    private static func insertImage(repository: any ClipRepository) {
        let image = NSImage(size: NSSize(width: 80, height: 80))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 80, height: 80).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return }
        let payload = ClipPayload(typed: [NSPasteboard.PasteboardType.png.rawValue: png])
        _ = try? repository.insert(payload: payload, sourceBundleId: "com.apple.Preview")
    }

    private static func insertColor(repository: any ClipRepository) {
        let color = NSColor.systemPurple
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true) else { return }
        let payload = ClipPayload(typed: [NSPasteboard.PasteboardType.color.rawValue: data])
        _ = try? repository.insert(payload: payload, sourceBundleId: "com.apple.dt.Xcode")
    }

    private static func insertFile(repository: any ClipRepository) {
        let url = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        let payload = ClipPayload(typed: [
            NSPasteboard.PasteboardType.fileURL.rawValue: Data(url.absoluteString.utf8),
        ])
        _ = try? repository.insert(payload: payload, sourceBundleId: "com.apple.Finder")
    }

    private static func insertPdf(repository: any ClipRepository) {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        let printInfo = NSPrintInfo.shared
        let pdfData = view.dataWithPDF(inside: view.bounds)
        let payload = ClipPayload(typed: [NSPasteboard.PasteboardType.pdf.rawValue: pdfData])
        _ = try? repository.insert(payload: payload, sourceBundleId: "com.apple.Preview")
        _ = printInfo
    }
}
