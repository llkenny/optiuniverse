//
//  TitleSectionView.swift
//  OptiUniverse
//
//  Created by max on 08.04.2026.
//

import SwiftUI

struct TitleSectionView: View {
    let missions: [Mission]
    let onMissionSelected: (Mission) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(missions) { mission in
                        MissionCardView(mission: mission)
                            .onTapGesture {
                                onMissionSelected(mission)
                            }
                    }
                }
            }
            .frame(height: 82)

            HStack {
                Text("Where do you wanna go?")
                    .font(Typography.screenTitle)
                    .foregroundStyle(OptiColor.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 60)
            }
        }
    }
}

#Preview {
    VStack {
        TitleSectionView(missions: Mission.available,
                         onMissionSelected: { _ in })
        Spacer()
    }
    .padding(.horizontal)
    .background(OptiColor.screenBackground)
}
