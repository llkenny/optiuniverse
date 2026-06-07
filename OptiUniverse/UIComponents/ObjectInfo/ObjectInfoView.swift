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
                .foregroundStyle(OptiColor.objectInfoTextPrimary)
                .font(Typography.overlayTitle)
                .padding(.bottom, 2)

            Text(entity.subtitle)
                .foregroundStyle(OptiColor.objectInfoTextSecondary)
                .font(Typography.overlayBody)
                .padding(.bottom, 12)

            HStack {
                ForEach(entity.details, id: \.title) { detail in
                    ObjectInfoDetailCardView(entity: detail)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 12)

            Text("About \(entity.title)")
                .foregroundStyle(OptiColor.objectInfoTextPrimary)
                .font(Typography.overlayHeading)
                .padding(.bottom, 2)

            Text(entity.description)
                .foregroundStyle(OptiColor.objectInfoTextSecondary)
                .font(Typography.overlayBody)
                .padding(.bottom, 8)

            if let orbitInfo = entity.orbitInfo {
                ObjectInfoOrbitView(model: orbitInfo)
                    .padding(.bottom, 8)
            }

            if let imageName = entity.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.detailCard))
            }

            if entity.isNavigable {
                Button(action: entity.navigationButtonAction) {
                    NeonButtonView(title: entity.navigationButtonTitle)
                }
                .buttonStyle(NeonButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .background(LinearGradient(colors: [.clear, OptiColor.objectInfoSurface],
                                   startPoint: .top, endPoint: .bottom))
    }
}

#Preview("Planet") {
    let description = """
Mercury is the smallest planet in our solar system and the closest to the Sun.
It has a rocky surface covered in craters and experiences extreme temperature variations.
"""
    let entity = ObjectInfoViewEntity(id: .init(),
                                      imageName: nil,
                                      title: "Mercury",
                                      subtitle: "Swift Cratered World",
                                      description: description,
                                      details: [.init(title: "age", value: "4.5B", dimension: "years"),
                                                .init(title: "diameter", value: "4,879", dimension: "km"),
                                                .init(title: "mass", value: "0.055", dimension: "earth masses"),
                                                .init(title: "surface temp", value: "-180 to 430", dimension: "°C")],
                                      navigationButtonTitle: "🎯 Route",
                                      isNavigable: true,
                                      orbitInfo: .init(
                                        description: "Mercury completes one orbit around the Sun every 87.97 days",
                                        properties: [
                                            .axis: "0.39 AU",
                                            .eccentricity: "0.206",
                                            .inclination: "7.00°"
                                        ]
                                      ),
                                      navigationButtonAction: {
        print("Navigate to Mercury")
    })
    ObjectInfoView(entity: entity)
        .background(.black)
}

#Preview("Base") {
    let description = """
Mercury is the smallest planet in our solar system and the closest to the Sun.
It has a rocky surface covered in craters and experiences extreme temperature variations.
"""
    let entity = ObjectInfoViewEntity(id: .init(),
                                      imageName: "Moon_Base_Info",
                                      title: "Mercury",
                                      subtitle: "Swift Cratered World",
                                      description: description,
                                      details: [.init(title: "age", value: "4.5B", dimension: "years"),
                                                .init(title: "diameter", value: "4,879", dimension: "km"),
                                                .init(title: "mass", value: "0.055", dimension: "earth masses"),
                                                .init(title: "surface temp", value: "-180 to 430", dimension: "°C")],
                                      navigationButtonTitle: "🎯 Route",
                                      isNavigable: true,
                                      orbitInfo: nil,
                                      navigationButtonAction: {
        print("Navigate to Mercury")
    })
    ObjectInfoView(entity: entity)
        .background(.black)
}
