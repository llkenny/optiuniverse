//
//  HeroCarouselView.swift
//  OptiUniverse
//
//  Created by max on 08.04.2026.
//

import SwiftUI
import BaseModule

struct HeroCarouselView: View {
    private enum Constants {
        static let cardWidth: CGFloat = 283
        static let cardHeight: CGFloat = 291
        static let cardSpacing: CGFloat = 16
        static let horizontalInset: CGFloat = 64
    }

    @Environment(AppEnvironment.self) private var appEnvironment

    @Binding var currentIndex: Int
    @Binding var totalCount: Int
    @State private var viewModel: HeroCarouselViewModel

    init(viewModel: HeroCarouselViewModel = .init(),
         currentIndex: Binding<Int>,
         totalCount: Binding<Int>) {
        self._viewModel = State(initialValue: viewModel)
        self._currentIndex = currentIndex
        self._totalCount = totalCount
    }

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = (geometry.size.width - Constants.cardWidth) / 2

            ScrollView(.horizontal) {
                LazyHStack(spacing: Constants.cardSpacing) {
                    ForEach(viewModel.cards) { card in
                        HeroCardView(card: card)
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
                            .onTapGesture {
                                appEnvironment.selectedPlanet = card.title
                                appEnvironment.currentScreen = .objects
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, horizontalPadding)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $viewModel.activeCardID)
            .defaultScrollAnchor(.center)
        }
        .frame(height: Constants.cardHeight)
        .task {
            viewModel.featuredObjectProvider = appEnvironment.featuredObjectProvider
            await viewModel.loadCards()
        }
        .onChange(of: currentIndex) { _, _ in
            syncSelectionToCurrentIndex()
        }
        .onChange(of: viewModel.activeCardID) { _, newValue in
            syncCurrentIndex(from: newValue)
        }
        .onChange(of: viewModel.cards) { _, newValue in
            totalCount = newValue.count
            syncSelectionToCurrentIndex()
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

private struct HeroCarouselPreview: View {
    @State private var currentIndex = 0
    @State private var totalCount = 0

    private let viewModel: HeroCarouselViewModel = {
        let viewModel = HeroCarouselViewModel()
        viewModel.cards = (0..<3).map { index in
            HeroCard(
                id: UUID(),
                imageResource: .dstMars,
                title: "Mars",
                subtitle: "Test \(index)",
                accentColors: [.orange, .yellow]
            )
        }
        return viewModel
    }()

    var body: some View {
        HeroCarouselView(
            viewModel: viewModel,
            currentIndex: $currentIndex,
            totalCount: $totalCount
        )
        .background(OptiColor.screenBackground)
        .environment(AppEnvironment())
    }
}

#Preview {
    HeroCarouselPreview()
}
