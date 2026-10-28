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

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                discoveryContent(width: geometry.size.width)
            }
        }
        .background(OptiColor.screenBackground.ignoresSafeArea())
    }

    private func discoveryContent(width: CGFloat) -> some View {
        let isExpanded = AdaptiveLayoutPolicy.isExpandedDiscovery(width: width)
        return VStack(spacing: 0) {
            HeroCarouselView(
                currentIndex: $currentCarouselIndex,
                totalCount: $totalCount,
                onMissionSelected: onMissionSelected,
                availableWidth: width,
                isExpanded: isExpanded
            )
            .padding(.bottom, 12)
            PageIndicatorView(totalCount: totalCount,
                              currentIndex: $currentCarouselIndex)
            .padding(.bottom, 16)
            CategoryChipsView(selectedTag: $selectedTag)
                .padding(.horizontal)
                .padding(.bottom, 2)
            DestinationListView(selectedTag: $selectedTag, isExpanded: isExpanded)
                .padding(.horizontal)
        }
    }
}

#Preview {
    HomeView(onMissionSelected: { _ in })
        .environment(AppEnvironment())
}
