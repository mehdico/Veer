import AppKit
import QuickLookThumbnailing
import SwiftUI

struct FileCellView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    let blobProvider: () -> Data?

    @State private var url: URL?
    @State private var icon: NSImage?
    @State private var thumbnail: NSImage?

    var body: some View {
        CellChrome(isSelected: isSelected, identifier: identifier) {
            HStack(spacing: 10) {
                imageView
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 2) {
                    Text(url?.lastPathComponent ?? snapshot.preview ?? "(file)")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(url?.deletingLastPathComponent().path ?? "")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Spacer(minLength: 0)
            }
        }
        .task(id: snapshot.id) {
            await load()
        }
    }

    private var identifier: String {
        thumbnail != nil
            ? AccessibilityIdentifiers.yippyFileThumbnailCellView
            : AccessibilityIdentifiers.yippyFileIconCellView
    }

    @ViewBuilder
    private var imageView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail).resizable().scaledToFit()
        } else if let icon {
            Image(nsImage: icon).resizable().scaledToFit()
        } else {
            Image(systemName: "doc").resizable().scaledToFit().foregroundStyle(.secondary)
        }
    }

    private func load() async {
        guard let data = blobProvider(),
              let str = String(data: data, encoding: .utf8)
        else { return }
        let parsed: URL?
        if str.hasPrefix("file://") {
            parsed = URL(string: str)
        } else if str.hasPrefix("/") {
            parsed = URL(fileURLWithPath: str)
        } else {
            parsed = URL(string: str)
        }
        guard let url = parsed else { return }
        self.url = url
        icon = NSWorkspace.shared.icon(forFile: url.path)
        thumbnail = await Self.makeThumbnail(for: url)
    }

    private static func makeThumbnail(for url: URL) async -> NSImage? {
        let size = NSSize(width: 36, height: 36)
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
                continuation.resume(returning: rep?.nsImage)
            }
        }
    }
}
