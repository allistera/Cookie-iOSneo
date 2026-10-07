import SwiftUI

/// The design's slide-over: the main content slides right to reveal the
/// sidebar beneath it, under a scrim. An approved exception to the
/// native-navigation rule, limited to this container.
struct DrawerContainer<Sidebar: View, Content: View>: View {
    @Binding var isOpen: Bool
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0

    /// 320pt, or the width minus a 48pt reveal of the content on narrow screens.
    static func width(for containerWidth: CGFloat) -> CGFloat {
        min(320, containerWidth - 48)
    }

    var body: some View {
        GeometryReader { geometry in
            let drawerWidth = Self.width(for: geometry.size.width)
            let offset = isOpen ? max(0, drawerWidth + dragOffset) : 0
            ZStack(alignment: .leading) {
                sidebar()
                    .frame(width: drawerWidth)
                    .accessibilityHidden(!isOpen)
                    .accessibilityAddTraits(.isModal)
                content()
                    .clipShape(.rect(topLeadingRadius: isOpen ? 28 : 0, bottomLeadingRadius: isOpen ? 28 : 0))
                    .shadow(color: Color(.primaryText).opacity(isOpen ? 0.10 : 0), radius: 16, x: -12)
                    .overlay {
                        if isOpen {
                            Button {
                                isOpen = false
                            } label: {
                                Color(.primaryText).opacity(0.32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Close sidebar")
                            .transition(.opacity)
                        }
                    }
                    .offset(x: offset)
                    .accessibilityHidden(isOpen)
                    .gesture(closeDrag, including: isOpen ? .all : .subviews)
            }
            .animation(reduceMotion ? nil : .default, value: isOpen)
            .onKeyPress(.escape) {
                guard isOpen else { return .ignored }
                isOpen = false
                return .handled
            }
        }
    }

    /// A leftward drag on the open content closes the drawer.
    private var closeDrag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                dragOffset = min(0, value.translation.width)
            }
            .onEnded { value in
                if value.translation.width < -60 {
                    isOpen = false
                }
                dragOffset = 0
            }
    }
}
