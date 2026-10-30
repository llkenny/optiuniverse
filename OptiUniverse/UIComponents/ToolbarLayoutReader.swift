import SwiftUI

/// Reads the native bar layout without tying control placement to a device model or size.
struct ToolbarLayoutReader<Content: View>: View {
    @ViewBuilder var content: (Bool) -> Content

    var body: some View {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            VerticalToolbarLayoutReader(content: content)
        } else {
            content(false)
        }
        #else
        content(false)
        #endif
    }
}

#if os(iOS)
@available(iOS 27.1, *)
private struct VerticalToolbarLayoutReader<Content: View>: View {
    @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge
    @ViewBuilder var content: (Bool) -> Content

    var body: some View {
        content(toolbarVerticalEdge != nil)
    }
}
#endif
