import AppKit
import PDFKit
import QuickLookThumbnailing
import SwiftUI

private struct CardChrome<Content: View>: View {
    let isSelected: Bool
    let identifier: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(10)
            .background(.ultraThinMaterial)
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
            .accessibilityIdentifier(identifier)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

private func sourceFooter(_ bundleId: String?) -> some View {
    Group {
        if let bundleId,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            HStack(spacing: 4) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 14, height: 14)
                Text(Bundle(url: url)?.infoDictionary?["CFBundleName"] as? String ?? bundleId)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            EmptyView()
        }
    }
}

struct TextCardView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool

    var body: some View {
        CardChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.yippyTextCellView) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.preview ?? "(no preview)")
                    .font(.system(size: 14))
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                sourceFooter(snapshot.sourceBundleId)
            }
        }
    }
}

struct RichTextCardView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    let blobProvider: () -> Data?

    @State private var attributed: AttributedString?

    var body: some View {
        CardChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.yippyRichTextCellView) {
            VStack(alignment: .leading, spacing: 8) {
                if let attributed {
                    Text(attributed)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    Text(snapshot.preview ?? "")
                        .font(.system(size: 14))
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                sourceFooter(snapshot.sourceBundleId)
            }
        }
        .task(id: snapshot.id) { loadRTF() }
    }

    private func loadRTF() {
        guard let data = blobProvider(),
              let ns = try? NSAttributedString(
                  data: data,
                  options: [.documentType: NSAttributedString.DocumentType.rtf],
                  documentAttributes: nil
              )
        else { return }
        attributed = AttributedString(ns)
    }
}

struct ImageCardView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool

    var body: some View {
        CardChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.yippyTiffCellView) {
            VStack(spacing: 6) {
                if let data = snapshot.thumbnailPNG, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.medium)
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .foregroundStyle(.secondary)
                }
                sourceFooter(snapshot.sourceBundleId)
            }
        }
    }
}

struct ColorCardView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    let blobProvider: () -> Data?

    @State private var color: NSColor?
    @State private var hex: String?

    var body: some View {
        CardChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.yippyColorCellView) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.map { Color(nsColor: $0) } ?? Color.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(hex ?? "color")
                    .font(.system(.callout, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(8)
            }
        }
        .task(id: snapshot.id) { loadColor() }
    }

    private func loadColor() {
        guard let data = blobProvider() else { return }
        if let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            color = nsColor
            hex = ColorCellView.hexString(for: nsColor)
        }
    }
}

struct PdfCardView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    let blobProvider: () -> Data?

    @State private var thumbnail: NSImage?

    var body: some View {
        CardChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.yippyPdfCellView) {
            VStack(spacing: 6) {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "doc.richtext")
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
        .task(id: snapshot.id) { loadThumbnail() }
    }

    private func loadThumbnail() {
        guard let data = blobProvider(),
              let pdf = PDFDocument(data: data),
              let page = pdf.page(at: 0)
        else { return }
        thumbnail = page.thumbnail(of: NSSize(width: 256, height: 256), for: .mediaBox)
    }
}

struct FileCardView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    let blobProvider: () -> Data?

    @State private var url: URL?
    @State private var icon: NSImage?
    @State private var thumbnail: NSImage?

    var body: some View {
        CardChrome(isSelected: isSelected, identifier: identifier) {
            VStack(spacing: 6) {
                imageView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(url?.lastPathComponent ?? "(file)")
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: snapshot.id) { await load() }
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
            Image(systemName: "doc")
                .resizable()
                .scaledToFit()
                .padding(24)
                .foregroundStyle(.secondary)
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
        thumbnail = await Self.makeThumbnail(for: url, side: 192)
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
    switch snapshot.kind {
    case .image:
        ImageCardView(snapshot: snapshot, isSelected: isSelected)
    case .pdf:
        PdfCardView(snapshot: snapshot, isSelected: isSelected, blobProvider: {
            viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.pdf.rawValue)
        })
    case .color:
        ColorCardView(snapshot: snapshot, isSelected: isSelected, blobProvider: {
            viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.color.rawValue)
        })
    case .file:
        FileCardView(snapshot: snapshot, isSelected: isSelected, blobProvider: {
            viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.fileURL.rawValue)
        })
    case .richText:
        RichTextCardView(snapshot: snapshot, isSelected: isSelected, blobProvider: {
            viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.rtf.rawValue)
        })
    case .text:
        TextCardView(snapshot: snapshot, isSelected: isSelected)
    }
}
