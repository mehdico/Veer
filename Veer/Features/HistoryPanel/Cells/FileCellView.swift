import AppKit
import QuickLookThumbnailing
import SwiftUI

struct FileCellView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    /// Off → no QuickLook thumbnail; icon, name and path only.
    var previewsEnabled: Bool = true
    let blobProvider: () -> Data?

    @State private var url: URL?
    @State private var icon: NSImage?
    @State private var thumbnail: NSImage?
    @State private var fileMissing = false

    private static let cache = NSCache<NSString, NSImage>()
    /// Icon lookup is a LaunchServices round-trip; cache per path so repeated
    /// appearances of a file row don't refetch it.
    private static let iconCache = NSCache<NSString, NSImage>()

    var body: some View {
        CellChrome(isSelected: isSelected, identifier: identifier, pinned: snapshot.pinned) {
            HStack(spacing: 10) {
                imageView
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 2) {
                    Text(url?.lastPathComponent ?? snapshot.preview ?? "(file)")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 6) {
                        Text(fileMissing
                             ? "File unavailable"
                             : (url?.deletingLastPathComponent().path ?? ""))
                            .lineLimit(1)
                            .truncationMode(.head)
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
                Spacer(minLength: 0)
            }
        }
        .task(id: "\(snapshot.id.uuidString)-\(previewsEnabled)") {
            await load()
        }
    }

    private var identifier: String {
        thumbnail != nil
            ? AccessibilityIdentifiers.veerFileThumbnailCellView
            : AccessibilityIdentifiers.veerFileIconCellView
    }

    @ViewBuilder
    private var imageView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail).resizable().scaledToFit()
        } else if let icon {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .opacity(fileMissing ? 0.35 : 1)
        } else {
            Image(systemName: "doc").resizable().scaledToFit().foregroundStyle(.secondary)
        }
    }

    private func load() async {
        fileMissing = false
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
        if !FileManager.default.fileExists(atPath: url.path) {
            fileMissing = true
            thumbnail = nil
            return
        }
        icon = Self.cachedIcon(for: url)
        guard previewsEnabled else {
            thumbnail = nil
            return
        }
        let key = "\(snapshot.id.uuidString)-36" as NSString
        if let cached = Self.cache.object(forKey: key) {
            thumbnail = cached
            return
        }
        let generated = await Self.makeThumbnail(for: url)
        if Task.isCancelled { return }
        thumbnail = generated
        if let generated {
            Self.cache.setObject(generated, forKey: key)
        }
    }

    private static func cachedIcon(for url: URL) -> NSImage {
        let key = url.path as NSString
        if let cached = iconCache.object(forKey: key) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        iconCache.setObject(icon, forKey: key)
        return icon
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
