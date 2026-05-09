import AppKit
import SwiftUI

struct TextCellView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool

    var body: some View {
        CellChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.yippyTextCellView) {
            HStack(alignment: .top, spacing: 10) {
                sourceIcon
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.preview ?? "(no preview)")
                        .font(.system(size: 13))
                        .lineLimit(3)
                        .truncationMode(.tail)
                    if let bundle = snapshot.sourceBundleId {
                        Text(sourceAppName(for: bundle))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var sourceIcon: some View {
        if let bundle = snapshot.sourceBundleId,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
        {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(.secondary)
        }
    }

    private func sourceAppName(for bundleId: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return Bundle(url: url)?.infoDictionary?["CFBundleName"] as? String ?? bundleId
        }
        return bundleId
    }
}
