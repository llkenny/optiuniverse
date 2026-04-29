//
//  CategoryChipsView.swift
//  OptiUniverse
//
//  Created by max on 21.04.2026.
//

import SwiftUI
import BaseModule

struct CategoryChipsView: View {

    @Environment(AppEnvironment.self) private var appEnvironment

    @Binding var selectedTag: String?
    @State private var viewModel: CategoryChipsViewModel = .init()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(viewModel.tags, id: \.self) { tag in
                    CategoryChipView(
                        isActive: selectedTag == tag,
                        title: tag
                    )
                    .padding(.bottom, 20)
                    .onTapGesture {
                        if selectedTag == tag {
                            selectedTag = nil
                        } else {
                            selectedTag = tag
                        }
                    }
                }
            }
        }
        .task {
            viewModel.destinationsProvider = appEnvironment.destinationsProvider
            await viewModel.loadTags()
        }
    }
}

#Preview {
    @Previewable @State var selectedTag: String?

    VStack {
        CategoryChipsView(selectedTag: $selectedTag)
        Spacer()
    }
    .padding()
}
