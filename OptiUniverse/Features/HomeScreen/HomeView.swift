//
//  HomeView.swift
//  OptiUniverse
//
//  Created by max on 08.04.2026.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    TitleSectionView(name: "Stranger")
                        .padding(.horizontal)
                    HeroCarouselView()
                    
                    // TODO: Add views:
                    //                ├── PageIndicator
                    //                ├── CategoryChipsView
                    //                └── DestinationListView
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
