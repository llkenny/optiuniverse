//
//  HomeView.swift
//  OptiUniverse
//
//  Created by max on 08.04.2026.
//

import SwiftUI

struct HomeView: View {
    private let chipsViewModel = CategoryChipsViewModel()

    @State private var currentCarouselIndex: Int = 0
    @State private var totalCount: Int = 0
    @State private var currentChipsIndex: Int? = nil
    @State private var selectedTag: String? = nil
    
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
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
                    CategoryChipsView(selectedTag: $selectedTag)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    DestinationListView(selectedTag: $selectedTag)
                        .padding(.horizontal)
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
