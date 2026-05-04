//
//  CurrentMissionView.swift
//  OptiUniverse
//
//  Created by max on 04.05.2026.
//

import SwiftUI

struct CurrentMissionView: View {
    @State private var isShipFloating = false

    var body: some View {
        HStack {
            Spacer()
            Image(.missionShip)
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                .scaleEffect(isShipFloating ? 1.03 : 0.98)
                .offset(y: isShipFloating ? -10 : 8)
                .rotationEffect(.degrees(isShipFloating ? 3 : -3))
                .animation(
                    .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                    value: isShipFloating
                )
                .onAppear {
                    isShipFloating = true
                }
            Spacer()
            VStack {
                Image(.missionDestination)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                Image(.missionHealth)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 35)
            }
        }
    }
}

#Preview {
    CurrentMissionView()
        .padding()
}
