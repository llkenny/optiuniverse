//
//  CategoryChipView.swift
//  OptiUniverse
//
//  Created by max on 21.04.2026.
//

import SwiftUI

struct CategoryChipView: View {
    let isActive: Bool
    let title: String

    var body: some View {
        Text(title)
            .foregroundStyle(isActive ? .white : Color.lowEmphasized)
            .font(.system(size: 14))
            .lineLimit(1)
        .padding(10)
        .background {
            ZStack {
                Capsule()
                    .fill(Color.enable)
                    .opacity(isActive ? 1 : 0)
                    .scaleEffect(isActive ? 1 : 0.96)

                Capsule()
                    .fill(.black.opacity(0.6))
                    .frame(height: 20)
                    .padding(.horizontal, 12)
                    .blur(radius: 8)
                    .offset(y: isActive ? 12 : 0)
                    .opacity(isActive ? 1 : 0)

                Capsule()
                    .stroke(lineWidth: 1)
                    .foregroundStyle(.chipInactiveStroke)
                    .opacity(isActive ? 0 : 1)
            }
        }
        .animation(.easeInOut, value: isActive)
    }
}

#Preview {
    @Previewable @State var isActive: Bool = true

    VStack {
        HStack {
            CategoryChipView(isActive: isActive, title: "🔥 Test")
            .onTapGesture { isActive.toggle() }
            Spacer()
            Toggle("", isOn: $isActive)
        }
        Spacer()
    }
    .padding()
}
