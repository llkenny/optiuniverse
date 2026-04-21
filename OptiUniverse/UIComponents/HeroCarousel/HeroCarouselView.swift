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

    @Binding var currentIndex: Int
    @Binding var totalCount: Int
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
            totalCount = viewModel.cards.count
            syncSelectionToCurrentIndex()
        }
        .onChange(of: currentIndex) { _, _ in
            syncSelectionToCurrentIndex()
        }
        .onChange(of: viewModel.activeCardID) { _, newValue in
            syncCurrentIndex(from: newValue)
        }
    }

    private func syncSelectionToCurrentIndex() {
        totalCount = viewModel.totalCount

        guard let clampedIndex = viewModel.clampedIndex(for: currentIndex) else {
            viewModel.activeCardID = nil
            return
        }

        if currentIndex != clampedIndex {
            currentIndex = clampedIndex
        }

        guard let selectedCardID = viewModel.cardID(for: clampedIndex) else { return }
        guard viewModel.activeCardID != selectedCardID else { return }

        withAnimation(.easeOut) {
            viewModel.activeCardID = selectedCardID
        }
    }

    private func syncCurrentIndex(from activeCardID: HeroCard.ID?) {
        guard
            let updatedIndex = viewModel.index(for: activeCardID),
            currentIndex != updatedIndex
        else {
            return
        }

        currentIndex = updatedIndex
    }
}

#Preview {
    @Previewable @State var currentIndex: Int = 0
    @Previewable @State var totalCount: Int = 0

    HeroCarouselView(currentIndex: $currentIndex, totalCount: $totalCount)
}
