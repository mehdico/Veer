import SwiftUI

struct CellChrome<Content: View>: View {
    let isSelected: Bool
    let identifier: String
    let pinned: Bool
    @State private var isHovered = false
    @ViewBuilder let content: () -> Content

    init(isSelected: Bool, identifier: String, pinned: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.isSelected = isSelected
        self.identifier = identifier
        self.pinned = pinned
        self.content = content
    }

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
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: 4)
                            .padding(.vertical, 4)
                            .padding(.leading, 2)
                    } else if pinned {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.12))
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
