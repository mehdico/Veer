import AppKit
import SwiftUI

@ViewBuilder
func clipCellView(
    snapshot: ClipItemSnapshot,
    isSelected: Bool,
    viewModel: HistoryListViewModel
) -> some View {
    let content: some View = Group {
        if viewModel.previewsEnabled, let hexText = snapshot.colorHexText {
            ColorCellView(snapshot: snapshot, isSelected: isSelected, blobProvider: { nil }, hexColorFallback: hexText)
        } else {
            switch snapshot.kind {
            case .image:
                ImageCellView(snapshot: snapshot, isSelected: isSelected, viewModel: viewModel)
            case .pdf:
                PdfCellView(snapshot: snapshot, isSelected: isSelected, previewsEnabled: viewModel.previewsEnabled, blobProvider: {
                    viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.pdf.rawValue)
                })
            case .color:
                ColorCellView(snapshot: snapshot, isSelected: isSelected, previewsEnabled: viewModel.previewsEnabled, blobProvider: {
                    viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.color.rawValue)
                })
            case .file:
                FileCellView(snapshot: snapshot, isSelected: isSelected, previewsEnabled: viewModel.previewsEnabled, blobProvider: {
                    viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.fileURL.rawValue)
                })
            case .richText:
                RichTextCellView(
                    snapshot: snapshot,
                    isSelected: isSelected,
                    blobProvider: {
                        viewModel.blob(for: snapshot.id, type: NSPasteboard.PasteboardType.rtf.rawValue)
                    },
                    highlightRanges: viewModel.highlights(for: snapshot)
                )
            case .text:
                TextCellView(
                    snapshot: snapshot,
                    isSelected: isSelected,
                    highlightRanges: viewModel.highlights(for: snapshot)
                )
            }
        }
    }
    content
        .overlay(alignment: .topLeading) {
            if snapshot.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .accessibilityIdentifier(AccessibilityIdentifiers.pinnedBadge)
            }
        }
}

/// Right-click menu for a clip: a Smart Actions submenu listing the detected
/// actions (mouse users don't have to discover the keyboard strip), plus
/// Delete.
@ViewBuilder
func clipContextMenu(snapshot: ClipItemSnapshot, viewModel: HistoryListViewModel) -> some View {
    let actions = viewModel.actions(for: snapshot)
    if !actions.isEmpty {
        Menu("Smart Actions") {
            ForEach(actions) { action in
                Button {
                    viewModel.run(action)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
        }
    }
    Button("Delete", role: .destructive) {
        viewModel.delete(snapshot)
    }
}
