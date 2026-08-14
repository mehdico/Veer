import AppKit
import SwiftUI

struct ClipThumbnailImage: View {
    let clipID: UUID
    let pngProvider: () -> Data?

    @State private var image: NSImage?

    private static let cache = NSCache<NSString, NSImage>()

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: clipID) {
            let key = clipID.uuidString as NSString
            if let cached = Self.cache.object(forKey: key) {
                image = cached
                return
            }
            guard let pngData = pngProvider() else {
                image = nil
                return
            }
            let decoded = await Task.detached(priority: .utility) {
                NSImage(data: pngData)
            }.value
            if !Task.isCancelled {
                image = decoded
                if let decoded {
                    Self.cache.setObject(decoded, forKey: key)
                }
            }
        }
    }
}
