import AppKit
import PDFKit
import QuickLookThumbnailing
import SwiftUI

private struct CardChrome<Content: View>: View {
    let isSelected: Bool
    let identifier: String
    let sourceBundleId: String?
    let timeLabel: String
    let pinned: Bool
    @State private var isHovered = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if let sourceBundleId {
                sourceHeader(sourceBundleId)
                    .padding(.bottom, 6)
            }
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack(spacing: 0) {
                Spacer()
                if pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.trailing, 3)
                        .accessibilityIdentifier(AccessibilityIdentifiers.pinnedBadge)
                }
                Text(timeLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                .fill(pinned ? Color.accentColor.opacity(0.12) : Color.primary.opacity(isHovered && !isSelected ? 0.05 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                .stroke(
                    LinearGradient(
                        colors: isSelected ? [Color.accentColor, Color.accentColor.opacity(0.5)] : [Color.white.opacity(0.2), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? 2 : Constants.UI.glassBorderWidth
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
        .shadow(color: isSelected ? Color.accentColor.opacity(0.4) : Color.black.opacity(0.1), radius: isSelected ? 12 : 4)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .onHover { isHovered = $0 }
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func sourceHeader(_ bundleId: String) -> some View {
        if let icon = SourceAppInfoCache.appIcon(for: bundleId) {
            HStack(spacing: 4) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
                Text(SourceAppInfoCache.appName(for: bundleId))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
        }
    }
}

struct TextCardView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    var highlightRanges: [Range<String.Index>] = []

    var body: some View {
        CardChrome(
            isSelected: isSelected,
            identifier: AccessibilityIdentifiers.veerTextCellView,
            sourceBundleId: snapshot.sourceBundleId,
            timeLabel: snapshot.relativeTimeLabel,
            pinned: snapshot.pinned
        ) {
            previewText
                .font(.system(size: 14))
                .lineLimit(nil)
        }
    }

    private var previewText: Text {
        let text = snapshot.preview ?? "(no preview)"
        guard !highlightRanges.isEmpty else { return Text(text) }
        return Text(AttributedString.highlighted(text, ranges: highlightRanges))
    }
}

struct RichTextCardView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    let blobProvider: () -> Data?
    var highlightRanges: [Range<String.Index>] = []

    @State private var attributed: AttributedString?

    private static let cache = NSCache<NSString, NSAttributedString>()

    var body: some View {
        CardChrome(
            isSelected: isSelected,
            identifier: AccessibilityIdentifiers.veerRichTextCellView,
            sourceBundleId: snapshot.sourceBundleId,
            timeLabel: snapshot.relativeTimeLabel,
            pinned: snapshot.pinned
        ) {
            if let attributed {
                Text(attributed)
                    .lineLimit(nil)
            } else {
                previewText
                    .font(.system(size: 14))
                    .lineLimit(nil)
            }
        }
        .task(id: snapshot.id) { await loadRTF() }
    }

    private var previewText: Text {
        let text = snapshot.preview ?? ""
        guard !highlightRanges.isEmpty else { return Text(text) }
        return Text(AttributedString.highlighted(text, ranges: highlightRanges))
    }

    private func loadRTF() async {
        let key = snapshot.id.uuidString as NSString
        if let cached = Self.cache.object(forKey: key) {
            attributed = AttributedString(cached)
            return
        }
        guard let data = blobProvider() else { return }
        // RTF import off the main actor, matching the list's rich-text cells.
        let ns = await Task.detached(priority: .utility) {
            try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
        }.value
        guard !Task.isCancelled, let ns else { return }
        Self.cache.setObject(ns, forKey: key)
        attributed = AttributedString(ns)
    }
}

struct ImageCardView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    let viewModel: HistoryListViewModel

    @State private var hasThumbnail = false

    var body: some View {
        CardChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.veerTiffCellView, sourceBundleId: snapshot.sourceBundleId, timeLabel: snapshot.relativeTimeLabel, pinned: snapshot.pinned) {
            if viewModel.previewsEnabled {
                ClipThumbnailImage(clipID: snapshot.id) {
                    viewModel.thumbnailPNG(for: snapshot.id)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(hasThumbnail ? 0 : 20)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Image")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: snapshot.id) {
            hasThumbnail = viewModel.thumbnailPNG(for: snapshot.id) != nil
        }
    }
}

struct ColorCardView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    /// Off → no swatch or decoding; an icon + label card.
    var previewsEnabled: Bool = true
    let blobProvider: () -> Data?
    /// Hex color text for text clips that are exactly a hex string;
    /// takes precedence over the pasteboard blob.
    var hexColorFallback: String?

    @State private var color: NSColor?
    @State private var hex: String?
    @State private var loaded = false

    var body: some View {
        CardChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.veerColorCellView, sourceBundleId: snapshot.sourceBundleId, timeLabel: snapshot.relativeTimeLabel, pinned: snapshot.pinned) {
            if previewsEnabled {
                ZStack(alignment: .bottomLeading) {
                    swatch
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    label
                        .padding(8)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Color")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: "\(snapshot.id.uuidString)-\(previewsEnabled)") {
            guard previewsEnabled else { return }
            loadColor()
        }
    }

    /// The color itself, with a visible edge (and a checkerboard behind
    /// translucent colors) so the swatch never blends into the card.
    @ViewBuilder
    private var swatch: some View {
        if let color {
            if color.alphaComponent < 1 {
                ColorContrastCheckerboard()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: color))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
                )
        }
    }

    /// Hex label on an opaque, adaptive backing so the text stays readable
    /// on any color.
    @ViewBuilder
    private var label: some View {
        if let color {
            let textColor = color.contrastingTextColor
            Text(hex ?? "color")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(textColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    textColor == .white ? Color.black.opacity(0.5) : Color.white.opacity(0.75),
                    in: RoundedRectangle(cornerRadius: 4)
                )
        } else {
            Text(loaded ? "Unknown color" : "color")
                .font(.system(.callout))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
        }
    }

    private func loadColor() {
        if let hexColorFallback, let nsColor = NSColor.fromHexString(hexColorFallback) {
            color = nsColor
            hex = ColorCellView.hexString(for: nsColor)
            loaded = true
            return
        }
        if let data = blobProvider(),
           let nsColor = NSColor.decodePasteboardColor(from: data)
        {
            color = nsColor
            hex = ColorCellView.hexString(for: nsColor)
            loaded = true
            return
        }
        loaded = true
    }
}

struct PdfCardView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    /// Off → no first-page thumbnail; icon + label only.
    var previewsEnabled: Bool = true
    let blobProvider: () -> Data?

    @State private var thumbnail: NSImage?

    private static let cache = NSCache<NSString, NSImage>()

    var body: some View {
        CardChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.veerPdfCellView, sourceBundleId: snapshot.sourceBundleId, timeLabel: snapshot.relativeTimeLabel, pinned: snapshot.pinned) {
            VStack(spacing: 6) {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "doc")
                        .resizable()
                        .scaledToFit()
                        .padding(24)
                        .foregroundStyle(.secondary)
                }
                Text("PDF")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: "\(snapshot.id.uuidString)-\(previewsEnabled)") {
            guard previewsEnabled else {
                thumbnail = nil
                return
            }
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let key = snapshot.id.uuidString as NSString
        if let cached = Self.cache.object(forKey: key) {
            thumbnail = cached
            return
        }
        guard let data = blobProvider() else { return }
        let decoded = await Task.detached(priority: .utility) { () -> NSImage? in
            guard let pdf = PDFDocument(data: data),
                  let page = pdf.page(at: 0)
            else { return nil }
            return page.thumbnail(of: NSSize(width: 256, height: 256), for: .mediaBox)
        }.value
        if Task.isCancelled { return }
        thumbnail = decoded
        if let decoded {
            Self.cache.setObject(decoded, forKey: key)
        }
    }
}

struct FileCardView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    /// Off → no QuickLook thumbnail or extension badge; icon, name and status only.
    var previewsEnabled: Bool = true
    let blobProvider: () -> Data?

    @State private var url: URL?
    @State private var icon: NSImage?
    @State private var thumbnail: NSImage?
    @State private var fileMissing = false

    private static let cache = NSCache<NSString, NSImage>()
    /// Icon lookup is a LaunchServices round-trip; cache per path so repeated
    /// appearances of a file card don't refetch it.
    private static let iconCache = NSCache<NSString, NSImage>()

    var body: some View {
        CardChrome(isSelected: isSelected, identifier: identifier, sourceBundleId: snapshot.sourceBundleId, timeLabel: snapshot.relativeTimeLabel, pinned: snapshot.pinned) {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    imageView
                    if previewsEnabled, let url, !url.pathExtension.isEmpty, !fileMissing {
                        Text(url.pathExtension.uppercased())
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(url?.lastPathComponent ?? "(file)")
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                if fileMissing {
                    Text("File unavailable")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: "\(snapshot.id.uuidString)-\(previewsEnabled)") { await load() }
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
            Image(systemName: fileMissing ? "exclamationmark.triangle" : "doc")
                .resizable()
                .scaledToFit()
                .padding(24)
                .foregroundStyle(.secondary)
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
        let key = "\(snapshot.id.uuidString)-192" as NSString
        if let cached = Self.cache.object(forKey: key) {
            thumbnail = cached
            return
        }
        let generated = await Self.makeThumbnail(for: url, side: 192)
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

    private static func makeThumbnail(for url: URL, side: CGFloat) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: NSSize(width: side, height: side),
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

@ViewBuilder
func clipCardView(
    snapshot: ClipItemSnapshot,
    isSelected: Bool,
    viewModel: HistoryListViewModel
) -> some View {
    if viewModel.previewsEnabled, let hexText = snapshot.colorHexText {
        ColorCardView(snapshot: snapshot, isSelected: isSelected, blobProvider: { nil }, hexColorFallback: hexText)
    } else {
        switch snapshot.kind {
        case .image:
            ImageCardView(snapshot: snapshot, isSelected: isSelected, viewModel: viewModel)
        case .pdf:
            PdfCardView(snapshot: snapshot, isSelected: isSelected, previewsEnabled: viewModel.previewsEnabled, blobProvider: {
                viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.pdf.rawValue)
            })
        case .color:
            ColorCardView(snapshot: snapshot, isSelected: isSelected, previewsEnabled: viewModel.previewsEnabled, blobProvider: {
                viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.color.rawValue)
            })
        case .file:
            FileCardView(snapshot: snapshot, isSelected: isSelected, previewsEnabled: viewModel.previewsEnabled, blobProvider: {
                viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.fileURL.rawValue)
            })
        case .richText:
            RichTextCardView(
                snapshot: snapshot,
                isSelected: isSelected,
                blobProvider: {
                    viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.rtf.rawValue)
                },
                highlightRanges: viewModel.highlights(for: snapshot)
            )
        case .text:
            TextCardView(
                snapshot: snapshot,
                isSelected: isSelected,
                highlightRanges: viewModel.highlights(for: snapshot)
            )
        }
    }
}
