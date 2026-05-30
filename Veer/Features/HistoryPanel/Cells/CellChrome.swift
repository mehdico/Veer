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
            .background(
                ZStack {
                    if isSelected {
                        Color.accentColor.opacity(0.2)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 0)
            .accessibilityIdentifier(identifier)
    }
}
