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
    var availableWidth: CGFloat = 348

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var bodySize = 14
    @ScaledMetric(relativeTo: .headline) private var headingSize = 16

    var body: some View {
        Group {
            if AdaptiveLayoutPolicy.usesHorizontalInfoOrbit(cardWidth: availableWidth,
                                                            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize) {
                HStack(alignment: .top, spacing: 12) {
                    orbitImage
                        .frame(width: 96)
                    orbitDescription
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    orbitImage
                        .frame(maxWidth: .infinity)
                    orbitDescription
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

    private var orbitImage: some View {
        Image(.objectInfoOrbit)
            .resizable()
            .scaledToFit()
            .frame(height: 140)
            .accessibilityHidden(true)
    }

    private var orbitDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Orbit")
                .foregroundStyle(OptiColor.objectInfoTextPrimary)
                .font(.system(size: headingSize))
            Text(model.description)
                .foregroundStyle(OptiColor.objectInfoTextSecondary)
                .font(.system(size: bodySize))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(orderedProperties.enumerated()), id: \.offset) { index, item in
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text(item.key.rawValue)
                            .font(.system(size: bodySize * 5 / 7))
                            .fixedSize()
                        Spacer(minLength: 8)
                        Text(item.value)
                            .fixedSize()
                    }
                    .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.key.rawValue)
                        Text(item.value)
                    }
                }
                .font(.system(size: bodySize))
                .foregroundStyle(OptiColor.objectInfoTextSecondary)
                if index < orderedProperties.count - 1 {
                    Divider().background(OptiColor.objectInfoBorder)
                }
            }
        }
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
