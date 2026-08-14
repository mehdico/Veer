import AppKit
import Quartz
import SwiftUI

struct FilePreview: NSViewRepresentable {
    let url: URL?

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)
        view?.shouldCloseWithWindow = false
        return view ?? QLPreviewView()
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        guard url != context.coordinator.lastURL else { return }
        context.coordinator.lastURL = url
        view.previewItem = url as (any QLPreviewItem)?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastURL: URL?
    }
}
