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
    @State private var metrics = Metrics()

    /// The container's safe-area width and insets, measured by a probe that
    /// stays inside the safe area while the drawer itself ignores it.
    private struct Metrics: Equatable {
        var width: CGFloat = 0
        var safeArea = EdgeInsets()
    }

    /// 320pt, or the width minus a 48pt reveal of the content on narrow screens.
    static func width(for containerWidth: CGFloat) -> CGFloat {
        max(0, min(320, containerWidth - 48))
    }

    var body: some View {
        let drawerWidth = Self.width(for: metrics.width)
        let offset = isOpen ? max(0, drawerWidth + dragOffset) : 0
        ZStack {
            Color.clear
                .onGeometryChange(for: Metrics.self) { proxy in
                    Metrics(width: proxy.size.width, safeArea: proxy.safeAreaInsets)
                } action: { measured in
                    metrics = measured
                }
            // The drawer ignores the safe area so the content's background and
            // clip reach the status bar and home indicator. The content's
            // NavigationStack insets itself; the sidebar is inset explicitly.
            ZStack(alignment: .leading) {
                sidebar()
                    .safeAreaPadding(metrics.safeArea)
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
                            .simultaneousGesture(closeDrag)
                        }
                    }
                    .offset(x: offset)
                    .accessibilityHidden(isOpen)
            }
            .ignoresSafeArea()
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
