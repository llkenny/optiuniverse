//
//  HomeView.swift
//  OptiUniverse
//
//  Created by max on 08.04.2026.
//

import SwiftUI
import BaseModule

struct HomeView: View {

    @Environment(AppEnvironment.self) private var appEnvironment
    let onMissionSelected: (Mission) -> Void

    @State private var currentCarouselIndex: Int = 0
    @State private var totalCount: Int = 0
    @State private var currentChipsIndex: Int?
    @State private var selectedTag: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                TitleSectionView(missions: Mission.available,
                                 onMissionSelected: onMissionSelected)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                HeroCarouselView(
                    currentIndex: $currentCarouselIndex,
                    totalCount: $totalCount
                )
                .padding(.bottom, 12)
                PageIndicatorView(totalCount: totalCount,
                                  currentIndex: $currentCarouselIndex)
                .padding(.bottom, 16)
                CategoryChipsView(selectedTag: $selectedTag)
                    .padding(.horizontal)
                    .padding(.bottom, 2)
                DestinationListView(selectedTag: $selectedTag)
                    .padding(.horizontal)
            }
        }
        .background(OptiColor.screenBackground.ignoresSafeArea())
    }
}

#Preview {
    HomeView(onMissionSelected: { _ in })
        .environment(AppEnvironment())
}
