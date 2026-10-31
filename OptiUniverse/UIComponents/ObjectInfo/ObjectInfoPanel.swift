import SwiftUI

/// One scroll view survives compact/expanded transitions, keeping the reader's place.
struct ObjectInfoPanel: View {
    let entity: ObjectInfoViewEntity
    var availableWidth: CGFloat = 380
    var availableHeight: CGFloat = 700
    var isSidePanel = false
    let onDismiss: () -> Void

    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var dragStartScrollOffset: CGFloat?
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var scrollDismissal = ObjectInfoScrollDismissalState()
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        ScrollView {
            ObjectInfoView(entity: entity, availableWidth: availableWidth)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                .contentShape(Rectangle())
                .onTapGesture {} // Keep content taps from reaching the dismissal backdrop.
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.top, for: .initialOffset)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            scrollOffset = offset
            if scrollPhase == .interacting { scrollDismissal.update(offset: offset) }
        }
        .onScrollPhaseChange { oldPhase, phase, context in
            let offset = context.geometry.contentOffset.y + context.geometry.contentInsets.top
            if phase == .tracking {
                dragStartScrollOffset = nil
                scrollDismissal.begin(offset: offset)
            }
            if oldPhase == .interacting, phase != .interacting,
               scrollDismissal.end(offset: offset, velocity: context.velocity?.dy ?? 0) {
                onDismiss()
            }
            scrollPhase = phase
        }
        .frame(width: availableWidth,
               height: AdaptiveLayoutPolicy.bottomPanelHeight(contentHeight: contentHeight,
                                                              viewportHeight: availableHeight))
        .contentShape(Rectangle())
        // Overflowing content uses native scroll events so dismissal cannot capture its pan gesture.
        .simultaneousGesture(dismissGesture, isEnabled: contentHeight <= availableHeight)
        .offset(y: dragOffset)
        .animation(.default, value: dragOffset)
        .accessibilityAction(.escape, onDismiss)
        .accessibilityIdentifier(isSidePanel ? "objectInfoSidePanel" : "objectInfoBottomPanel")
    }

    private var dismissGesture: some Gesture {
        DragGesture()
            .onChanged { _ in
                if dragStartScrollOffset == nil { dragStartScrollOffset = scrollOffset }
            }
            .updating($dragOffset) { value, state, _ in
                if (dragStartScrollOffset ?? scrollOffset) <= 1,
                   value.translation.height > abs(value.translation.width) {
                    state = max(value.translation.height, 0)
                }
            }
            .onEnded { value in
                let startedAtTop = (dragStartScrollOffset ?? scrollOffset) <= 1
                dragStartScrollOffset = nil
                guard startedAtTop, value.translation.height > abs(value.translation.width) else { return }
                if value.translation.height > 80 || value.predictedEndTranslation.height > 140 {
                    onDismiss()
                }
            }
    }
}

/// A pull can dismiss only if the same touch sequence began at the top of the details.
nonisolated struct ObjectInfoScrollDismissalState {
    private var beganAtTop = false
    private var maximumPull: CGFloat = 0

    mutating func begin(offset: CGFloat) {
        beganAtTop = offset.isFinite && offset <= 1
        maximumPull = 0
    }

    mutating func update(offset: CGFloat) {
        guard beganAtTop, offset.isFinite else { return }
        maximumPull = max(maximumPull, -offset)
    }

    mutating func end(offset: CGFloat, velocity: CGFloat) -> Bool {
        update(offset: offset)
        defer { self = Self() }
        let predictedPull = maximumPull + (velocity.isFinite ? max(0, -velocity) * 0.2 : 0)
        return beganAtTop && (maximumPull > 80 || (maximumPull > 0 && predictedPull > 140))
    }
}
