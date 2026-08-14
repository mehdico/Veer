import AppKit
import SwiftUI

@ViewBuilder
func clipCellView(
    snapshot: ClipItemSnapshot,
    isSelected: Bool,
    viewModel: HistoryListViewModel
) -> some View {
    switch snapshot.kind {
    case .image:
        ImageCellView(snapshot: snapshot, isSelected: isSelected, viewModel: viewModel)
    case .pdf:
        PdfCellView(snapshot: snapshot, isSelected: isSelected, blobProvider: {
            viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.pdf.rawValue)
        })
    case .color:
        ColorCellView(snapshot: snapshot, isSelected: isSelected, blobProvider: {
            viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.color.rawValue)
        })
    case .file:
        FileCellView(snapshot: snapshot, isSelected: isSelected, blobProvider: {
            viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.fileURL.rawValue)
        })
    case .richText:
        RichTextCellView(snapshot: snapshot, isSelected: isSelected, blobProvider: {
            viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.rtf.rawValue)
        })
    case .text:
        TextCellView(snapshot: snapshot, isSelected: isSelected)
    }
}
