//
//  HeroCarouselView.swift
//  OptiUniverse
//
//  Created by max on 08.04.2026.
//

import SwiftUI

struct HeroCarouselView: View {
    @Binding var currentIndex: Int
    @Binding var totalCount: Int
    let onMissionSelected: (Mission) -> Void

    @State private var viewModel: HeroCarouselViewModel
    @State private var viewportWidth: CGFloat = 315

    init(viewModel: HeroCarouselViewModel = .init(),
         currentIndex: Binding<Int>,
         totalCount: Binding<Int>,
         onMissionSelected: @escaping (Mission) -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self._currentIndex = currentIndex
        self._totalCount = totalCount
        self.onMissionSelected = onMissionSelected
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                ForEach(viewModel.cards) { card in
                    Button {
                        onMissionSelected(card.mission)
                    } label: {
                        MissionCardView(card: card)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Start mission")
                    .scrollTransition(axis: .horizontal) { content, phase in
                        let direction = phase.value
                        return content
                            .scaleEffect(phase.isIdentity ? 1 : 0.88)
                            .opacity(phase.isIdentity ? 1 : 0.2)
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
            // Measure the tallest card at its full text height, including Dynamic Type.
            .fixedSize(horizontal: false, vertical: true)
            .scrollTargetLayout()
            .padding(.vertical, 16)
        }
        .safeAreaPadding(.horizontal, max(0, (viewportWidth - 283) / 2))
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $viewModel.activeCardID, anchor: .center)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewportWidth = $0 }
        .onAppear {
            syncSelectionToCurrentIndex()
        }
        .onChange(of: currentIndex) { _, _ in
            withAnimation(.easeOut) {
                syncSelectionToCurrentIndex()
            }
        }
        .onChange(of: viewModel.activeCardID) { _, newValue in
            guard let index = viewModel.index(for: newValue) else { return }
            currentIndex = index
        }
    }

    private func syncSelectionToCurrentIndex() {
        totalCount = viewModel.totalCount
        viewModel.currentIndex = currentIndex
        currentIndex = viewModel.currentIndex
    }
}

private struct HeroCarouselPreview: View {
    @State private var currentIndex = 0
    @State private var totalCount = 0

    var body: some View {
        VStack {
            HeroCarouselView(currentIndex: $currentIndex, totalCount: $totalCount,
                             onMissionSelected: { _ in })
            PageIndicatorView(totalCount: totalCount, currentIndex: $currentIndex)
        }
        .background(OptiColor.screenBackground)
    }
}

#Preview {
    HeroCarouselPreview()
}
