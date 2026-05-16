//
//  TopBarView.swift
//  OptiUniverse
//
//  Created by max on 07.04.2026.
//

import SwiftUI
import BaseModule

struct TopBarView: View {

    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var isShowingProfile: Bool = false

    var body: some View {
        HStack {
            if appEnvironment.currentScreen == .home {
                Spacer()
                    .frame(width: 44)
            } else {
                Button {
                    appEnvironment.currentScreen = .home
                } label: {
                    Image(.menu)
                        .frame(width: 44, height: 44)
                }
            }
            Spacer()

            Text(appEnvironment.location)
                .foregroundStyle(OptiColor.textTertiary)
                .font(Typography.location)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Spacer()

            // Hidden for version 1 release in #239
//            Image(.avatar)
//                .resizable()
//                .scaledToFill()
//                .frame(width: 44, height: 44)
//                .clipShape(Circle())
//                .onTapGesture {
//                    isShowingProfile = true
//                }
        }
        .sheet(isPresented: $isShowingProfile) {
            ProfileView()
        }
    }
}

#Preview {
    VStack {
        TopBarView()
        Spacer()
    }
    .padding()
    .background(OptiColor.screenBackground)
    .environment(AppEnvironment())
}
