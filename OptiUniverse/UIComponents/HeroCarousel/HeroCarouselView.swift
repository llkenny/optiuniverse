//
//  HeroCarouselView.swift
//  OptiUniverse
//
//  Created by max on 08.04.2026.
//

import SwiftUI

struct HeroCarouselView: View {
    @Binding var currentIndex: Int
    @Binding var totalCount: Int
    let onMissionSelected: (Mission) -> Void
    let availableWidth: CGFloat
    let isExpanded: Bool
    let cardHeight: CGFloat
    let onMinimumCardHeightChange: (CGFloat) -> Void

    @State private var viewModel: HeroCarouselViewModel

    init(viewModel: HeroCarouselViewModel = .init(),
         currentIndex: Binding<Int>,
         totalCount: Binding<Int>,
         onMissionSelected: @escaping (Mission) -> Void,
         availableWidth: CGFloat = 315,
         isExpanded: Bool = false,
         cardHeight: CGFloat = 360,
         onMinimumCardHeightChange: @escaping (CGFloat) -> Void = { _ in }) {
        self._viewModel = State(initialValue: viewModel)
        self._currentIndex = currentIndex
        self._totalCount = totalCount
        self.onMissionSelected = onMissionSelected
        self.availableWidth = availableWidth
        self.isExpanded = isExpanded
        self.cardHeight = cardHeight
        self.onMinimumCardHeightChange = onMinimumCardHeightChange
    }

    var body: some View {
        ScrollViewReader { reader in
            carousel
                .task(id: CGSize(width: availableWidth, height: cardHeight)) {
                    // Reapply the stable selection after the new card geometry has been laid out.
                    let selectedID = viewModel.cardID(for: currentIndex)
                    await Task.yield()
                    guard !Task.isCancelled, let selectedID else { return }
                    reader.scrollTo(selectedID, anchor: isExpanded ? .leading : .center)
                }
        }
    }

    private var cardWidth: CGFloat {
        AdaptiveLayoutPolicy.missionCardWidth(availableWidth: availableWidth)
    }

    private var carousel: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                ForEach(viewModel.cards) { card in
                    Button {
                        onMissionSelected(card.mission)
                    } label: {
                        MissionCardView(card: card, width: cardWidth, height: cardHeight)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Start mission")
                    .scrollTransition(axis: .horizontal) { content, phase in
                        let direction = phase.value
                        return content
                            .scaleEffect((isExpanded || phase.isIdentity) ? 1 : 0.88)
                            .opacity((isExpanded || phase.isIdentity) ? 1 : 0.2)
                            .offset(y: (isExpanded || phase.isIdentity) ? 0 : 16)
                            .offset(x: isExpanded ? 0 : direction * -24)
                            .rotation3DEffect(
                                .degrees(isExpanded ? 0 : direction * -30),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.6
                            )
                    }
                    .id(card.id)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, DiscoveryLayoutSizing.carouselPadding)
        }
        .frame(height: cardHeight + DiscoveryLayoutSizing.carouselPadding * 2)
        .onPreferenceChange(MissionCardMinimumHeightKey.self, perform: onMinimumCardHeightChange)
        .safeAreaPadding(.horizontal, isExpanded ? 16 : max(0, (availableWidth - cardWidth) / 2))
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $viewModel.activeCardID, anchor: isExpanded ? .leading : .center)
        .onAppear {
            syncSelectionToCurrentIndex()
        }
        .onChange(of: currentIndex) { _, _ in
            withAnimation(.easeOut) {
                syncSelectionToCurrentIndex()
            }
        }
        .onChange(of: viewModel.activeCardID) { _, newValue in
            guard let index = viewModel.index(for: newValue) else { return }
            currentIndex = index
        }
    }

    private func syncSelectionToCurrentIndex() {
        totalCount = viewModel.totalCount
        viewModel.currentIndex = currentIndex
        currentIndex = viewModel.currentIndex
    }
}

private struct HeroCarouselPreview: View {
    @State private var currentIndex = 0
    @State private var totalCount = 0

    var body: some View {
        VStack {
            HeroCarouselView(currentIndex: $currentIndex, totalCount: $totalCount,
                             onMissionSelected: { _ in })
            PageIndicatorView(totalCount: totalCount, currentIndex: $currentIndex)
        }
        .background(OptiColor.screenBackground)
    }
}

#Preview {
    HeroCarouselPreview()
}
