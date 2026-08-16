import SwiftUI

/// The panel's search chrome. A real, always-present TextField (kept at zero
/// height while the query is empty, in the same frame the panel window is
/// resized by PanelWindowController) owns keyboard focus, so typing gets a
/// caret, selection, and IME for free. Navigation keys never reach it —
/// PanelKeyHandler on the panel container intercepts them first and only
/// passes plain typing through (`.ignored`).
struct PanelSearchChrome: View {
    @Binding var searchText: String
    let focused: FocusState<Bool>.Binding

    var body: some View {
        PanelSearchBar(text: $searchText, focused: focused)
            // Appears/disappears instantly, in the same frame the panel window is
            // resized by PanelWindowController — so the list below never changes
            // size. (Animated heights on both sides desynced and re-laid the list
            // every frame, which was the visible glitch.)
            .frame(height: searchText.isEmpty ? 0 : Constants.Panel.searchBarHeight)
            .clipped()
            .allowsHitTesting(!searchText.isEmpty)
            .accessibilityIdentifier(AccessibilityIdentifiers.panelSearchField)
            .accessibilityLabel(searchText.isEmpty ? "Type to search" : "Search, \(searchText)")
    }
}

struct PanelSearchBar: View {
    @Binding var text: String
    let focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused(focused)
                .focusEffectDisabled()
                .labelsHidden()
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityIdentifier(AccessibilityIdentifiers.panelSearchClearButton)
            }
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
