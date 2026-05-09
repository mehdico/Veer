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
            view.document = PDFDocument(data: data)
        } else {
            view.document = nil
        }
    }
}
