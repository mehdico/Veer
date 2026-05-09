import AppKit
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ClipPayload: Sendable, Equatable {
    var typed: [String: Data]

    init(typed: [String: Data]) {
        self.typed = typed
    }

    var isEmpty: Bool { typed.isEmpty }

    var hasDenyListedType: Bool {
        !Constants.Pasteboard.denylistedTypes.isDisjoint(with: typed.keys)
    }

    func digest() -> Data {
        var hasher = SHA256()
        for (key, data) in typed.sorted(by: { $0.key < $1.key }) {
            hasher.update(data: Data(key.utf8))
            hasher.update(data: data)
        }
        return Data(hasher.finalize())
    }

    func plainTextPreview(limit: Int = Constants.History.previewCharacterLimit) -> String? {
        if let data = typed[NSPasteboard.PasteboardType.string.rawValue],
           let text = String(data: data, encoding: .utf8)
        {
            return Self.truncate(text, limit: limit)
        }
        if let data = typed[NSPasteboard.PasteboardType.rtf.rawValue],
           let attr = try? NSAttributedString(data: data, options: [:], documentAttributes: nil)
        {
            return Self.truncate(attr.string, limit: limit)
        }
        if let data = typed[NSPasteboard.PasteboardType.html.rawValue],
           let attr = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
           )
        {
            return Self.truncate(attr.string, limit: limit)
        }
        if let data = typed[NSPasteboard.PasteboardType.URL.rawValue],
           let url = String(data: data, encoding: .utf8)
        {
            return Self.truncate(url, limit: limit)
        }
        return nil
    }

    nonisolated func thumbnailPNG(maxEdge: CGFloat = 64) -> Data? {
        let imageData = typed["public.png"] ?? typed["public.tiff"]
        guard let imageData,
              let source = CGImageSourceCreateWithData(imageData as CFData, nil)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxEdge),
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, thumb, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    private static func truncate(_ s: String, limit: Int) -> String {
        s.count <= limit ? s : String(s.prefix(limit))
    }
}
