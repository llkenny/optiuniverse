//
//  DestinationListView.swift
//  OptiUniverse
//
//  Created by max on 19.04.2026.
//

import SwiftUI
import BaseModule

struct DestinationListView: View {

    @Environment(AppEnvironment.self) private var appEnvironment

    @Binding var selectedTag: String?
    var isExpanded = false
    var cardSide: CGFloat = 174
    var gridColumnCount: Int = 1
    var gridViewportHeight: CGFloat?
    @State private var viewModel: DestinationListViewModel = .init()

    var body: some View {
        Group {
            if isExpanded {
                if let gridViewportHeight {
                    ScrollView(.vertical, showsIndicators: false) {
                        destinationGrid
                    }
                    .frame(height: gridViewportHeight)
                } else {
                    destinationGrid
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack {
                        destinationCards
                    }
                    .frame(height: cardSide)
                }
            }
        }
        .task {
            viewModel.destinationsProvider = appEnvironment.destinationsProvider
            viewModel.loadCards()
        }
        .animation(.easeInOut, value: selectedTag)
    }

    private var destinationGrid: some View {
        let columns = Array(repeating: GridItem(.fixed(cardSide), spacing: DiscoveryLayoutSizing.destinationSpacing),
                            count: max(1, gridColumnCount))
        return LazyVGrid(columns: columns, alignment: .leading, spacing: DiscoveryLayoutSizing.destinationSpacing) {
            destinationCards
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var destinationCards: some View {
        ForEach(viewModel.cards(filteredBy: selectedTag)) { model in
            Button {
                appEnvironment.selectedDestinationID = model.id
                appEnvironment.selectedPlanet = model.title
                appEnvironment.currentScreen = .objects
            } label: {
                DestinationCardView(model: model)
            }
            .buttonStyle(.plain)
            .frame(width: cardSide, height: cardSide)
        }
    }
}

#Preview {
    @Previewable @State var selectedTag: String?

    DestinationListView(selectedTag: $selectedTag)
        .padding(.horizontal)
}
