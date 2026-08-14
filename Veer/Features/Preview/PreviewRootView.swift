import AppKit
import SwiftUI

struct PreviewRootView: View {
    let viewModel: HistoryListViewModel
    @Bindable var coordinator: PreviewCoordinator

    var body: some View {
        Group {
            if let snapshot = coordinator.preview {
                content(for: snapshot)
            } else {
                Text("No selection")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    @ViewBuilder
    private func content(for snapshot: ClipItemSnapshot) -> some View {
        switch snapshot.kind {
        case .image:
            ImagePreview(clipID: snapshot.id, data: blobForImage(snapshot))
        case .pdf:
            PdfPreview(data: viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.pdf.rawValue))
        case .color:
            ColorPreview(data: viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.color.rawValue))
        case .file:
            FilePreview(url: fileURL(snapshot))
        case .richText:
            RichTextPreview(
                rtfData: viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.rtf.rawValue),
                fallback: snapshot.preview
            )
        case .text:
            TextPreview(text: snapshot.preview ?? "")
        }
    }

    private func blobForImage(_ snapshot: ClipItemSnapshot) -> Data? {
        viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.png.rawValue)
            ?? viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.tiff.rawValue)
    }

    private func fileURL(_ snapshot: ClipItemSnapshot) -> URL? {
        guard let data = viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.fileURL.rawValue),
              let raw = String(data: data, encoding: .utf8)
        else { return nil }
        if raw.hasPrefix("file://") {
            return URL(string: raw)
        } else if raw.hasPrefix("/") {
            return URL(fileURLWithPath: raw)
        } else {
            return URL(string: raw)
        }
    }
}
