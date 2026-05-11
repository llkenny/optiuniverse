//
//  ObjectInfoView.swift
//  OptiUniverse
//
//  Created by max on 11.05.2026.
//

import SwiftUI

struct ObjectInfoView: View {
    let entity: ObjectInfoViewEntity

    var body: some View {
        VStack(alignment: .leading) {
            Text(entity.title)
                .foregroundStyle(.neonTextPrimary)
                .font(.system(size: 27))
                .padding(.bottom, 2)

            Text(entity.subtitle)
                .foregroundStyle(.neonTextSecondary)
                .font(.system(size: 14))
                .padding(.bottom, 12)

            Text(entity.description)
                .foregroundStyle(.neonTextSecondary)
                .font(.system(size: 14))
                .padding(.bottom, 32)

            Button(action: entity.navigationButtonAction) {
                NeonButtonView(title: entity.navigationButtonTitle)
            }
            .buttonStyle(NeonButtonStyle())
        }
        .padding()
        .background(LinearGradient(colors: [.clear, .neonSectionFill],
                                   startPoint: .top, endPoint: .bottom))
    }
}

#Preview {
    let description = """
Mercury is the smallest planet in our solar system and the closest to the Sun.
It has a rocky surface covered in craters and experiences extreme temperature variations.
"""
    let entity = ObjectInfoViewEntity(id: .init(),
                                      title: "Mercury",
                                      subtitle: "Swift Cratered World",
                                      description: description,
                                      navigationButtonTitle: "Navigate to",
                                      navigationButtonAction: {
        print("Navigate to Mercury")
    })
    ObjectInfoView(entity: entity)
}
