//
//  HomeView.swift
//  OptiUniverse
//
//  Created by max on 08.04.2026.
//

import SwiftUI
import BaseModule

struct HomeView: View {

    let onMissionSelected: (Mission) -> Void

    @State private var currentCarouselIndex: Int = 0
    @State private var totalCount: Int = 0
    @State private var selectedTag: String?
    @State private var minimumMissionCardHeight: CGFloat = 0
    @State private var categoryHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .caption) private var minimumDestinationSide: CGFloat = 96

    var body: some View {
        GeometryReader { geometry in
            let isExpanded = AdaptiveLayoutPolicy.isExpandedDiscovery(width: geometry.size.width)
            let sizing = DiscoveryLayoutSizing(
                availableHeight: geometry.size.height,
                minimumMissionCardHeight: minimumMissionCardHeight,
                categoryHeight: categoryHeight,
                minimumDestinationSide: min(174, minimumDestinationSide),
                maximumDestinationSide: isExpanded ? 240 : 174
            )
            ScrollView(.vertical, showsIndicators: false) {
                discoveryContent(width: geometry.size.width, sizing: sizing, isExpanded: isExpanded)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .background(OptiColor.screenBackground.ignoresSafeArea())
    }

    private func discoveryContent(width: CGFloat, sizing: DiscoveryLayoutSizing,
                                  isExpanded: Bool) -> some View {
        VStack(spacing: 0) {
            HeroCarouselView(
                currentIndex: $currentCarouselIndex,
                totalCount: $totalCount,
                onMissionSelected: onMissionSelected,
                availableWidth: width,
                isExpanded: isExpanded,
                cardHeight: sizing.missionCardHeight,
                onMinimumCardHeightChange: { minimumMissionCardHeight = $0 }
            )
            PageIndicatorView(totalCount: totalCount,
                              currentIndex: $currentCarouselIndex)
                .frame(height: DiscoveryLayoutSizing.indicatorHeight)
            objects(width: width, sizing: sizing, isExpanded: isExpanded)
        }
    }

    private func objects(width: CGFloat, sizing: DiscoveryLayoutSizing, isExpanded: Bool) -> some View {
        VStack(spacing: DiscoveryLayoutSizing.sectionSpacing) {
            CategoryChipsView(selectedTag: $selectedTag)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { categoryHeight = $0 }
            DestinationListView(
                selectedTag: $selectedTag,
                isExpanded: isExpanded,
                cardSide: sizing.destinationSide,
                gridColumnCount: DiscoveryLayoutSizing.destinationColumnCount(
                    availableWidth: width - DiscoveryLayoutSizing.horizontalPadding * 2,
                    cardSide: sizing.destinationSide
                ),
                gridViewportHeight: sizing.needsPageScrolling ? nil : sizing.destinationViewportHeight
            )
        }
        .padding(.horizontal, DiscoveryLayoutSizing.horizontalPadding)
        .padding(.bottom, DiscoveryLayoutSizing.bottomPadding)
        .frame(minHeight: sizing.objectsHeight, alignment: .top)
    }
}

#Preview {
    HomeView(onMissionSelected: { _ in })
        .environment(AppEnvironment())
}
