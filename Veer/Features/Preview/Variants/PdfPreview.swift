import AppKit
import PDFKit
import SwiftUI

struct PdfPreview: NSViewRepresentable {
    let data: Data?

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if let data {
            guard data != context.coordinator.lastData else { return }
            context.coordinator.lastData = data
            view.document = PDFDocument(data: data)
        } else {
            guard context.coordinator.lastData != nil else { return }
            context.coordinator.lastData = nil
            view.document = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastData: Data?
    }
}
