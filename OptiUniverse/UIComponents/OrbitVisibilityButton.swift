import SwiftUI
import UniverseModule

/// The preference belongs to the app; the renderer only receives its current value.
struct OrbitVisibilityButton: View {
    @AppStorage("showsCelestialOrbits") private var showsOrbitLines = false
    let resources: UniverseModuleResources

    var body: some View {
        Button {
            showsOrbitLines.toggle()
        } label: {
            Label(showsOrbitLines ? "Hide orbits" : "Show orbits", systemImage: "circle.dotted")
        }
        .labelStyle(.iconOnly)
        .tint(showsOrbitLines ? Color.accentColor : nil)
        .accessibilityAddTraits(showsOrbitLines ? .isSelected : [])
        .accessibilityIdentifier("orbitVisibilityToggle")
        .onChange(of: showsOrbitLines, initial: true) { _, isVisible in
            resources.setOrbitLinesVisible(isVisible)
        }
    }
}

/// Native bars can change axis without replacing the mounted universe scene.
struct OrbitSceneToolbar: ToolbarContent {
    let resources: UniverseModuleResources
    let usesVerticalToolbar: Bool
    let showsObjectDetails: Bool
    let onShowDetails: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            if usesVerticalToolbar { Spacer() }
            OrbitVisibilityButton(resources: resources)
            if !usesVerticalToolbar { Spacer() }
            if showsObjectDetails {
                Button("Object details", systemImage: "binoculars", action: onShowDetails)
            }
        }
    }
}
