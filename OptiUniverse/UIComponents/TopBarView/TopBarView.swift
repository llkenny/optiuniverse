//
//  TopBarView.swift
//  OptiUniverse
//
//  Created by max on 07.04.2026.
//

import SwiftUI

struct TopBarView: View {
    @Environment(UniverseSelectionState.self) private var universeSelectionState
    @State var viewModel: TopBarViewModel

    var body: some View {
        HStack {
            Menu {
                ForEach(viewModel.planetNames, id: \.self) { name in
                    Button(name) {
                        universeSelectionState.selectedPlanet = name
                    }
                }
            } label: {
                Image(.menu)
            }
            Spacer()
            
            Text(universeSelectionState.location)
                .foregroundStyle(Color(.lowEmphasized))
                .fontWeight(.light)
                .font(.system(size: 14))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                
            Spacer()
            Image(.avatar)
        }
    }
}

#Preview {
    VStack {
        TopBarView(
            viewModel: TopBarViewModel(planetNames: ["Mercury", "Venus", "Earth"])
        )
        Spacer()
    }
    .padding()
    .environment(UniverseSelectionState())
}
