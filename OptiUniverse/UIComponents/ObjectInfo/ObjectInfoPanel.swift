import SwiftUI

/// Keeps dismissal and route controls reachable while the details scroll independently.
struct ObjectInfoPanel: View {
    let entity: ObjectInfoViewEntity
    var isSidePanel = false
    let onDismiss: () -> Void

    @ScaledMetric(relativeTo: .title2) private var titleSize = 27
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let inlineRoute = geometry.size.height < 240
            VStack(spacing: 0) {
                header(inlineRoute: inlineRoute)
                ScrollView {
                    ObjectInfoView(entity: entity, availableWidth: geometry.size.width)
                }
                .scrollBounceBehavior(.basedOnSize)

                if entity.isNavigable, !inlineRoute {
                    Button(action: entity.navigationButtonAction) {
                        NeonButtonView(title: entity.navigationButtonTitle)
                    }
                    .buttonStyle(NeonButtonStyle())
                    .padding(12)
                }
            }
        }
        .background(OptiColor.objectInfoSurface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.panel))
        .offset(y: isSidePanel ? 0 : dragOffset)
        .animation(.default, value: dragOffset)
        .accessibilityIdentifier(isSidePanel ? "objectInfoSidePanel" : "objectInfoBottomPanel")
    }

    private func header(inlineRoute: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(entity.title)
                .font(.system(size: titleSize))
                .foregroundStyle(OptiColor.objectInfoTextPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if entity.isNavigable, inlineRoute {
                Button("Route", action: entity.navigationButtonAction)
                    .buttonStyle(.bordered)
                    .accessibilityLabel(entity.navigationButtonTitle)
            }
            Button(action: onDismiss) {
                Label("Close", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close object details")
        }
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .gesture(dismissGesture)
    }

    private var dismissGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                if !isSidePanel { state = max(value.translation.height, 0) }
            }
            .onEnded { value in
                guard !isSidePanel else { return }
                if value.translation.height > 80 || value.predictedEndTranslation.height > 140 {
                    onDismiss()
                }
            }
    }
}
