//
//  DestinationListView.swift
//  OptiUniverse
//
//  Created by max on 19.04.2026.
//

import SwiftUI

struct DestinationListView: View {
    @State var viewModel: DestinationListViewModel = .init()
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack {
                ForEach(viewModel.cards) { model in
                    DestinationCardView(model: model)
                }
            }
            .frame(height: 174)
            .padding()
        }
        .onAppear {
            viewModel.loadCards()
        }
    }
}

#Preview {
    DestinationListView()
}
