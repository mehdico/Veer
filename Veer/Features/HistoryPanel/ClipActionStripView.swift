import SwiftUI

/// Inline action strip revealed on the selected clip. In the vertical list it
/// sits under the selected row with labeled buttons; in the card layout it
/// hovers over the card as a floating pill with large icons. The highlighted
/// action is the one Return will run.
struct ClipActionStripView: View {
    let actions: [ClipAction]
    let compact: Bool
    let highlightedIndex: Int
    let onRun: (ClipAction) -> Void

    var body: some View {
        Group {
            if compact {
                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        ForEach(0..<actions.count, id: \.self) { index in
                            actionButton(
                                actions[index],
                                isHighlighted: index == highlightedIndex
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: Constants.UI.glassBorderWidth)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

                    if actions.indices.contains(highlightedIndex) {
                        Text(actions[highlightedIndex].title)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: Capsule())
                            .accessibilityIdentifier(AccessibilityIdentifiers.clipActionTitle)
                    }
                }
                .padding(.bottom, 10)
            } else {
                HStack(spacing: 6) {
                    ForEach(0..<actions.count, id: \.self) { index in
                        actionButton(
                            actions[index],
                            isHighlighted: index == highlightedIndex
                        )
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.clipActionStrip)
    }

    @ViewBuilder
    private func actionButton(_ action: ClipAction, isHighlighted: Bool) -> some View {
        let button = Button {
            onRun(action)
        } label: {
            if compact {
                Image(systemName: action.systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 42, height: 36)
                    .help(action.title)
            } else {
                Label(action.title, systemImage: action.systemImage)
            }
        }
        if isHighlighted {
            button
                .buttonStyle(.borderedProminent)
                .controlSize(compact ? .large : .small)
                .accessibilityLabel(action.title)
                .accessibilityIdentifier(AccessibilityIdentifiers.clipActionButton(action.id))
                .accessibilityAddTraits(.isSelected)
        } else {
            button
                .buttonStyle(.bordered)
                .controlSize(compact ? .large : .small)
                .accessibilityLabel(action.title)
                .accessibilityIdentifier(AccessibilityIdentifiers.clipActionButton(action.id))
        }
    }
}
