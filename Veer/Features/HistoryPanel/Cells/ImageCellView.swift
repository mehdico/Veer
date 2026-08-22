import AppKit
import SwiftUI

struct ImageCellView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    let viewModel: HistoryListViewModel

    var body: some View {
        CellChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.veerTiffCellView, pinned: snapshot.pinned) {
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
                    metadataLine
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var metadataLine: some View {
        HStack(spacing: 6) {
            if let bundle = snapshot.sourceBundleId {
                Text(bundle)
            }
            if snapshot.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityIdentifier(AccessibilityIdentifiers.pinnedBadge)
            }
            Text(snapshot.relativeTimeLabel)
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
    }
}
