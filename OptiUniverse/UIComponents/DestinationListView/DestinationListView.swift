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
    @State private var viewModel: DestinationListViewModel = .init()

    var body: some View {
        Group {
            if isExpanded {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 174, maximum: 240))], spacing: 16) {
                    destinationCards
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack {
                        destinationCards
                    }
                    .frame(height: 174)
                }
            }
        }
        .task {
            viewModel.destinationsProvider = appEnvironment.destinationsProvider
            viewModel.loadCards()
        }
        .animation(.easeInOut, value: selectedTag)
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
            .frame(width: isExpanded ? nil : 174, height: isExpanded ? nil : 174)
        }
    }
}

#Preview {
    @Previewable @State var selectedTag: String?

    DestinationListView(selectedTag: $selectedTag)
        .padding(.horizontal)
}
