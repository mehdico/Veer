import AppKit
import SwiftUI

struct ClipThumbnailImage: View {
    let pngData: Data?
    @State private var image: NSImage?

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
        .task(id: pngData) {
            guard let pngData else {
                image = nil
                return
            }
            let decoded = await Task.detached(priority: .utility) {
                NSImage(data: pngData)
            }.value
            if !Task.isCancelled {
                image = decoded
            }
        }
    }
}
