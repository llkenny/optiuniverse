//
//  HomeView.swift
//  OptiUniverse
//
//  Created by max on 08.04.2026.
//

import SwiftUI

struct HomeView: View {
    
    // TODO: Connect with cards from HeroCarouselView
    @State private var currentIndex: Int = 0
    @State private var totalCount: Int = 3
    
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    TitleSectionView(name: "Stranger")
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    HeroCarouselView()
                        .padding(.bottom, 12)
                    PageIndicatorView(totalCount: totalCount, currentIndex: $currentIndex)
                        .padding(.bottom, 16)
                    // TODO: Add views:
                    //                ├── CategoryChipsView
                    DestinationListView()
                        .padding(.horizontal)
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
