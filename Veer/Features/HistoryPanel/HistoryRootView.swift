import SwiftUI

struct HistoryRootView: View {
    let env: AppEnvironment
    @Bindable var coordinator: PanelCoordinator

    init(env: AppEnvironment) {
        self.env = env
        self.coordinator = env.panel
    }

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if coordinator.effectiveHorizontal {
                HistoryCardStripView(viewModel: env.historyViewModel, coordinator: coordinator)
            } else {
                HistoryListView(viewModel: env.historyViewModel, coordinator: coordinator)
            }
        }
        // One-time discoverability hint for pasting and the smart-action
        // strip; dismissed explicitly or automatically the first time the
        // strip is opened. Read straight off env.settings so the overlay
        // re-evaluates when the flag flips.
        .overlay(alignment: .bottom) {
            if coordinator.isShown,
               !env.settings.hasSeenActionsHint,
               env.historyViewModel.searchText.isEmpty,
               !env.historyViewModel.filteredItems.isEmpty
            {
                ActionsHintView(horizontal: coordinator.effectiveHorizontal) {
                    env.historyViewModel.markActionsHintSeen()
                }
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .offset(y: 6)))
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: env.settings.hasSeenActionsHint
        )
        .onChange(of: coordinator.isShown) { _, shown in
            if shown {
                env.historyViewModel.resetForShow()
                coordinator.syncSearchChromeHeight(isSearching: false)
                env.historyViewModel.start()
            } else {
                env.historyViewModel.stop()
            }
        }
        .onChange(of: env.historyViewModel.searchText.isEmpty) { _, isEmpty in
            coordinator.syncSearchChromeHeight(isSearching: !isEmpty)
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95)
        .blur(radius: isVisible ? 0 : 10)
        .onAppear {
            coordinator.syncSearchChromeHeight(isSearching: !env.historyViewModel.searchText.isEmpty)
            if coordinator.isShown {
                env.historyViewModel.start()
            }
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
                    isVisible = true
                }
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
}

/// Floating capsule shown once at the bottom of the panel until dismissed or
/// until the action strip is opened for the first time.
private struct ActionsHintView: View {
    let horizontal: Bool
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Return or double-click to paste · \(horizontal ? "↓" : "→") reveals actions")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
            .accessibilityIdentifier(AccessibilityIdentifiers.actionsHintDismissButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: Constants.UI.glassBorderWidth)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.actionsHint)
    }
}
