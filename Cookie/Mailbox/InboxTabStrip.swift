import SwiftUI

/// The design's category tabs: large text with an unread count, plus page
/// dots. An approved exception to the native-navigation rule; paging itself
/// is the native page-style TabView in MailboxView.
struct InboxTabStrip: View {
    let tabs: [InboxTab]
    @Binding var selection: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 22) {
                        ForEach(tabs) { tab in
                            tabButton(tab)
                                .id(tab.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .onChange(of: selection, initial: true) { _, id in
                    withAnimation(reduceMotion ? nil : .default) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            pageDots
                .padding(.trailing, 14)
        }
    }

    private func tabButton(_ tab: InboxTab) -> some View {
        let selected = tab.id == selection
        return Button {
            selection = tab.id
        } label: {
            HStack(alignment: .top, spacing: 4) {
                Text(tab.name)
                    .font(CookieFont.text(.regular, size: 32, relativeTo: .largeTitle))
                    .lineLimit(1)
                if tab.unreadCount > 0 {
                    Text(tab.unreadCount, format: .number)
                        .font(CookieFont.mono(size: 12, relativeTo: .caption))
                        .foregroundStyle(selected ? Color.accentColor : Color(.muted))
                        .padding(.top, 6)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color(.primaryText) : Color(.muted))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityValue(tab.unreadCount > 0 ? Text("\(tab.unreadCount) unread") : Text(verbatim: ""))
    }

    private var pageDots: some View {
        let index = tabs.firstIndex { $0.id == selection } ?? 0
        return HStack(spacing: 5) {
            ForEach(tabs) { tab in
                Capsule()
                    .fill(tab.id == selection ? Color(.primaryText) : Color(.muted).opacity(0.5))
                    .frame(width: tab.id == selection ? 18 : 6, height: 6)
            }
        }
        .animation(reduceMotion ? nil : .default, value: selection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(index + 1) of \(tabs.count)"))
    }
}
