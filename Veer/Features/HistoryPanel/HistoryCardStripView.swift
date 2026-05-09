import SwiftUI

struct HistoryCardStripView: View {
    @Bindable var viewModel: HistoryListViewModel
    @FocusState private var focused: Bool
    @State private var firstVisibleID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            Divider()
            cardScroll
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear {
            focused = true
            viewModel.start()
        }
        .onDisappear { viewModel.stop() }
        .onChange(of: viewModel.panel.isShown) { _, shown in
            if shown {
                focused = true
                viewModel.resetForShow()
                firstVisibleID = viewModel.filteredItems.first?.id
            }
        }
        .onKeyPress(phases: [.down, .repeat]) { press in
            PanelKeyHandler.handle(press, viewModel: viewModel)
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text(viewModel.searchText.isEmpty ? "Type to search" : viewModel.searchText)
                .foregroundStyle(viewModel.searchText.isEmpty ? Color.secondary : Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("panelSearchField")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: Constants.UI.glassBorderWidth)
        )
    }

    @Namespace private var animation

    private var cardScroll: some View {
        GeometryReader { geo in
            let verticalPadding: CGFloat = 16
            let side = max(80, geo.size.height - verticalPadding)
            let visibleCount = max(1, Int(geo.size.width / max(side + 8, 1)))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .center, spacing: 8) {
                    let items = viewModel.filteredItems
                    if items.isEmpty {
                        Text(viewModel.searchText.isEmpty ? "No clips yet" : "No matches")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                            .frame(width: side, height: side)
                    } else {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, snapshot in
                            cardCell(index: index, snapshot: snapshot, side: side)
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: 4)),
                                        removal: .opacity.combined(with: .scale(scale: 0.98))
                                    )
                                )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, verticalPadding / 2)
                .scrollTargetLayout()
                .animation(viewModel.searchText.isEmpty ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: viewModel.filteredIDs)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $firstVisibleID, anchor: .leading)
            .accessibilityIdentifier(AccessibilityIdentifiers.yippyTableView)
            .onAppear {
                if firstVisibleID == nil {
                    firstVisibleID = viewModel.filteredItems.first?.id
                }
            }
            .onChange(of: firstVisibleID) { _, newID in
                guard let newID,
                      let idx = viewModel.filteredItems.firstIndex(where: { $0.id == newID })
                else { return }
                viewModel.quickPasteBase = idx
            }
            .onChange(of: viewModel.filteredItems.map(\.id)) { _, _ in
                let items = viewModel.filteredItems
                if let anchor = firstVisibleID,
                   let idx = items.firstIndex(where: { $0.id == anchor })
                {
                    viewModel.quickPasteBase = idx
                } else {
                    viewModel.quickPasteBase = 0
                }
            }
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                let items = viewModel.filteredItems
                guard newIndex >= 0, newIndex < items.count else { return }
                let firstIdx = items.firstIndex(where: { $0.id == firstVisibleID }) ?? 0
                if newIndex < firstIdx {
                    firstVisibleID = items[newIndex].id
                } else if newIndex >= firstIdx + visibleCount {
                    let target = max(0, newIndex - visibleCount + 1)
                    firstVisibleID = items[target].id
                }
            }
            .onChange(of: viewModel.searchText) { _, newValue in
                if newValue.isEmpty {
                    // Reset scroll instantly when clearing to prevent jumping
                    firstVisibleID = viewModel.filteredItems.first?.id
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        firstVisibleID = viewModel.filteredItems.first?.id
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cardCell(index: Int, snapshot: ClipItemSnapshot, side: CGFloat) -> some View {
        let shortcut = index - viewModel.quickPasteBase
        clipCardView(
            snapshot: snapshot,
            isSelected: index == viewModel.selectedIndex,
            viewModel: viewModel
        )
        .frame(width: side, height: side)
        .overlay(alignment: .topTrailing) {
            if (0...9).contains(shortcut) {
                shortcutBadge(shortcut)
            }
        }
        .id(snapshot.id)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedIndex = index
        }
    }

    private func shortcutBadge(_ number: Int) -> some View {
        Text("⌘\(number)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.9))
            .clipShape(Capsule())
            .padding(8)
            .accessibilityIdentifier("cardShortcut_\(number)")
    }
}
