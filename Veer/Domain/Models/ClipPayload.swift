import AppKit
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ClipPayload: Sendable, Equatable {
    var typed: [String: Data]

    nonisolated static let imageTypeKeys: [String] = [
        "public.png",
        "public.tiff",
        "public.jpeg",
        "public.heic",
        NSPasteboard.PasteboardType.png.rawValue,
        NSPasteboard.PasteboardType.tiff.rawValue,
    ]

    init(typed: [String: Data]) {
        self.typed = typed
    }

    var isEmpty: Bool { typed.isEmpty }

    var hasDenyListedType: Bool {
        let keys = Set(typed.keys)
        if !keys.isDisjoint(with: Constants.Pasteboard.alwaysRejectIfPresent) {
            return true
        }
        let contentKeys = keys.subtracting(Constants.Pasteboard.denylistedTypes)
        return contentKeys.isEmpty && !keys.isDisjoint(with: Constants.Pasteboard.denylistedTypes)
    }

    func digest() -> Data {
        var hasher = SHA256()
        for (key, data) in typed.sorted(by: { $0.key < $1.key }) {
            hasher.update(data: Data(key.utf8))
            if data.count > Constants.History.largePayloadBytes {
                var length = UInt64(data.count).bigEndian
                withUnsafeBytes(of: &length) { hasher.update(data: $0) }
                hasher.update(data: data.prefix(Constants.History.largePayloadDigestSampleBytes))
            } else {
                hasher.update(data: data)
            }
        }
        return Data(hasher.finalize())
    }

    func plainTextPreview(limit: Int = Constants.History.previewCharacterLimit) -> String? {
        for type in Self.plainTextTypeCandidates {
            if let data = typed[type], let text = String(data: data, encoding: .utf8) {
                return Self.truncate(text, limit: limit)
            }
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

    nonisolated func thumbnailPNG(maxEdge: CGFloat = Constants.History.thumbnailEdge) -> Data? {
        guard let imageData = Self.firstImageData(from: typed) else { return nil }
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
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

    nonisolated static func firstImageData(from typed: [String: Data]) -> Data? {
        for key in imageTypeKeys {
            if let data = typed[key], !data.isEmpty { return data }
        }
        return nil
    }

    private static let plainTextTypeCandidates = [
        NSPasteboard.PasteboardType.string.rawValue,
        "NSStringPboardType",
        "public.utf8-plain-text",
    ]

    private static func truncate(_ s: String, limit: Int) -> String {
        s.count <= limit ? s : String(s.prefix(limit))
    }
}
