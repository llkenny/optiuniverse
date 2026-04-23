//
//  CategoryChipsView.swift
//  OptiUniverse
//
//  Created by max on 21.04.2026.
//

import SwiftUI

struct CategoryChipsView: View {
    @Binding var selectedTag: String?
    private let viewModel: CategoryChipsViewModel = .init()
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Array(viewModel.chips.enumerated()),
                        id: \.element.id) { index, chip in
                    CategoryChipView(
                        isActive: .constant(selectedTag == chip.title),
                        model: chip
                    )
                    .padding(.bottom, 20)
                    .onTapGesture {
                        if selectedTag == chip.title {
                            selectedTag = nil
                        } else {
                            selectedTag = chip.title
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    VStack {
        CategoryChipsView(selectedTag: .constant(nil))
        Spacer()
    }
    .padding()
}
