import AppKit
import SwiftUI

struct ImagePreview: View {
    let clipID: UUID
    let data: Data?

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Text("Unable to render image")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .task(id: clipID) {
            if let data {
                image = await Task.detached(priority: .utility) {
                    NSImage(data: data)
                }.value
            } else {
                image = nil
            }
        }
    }
}
