//
//  HeroCarouselView.swift
//  OptiUniverse
//
//  Created by max on 08.04.2026.
//

import SwiftUI

struct HeroCarouselView: View {
    
    private enum Constants {
        static let cardHeight: CGFloat = 291
        static let cardSpacing: CGFloat = 16
        static let horizontalInset: CGFloat = 64
    }
    
    @State private var viewModel: HeroCarouselViewModel = .init()
    
    var body: some View {
        
        ScrollView(.horizontal) {
            LazyHStack(spacing: Constants.cardSpacing) {
                ForEach(viewModel.cards) { card in
                    HeroCardView(card: card)
                        .containerRelativeFrame(
                            .horizontal,
                            count: 3,
                            span: 2,
                            spacing: Constants.cardSpacing
                        )
                        .scrollTransition(axis: .horizontal) { content, phase in
                            let isCentered = phase.isIdentity
                            let direction = phase.value
                            
                            return content
                                .scaleEffect(isCentered ? 1 : 0.88)
                                .opacity(isCentered ? 1 : 0.2)
                                .offset(y: phase.isIdentity ? 0 : 16)
                                .offset(x: direction * -24)
                                .rotation3DEffect(
                                    .degrees(direction * -30),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.6
                                )
                        }
                        .id(card.id)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, Constants.horizontalInset)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $viewModel.activeCardID)
        .defaultScrollAnchor(.center)
        .onAppear {
            viewModel.loadCards()
        }
    }
}

#Preview {
    HeroCarouselView()
}
