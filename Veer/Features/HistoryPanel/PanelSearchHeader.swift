import SwiftUI

struct PanelSearchChrome: View {
    let searchText: String

    var body: some View {
        Group {
            if !searchText.isEmpty {
                PanelSearchBar(text: searchText)
            }
        }
        // Appears/disappears instantly, in the same frame the panel window is
        // resized by PanelWindowController — so the list below never changes
        // size. (Animated heights on both sides desynced and re-laid the list
        // every frame, which was the visible glitch.)
        .frame(height: searchText.isEmpty ? 0 : Constants.Panel.searchBarHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("panelSearchField")
        .accessibilityLabel(searchText.isEmpty ? "Type to search" : "Search, \(searchText)")
        .accessibilityAddTraits(.isSearchField)
    }
}

struct PanelSearchBar: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(text)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: Constants.UI.glassBorderWidth)
        )
        .padding(.horizontal, 8)
        .padding(.top, 5)
    }
}
