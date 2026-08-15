import AppKit
import SwiftUI

struct ImageCellView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    let viewModel: HistoryListViewModel

    var body: some View {
        CellChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.yippyTiffCellView) {
            HStack(spacing: 10) {
                if viewModel.previewsEnabled {
                    ClipThumbnailImage(clipID: snapshot.id) {
                        viewModel.thumbnailPNG(for: snapshot.id)
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
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
}
