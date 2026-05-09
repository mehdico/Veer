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
        view.previewItem = url as (any QLPreviewItem)?
    }
}
