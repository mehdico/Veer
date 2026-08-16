import AppKit
import SwiftUI

struct PreviewRootView: View {
    let viewModel: HistoryListViewModel
    @Bindable var coordinator: PreviewCoordinator

    /// Loaded payload per clip, fetched after layout (in `.task`) instead of
    /// synchronously inside `body`, so a cache miss never stalls SwiftUI on a
    /// large blob fetch. `loadedFor` gates rendering: stale data from the
    /// previously previewed clip is never shown for the new one.
    @State private var loadedFor: UUID?
    @State private var imageData: Data?
    @State private var pdfData: Data?
    @State private var colorData: Data?
    @State private var rtfData: Data?
    @State private var fileURL: URL?

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
        .task(id: coordinator.preview?.id) {
            if let snapshot = coordinator.preview {
                await load(for: snapshot)
            }
        }
    }

    @ViewBuilder
    private func content(for snapshot: ClipItemSnapshot) -> some View {
        switch snapshot.kind {
        case .image:
            if loaded(for: snapshot), let imageData {
                ImagePreview(clipID: snapshot.id, data: imageData)
            } else {
                loadingView
            }
        case .pdf:
            if loaded(for: snapshot), let pdfData {
                PdfPreview(data: pdfData)
            } else {
                loadingView
            }
        case .color:
            if loaded(for: snapshot), let colorData {
                ColorPreview(data: colorData)
            } else {
                loadingView
            }
        case .file:
            if loaded(for: snapshot), let fileURL {
                FilePreview(url: fileURL)
            } else {
                loadingView
            }
        case .richText:
            RichTextPreview(
                rtfData: loaded(for: snapshot) ? rtfData : nil,
                fallback: snapshot.preview
            )
        case .text:
            TextPreview(text: snapshot.preview ?? "")
        }
    }

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loaded(for snapshot: ClipItemSnapshot) -> Bool {
        loadedFor == snapshot.id
    }

    private func load(for snapshot: ClipItemSnapshot) async {
        loadedFor = nil
        switch snapshot.kind {
        case .image:
            imageData = viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.png.rawValue)
                ?? viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.tiff.rawValue)
        case .pdf:
            pdfData = viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.pdf.rawValue)
        case .color:
            colorData = viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.color.rawValue)
        case .richText:
            rtfData = viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.rtf.rawValue)
        case .file:
            fileURL = Self.fileURL(for: snapshot) { type in
                viewModel.blob(for: snapshot.id, type: type)
            }
        case .text:
            break
        }
        loadedFor = snapshot.id
    }

    private static func fileURL(
        for snapshot: ClipItemSnapshot,
        blob: (String) -> Data?
    ) -> URL? {
        guard let data = blob(NSPasteboard.PasteboardType.fileURL.rawValue),
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
