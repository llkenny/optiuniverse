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

    @State private var currentCarouselIndex: Int = 0
    @State private var totalCount: Int = 0
    @State private var currentChipsIndex: Int?
    @State private var selectedTag: String?
    @State private var isDataLoaded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TitleSectionView(name: "Stranger")
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

            if isDataLoaded {
                CategoryChipsView(selectedTag: $selectedTag)
                    .padding(.horizontal)
                    .padding(.bottom, 2)
                DestinationListView(selectedTag: $selectedTag)
                    .padding(.horizontal)
            } else {
                ProgressView()
                    .controlSize(ControlSize.large)
                    .frame(maxHeight: .infinity)
            }
        }
        .task {
            await appEnvironment.destinationsProvider.fetch()
            isDataLoaded = true
        }
    }
}

#Preview {
    HomeView()
        .environment(AppEnvironment())
}
