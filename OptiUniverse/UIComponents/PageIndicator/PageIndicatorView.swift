//
//  PageIndicatorView.swift
//  OptiUniverse
//
//  Created by max on 20.04.2026.
//

import SwiftUI

struct PageIndicatorView: View {

    let totalCount: Int
    @Binding var currentIndex: Int

    private let maxVisibleDots = 7
    private let indicatorAnimation: Animation = .easeOut

    private var visibleIndices: [Int] {
        guard totalCount > 0 else { return [] }
        guard totalCount > maxVisibleDots else { return Array(0..<totalCount) }

        let half = maxVisibleDots / 2
        let lower = max(0, min(currentIndex - half, totalCount - maxVisibleDots))
        let upper = lower + maxVisibleDots - 1
        return Array(lower...upper)
    }

    var body: some View {
        HStack(spacing: 9) {
            ForEach(visibleIndices, id: \.self) { index in
                ZStack {
                    Circle()
                        .fill(index == currentIndex ? .enable : .disable)
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentIndex ? 1.0 : 0.82)
                        .onTapGesture {
                            withAnimation(indicatorAnimation) {
                                currentIndex = index
                            }
                        }

                    if index == currentIndex {
                        Circle()
                            .stroke(lineWidth: 1)
                            .frame(width: 14, height: 14)
                            .transition(.blurReplace)
                    }
                }
            }
        }
        .animation(indicatorAnimation, value: currentIndex)
    }
}

#Preview {
    @Previewable @State var currentIndex: Int = 0

    PageIndicatorView(totalCount: 20, currentIndex: $currentIndex)
}
