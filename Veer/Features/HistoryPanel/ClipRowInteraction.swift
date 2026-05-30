import SwiftUI

struct ClipRowInteraction<Content: View>: View {
    let index: Int
    let onSelect: () -> Void
    let onDoublePaste: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var lastTap: (index: Int, time: Date)?

    var body: some View {
        content()
            .contentShape(Rectangle())
            .onTapGesture {
                let now = Date()
                if let lastTap, lastTap.index == index, now.timeIntervalSince(lastTap.time) < 0.35 {
                    self.lastTap = nil
                    onDoublePaste()
                } else {
                    onSelect()
                    lastTap = (index, now)
                }
            }
    }
}
