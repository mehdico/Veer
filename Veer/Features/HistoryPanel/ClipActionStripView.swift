import SwiftUI

/// Inline action strip revealed on the selected clip. In the vertical list it
/// sits under the selected row with labeled buttons that wrap onto a second
/// row when they don't fit; in the card layout it hovers over the card as a
/// floating pill with large icons, scrolling horizontally when the pill is
/// wider than the card. The highlighted action is the one Return will run.
///
/// Every detected action is always reachable — nothing is hidden or cropped:
/// the list wraps, and the card pill scrolls (and follows the keyboard
/// highlight) when it overflows the card.
struct ClipActionStripView: View {
    let actions: [ClipAction]
    let compact: Bool
    let highlightedIndex: Int
    let onRun: (ClipAction) -> Void

    var body: some View {
        Group {
            if compact {
                VStack(spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        pill {
                            HStack(spacing: 12) {
                                actionButtons
                            }
                        }
                        pill {
                            ScrollViewReader { proxy in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        actionButtons
                                    }
                                }
                                .onChange(of: highlightedIndex) { _, newIndex in
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        proxy.scrollTo(newIndex, anchor: .center)
                                    }
                                }
                            }
                        }
                    }

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
                ActionFlowLayout(spacing: 6) {
                    actionButtons
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.clipActionStrip)
    }

    private var actionButtons: some View {
        ForEach(0..<actions.count, id: \.self) { index in
            actionButton(actions[index], isHighlighted: index == highlightedIndex)
                .id(index)
        }
    }

    /// The capsule chrome shared by the fitting and scrolling card pills.
    private func pill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: Constants.UI.glassBorderWidth)
            )
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
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

/// Wraps subviews onto additional rows when they exceed the available width,
/// so every action stays visible instead of being clipped or hidden.
struct ActionFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        let width = maxWidth == .greatestFiniteMagnitude ? max(0, x - spacing) : maxWidth
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
