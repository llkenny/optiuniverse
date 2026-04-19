//
//  DestinationCardView.swift
//  OptiUniverse
//
//  Created by max on 19.04.2026.
//

import SwiftUI

struct DestinationCardView: View {
    let model: DestinationObjectModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Spacer()
            
            Text(model.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Text(model.subtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.leading, 8)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .aspectRatio(1, contentMode: .fit)
        .background {
            Image(model.imageResource)
                .resizable()
                .scaledToFill()
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

#Preview("Single") {
    DestinationCardView(model: .init(id: .init(),
                                     title: "Mars",
                                     subtitle: "Dusty Red Planet",
                                     imageResource: .marsPerseveranceZR008120739017260428EBYN0391170ZCAM036710340LMJ))
    .frame(width: 174)
    .clipped()
}

#Preview("Multiple") {
    let models = [
        DestinationObjectModel(id: .init(),
                               title: "Mars mountains",
                               subtitle: "Dusty Red Planet",
                               imageResource: .marsPerseveranceZR008120739017260428EBYN0391170ZCAM036710340LMJ),
        DestinationObjectModel(id: .init(),
                               title: "Neptune Scooter",
                               subtitle: "Windy Blue Planet",
                               imageResource: .pia01142Orig),
        DestinationObjectModel(id: .init(),
                               title: "Lunar landscape",
                               subtitle: "Nearest destination to Earth",
                               imageResource: .s21280)
    ]
    
    VStack {
        Spacer(minLength: 500)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(models) { model in
                    DestinationCardView(model: model)
                }
            }
            .frame(height: 174)
            .padding()
        }
        Spacer()
    }
}
