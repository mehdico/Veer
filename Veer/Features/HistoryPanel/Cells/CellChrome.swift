import SwiftUI

struct CellChrome<Content: View>: View {
    let isSelected: Bool
    let identifier: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier(identifier)
            .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
}
