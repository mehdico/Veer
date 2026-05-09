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
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityIdentifier(identifier)
            .animation(.none, value: isSelected)
    }
}
