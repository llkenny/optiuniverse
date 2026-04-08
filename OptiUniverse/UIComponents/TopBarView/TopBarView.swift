//
//  TopBarView.swift
//  OptiUniverse
//
//  Created by max on 07.04.2026.
//

import SwiftUI

struct TopBarView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State var viewModel: TopBarViewModel

    var body: some View {
        HStack {
            Menu {
                Button("Home") {
                    appEnvironment.currentScreen = .home
                }
                Menu("Objects") {
                    ForEach(viewModel.planetNames, id: \.self) { name in
                        Button(name) {
                            appEnvironment.selectedPlanet = name
                            appEnvironment.currentScreen = .objects
                        }
                    }
                }
            } label: {
                Image(.menu)
            }
            Spacer()
            
            Text(appEnvironment.location)
                .foregroundStyle(Color(.lowEmphasized))
                .fontWeight(.light)
                .font(.system(size: 14))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                
            Spacer()
            Image(.avatar)
                .frame(height: 44)
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
    .environment(AppEnvironment())
}
