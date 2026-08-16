import SwiftUI

struct CellChrome<Content: View>: View {
    let isSelected: Bool
    let identifier: String
    @State private var isHovered = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack(alignment: .leading) {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.22))
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor, lineWidth: 2)
                        // Solid leading bar so the selected row stays visible
                        // even with low-contrast system accent colors.
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: 4)
                            .padding(.vertical, 4)
                            .padding(.leading, 2)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.06))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 0)
            .onHover { isHovered = $0 }
            .accessibilityIdentifier(identifier)
    }
}
