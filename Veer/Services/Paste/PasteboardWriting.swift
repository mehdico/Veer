import AppKit

@MainActor
protocol PasteboardWriting: AnyObject {
    func write(typed: [String: Data])
}

@MainActor
final class LivePasteboardWriter: PasteboardWriting {
    private let pasteboard: NSPasteboard
    var onWrite: ((Int) -> Void)?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func write(typed: [String: Data]) {
        pasteboard.clearContents()
        for (type, data) in typed {
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType(rawValue: type))
        }
        onWrite?(pasteboard.changeCount)
    }
}
