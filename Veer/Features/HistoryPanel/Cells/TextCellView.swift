import AppKit
import SwiftUI

struct TextCellView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    /// Ranges of the search query inside the preview, highlighted to show why
    /// the clip matched. Empty when not searching or when nothing matched.
    var highlightRanges: [Range<String.Index>] = []

    var body: some View {
        CellChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.yippyTextCellView) {
            HStack(alignment: .top, spacing: 10) {
                sourceIcon
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    previewText
                        .font(.system(size: 13))
                        .lineLimit(3)
                        .truncationMode(.tail)
                    metadataLine
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var previewText: Text {
        let text = snapshot.preview ?? "(no preview)"
        guard !highlightRanges.isEmpty else { return Text(text) }
        return Text(AttributedString.highlighted(text, ranges: highlightRanges))
    }

    private var metadataLine: some View {
        HStack(spacing: 6) {
            if let bundle = snapshot.sourceBundleId {
                Text(sourceAppName(for: bundle))
            }
            Text(snapshot.relativeTimeLabel)
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var sourceIcon: some View {
        if let bundle = snapshot.sourceBundleId,
           let icon = SourceAppInfoCache.appIcon(for: bundle)
        {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(.secondary)
        }
    }

    private func sourceAppName(for bundleId: String) -> String {
        SourceAppInfoCache.appName(for: bundleId)
    }
}
