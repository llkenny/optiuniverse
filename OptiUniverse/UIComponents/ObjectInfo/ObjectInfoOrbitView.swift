//
//  ObjectInfoOrbitView.swift
//  OptiUniverse
//
//  Created by max on 01.06.2026.
//

import SwiftUI

struct ObjectInfoOrbitView: View {

    enum Property: String, CaseIterable {
        case axis = "Semi-major axis"
        case eccentricity = "Eccentricity"
        case inclination = "Inclination"
    }

    struct Model {
        let description: String
        let properties: [Property: String]
    }

    let model: Model

    var body: some View {
        HStack(alignment: .top) {
            Image(.objectInfoOrbit)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 140)
                .padding(.trailing, 8)
            VStack(alignment: .leading) {
                Text("Orbit")
                    .foregroundStyle(OptiColor.objectInfoTextPrimary)
                    .font(Typography.overlayHeading)
                    .padding(.bottom, 2)
                Text(model.description)
                    .foregroundStyle(OptiColor.objectInfoTextSecondary)
                    .font(Typography.overlayBody)
                    .padding(.bottom, 8)

                VStack(spacing: 4) {
                    ForEach(Array(orderedProperties.enumerated()), id: \.offset) { index, item in
                        HStack {
                            Text(item.key.rawValue)
                                .font(Typography.overlayValue)
                                .foregroundStyle(OptiColor.objectInfoTextSecondary)
                            Spacer()
                            Text(item.value)
                                .font(Typography.overlayBody)
                                .foregroundStyle(OptiColor.objectInfoTextSecondary)
                        }
                        if index < orderedProperties.count - 1 {
                            Divider()
                                .background(OptiColor.objectInfoBorder)
                        }
                    }
                }
            }
        }
        .padding()
        .background(OptiColor.objectInfoSurface.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.detailCard))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.detailCard)
                .stroke(OptiColor.objectInfoBorder, lineWidth: 1)
        )
    }

    private var orderedProperties: [(key: Property, value: String)] {
        Property.allCases.compactMap { property in
            guard let value = model.properties[property] else { return nil }
            return (property, value)
        }
    }
}

#Preview {
    VStack {
        ObjectInfoOrbitView(model: .init(
            description: "Mercury completes one orbit around the Sun every 87.97 days",
            properties: [
                .axis: "0.39 AU",
                .eccentricity: "0.206",
                .inclination: "7.00°"
            ]
        ))
        .padding()
        Spacer()
    }
    .frame(maxWidth: .infinity)
    .background(OptiColor.screenBackground)
}
