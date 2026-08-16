import AppKit
import SwiftUI

struct TextPreview: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.body, design: .default))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}

struct RichTextPreview: NSViewRepresentable {
    let rtfData: Data?
    let fallback: String?

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        if let textView = scroll.documentView as? NSTextView {
            textView.isEditable = false
            textView.isSelectable = true
            textView.drawsBackground = false
            textView.textContainerInset = NSSize(width: 12, height: 12)
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        // Guard against re-applying unchanged content: replacing the whole
        // text storage on every SwiftUI update also resets scroll position.
        if let data = rtfData {
            guard context.coordinator.lastData != data else { return }
            context.coordinator.lastData = data
            context.coordinator.lastFallback = nil
            if let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
                textView.textStorage?.setAttributedString(attr)
            } else if let fallback {
                textView.string = fallback
            }
        } else if let fallback {
            guard context.coordinator.lastFallback != fallback else { return }
            context.coordinator.lastFallback = fallback
            context.coordinator.lastData = nil
            textView.string = fallback
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastData: Data?
        var lastFallback: String?
    }
}
