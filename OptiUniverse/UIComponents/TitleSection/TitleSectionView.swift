//
//  TitleSectionView.swift
//  OptiUniverse
//
//  Created by max on 08.04.2026.
//

import SwiftUI

struct TitleSectionView: View {
    @State var name: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hi \(name),")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Color(.midEmphasized))
            HStack {
                Text("Where do you wanna go?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color(.highEmphasized))
                    .lineLimit(2)
                Spacer(minLength: 60)
            }
        }
    }
}

#Preview {
    VStack {
        TitleSectionView(name: "Stranger")
        Spacer()
    }
    .padding(.horizontal)
}
