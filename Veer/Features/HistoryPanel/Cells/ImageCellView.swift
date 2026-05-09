import AppKit
import SwiftUI

struct ImageCellView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool

    var body: some View {
        CellChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.yippyTiffCellView) {
            HStack(spacing: 10) {
                thumbnail
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Image")
                        .font(.system(size: 13, weight: .medium))
                    if let bundle = snapshot.sourceBundleId {
                        Text(bundle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = snapshot.thumbnailPNG, let image = NSImage(data: data) {
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
}
