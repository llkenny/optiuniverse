//
//  DestinationListView.swift
//  OptiUniverse
//
//  Created by max on 19.04.2026.
//

import SwiftUI

struct DestinationListView: View {
    @Binding var selectedTag: String?
    @State var viewModel: DestinationListViewModel = .init()
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack {
                ForEach(viewModel.cards(filteredBy: selectedTag)) { model in
                    DestinationCardView(model: model)
                }
            }
            .frame(height: 174)
        }
        .onAppear {
            viewModel.loadCards()
        }
        .animation(.easeInOut, value: selectedTag)
    }
}

#Preview {
    @Previewable @State var selectedTag: String? = nil
    
    DestinationListView(selectedTag: $selectedTag)
        .padding(.horizontal)
}
