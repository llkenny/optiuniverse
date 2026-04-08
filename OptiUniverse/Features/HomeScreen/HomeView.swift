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
                VStack {
                    TitleSectionView(name: "Stranger")
                        .padding(.horizontal)
                    // TODO: Add views:
                    //                ├── HeroCarouselView
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
