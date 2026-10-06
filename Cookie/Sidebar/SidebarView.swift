import SwiftUI

/// The design's sidebar: Views, with the extra ones behind More/Less, and Labels.
struct SidebarView: View {
    @Bindable var sidebar: SidebarModel
    /// The inbox's unread count, shown beside Inbox.
    let unreadCount: Int
    let onSelect: (SidebarSelection) -> Void

    @AccessibilityFocusState private var focusedSelection: SidebarSelection?

    /// One Views row: where it goes, its symbol, its title and an icon tint.
    private struct Item: Identifiable {
        let selection: SidebarSelection
        let symbol: String
        let title: String
        var tint: Color?
        var id: SidebarSelection { selection }
    }

    private static let primaryViews = [
        Item(selection: .today, symbol: "sparkles", title: "AI Today", tint: Color(.todayAccent)),
        Item(selection: .folder(.inbox), symbol: "tray", title: "Inbox", tint: Color(.tagClayText)),
        Item(selection: .folder(.screening), symbol: "person", title: "New senders"),
    ]
    private static let moreViews = [
        Item(selection: .folder(.done), symbol: "checkmark.circle", title: "Done"),
        Item(selection: .folder(.sent), symbol: "paperplane", title: "Sent"),
        Item(selection: .drafts, symbol: "doc", title: "Drafts"),
        Item(selection: .folder(.spam), symbol: "exclamationmark.octagon", title: "Spam"),
        Item(selection: .folder(.blocked), symbol: "eye.slash", title: "Blocked"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                section("Views") {
                    ForEach(Self.primaryViews) { item in
                        row(item.selection, symbol: item.symbol, title: item.title, tint: item.tint)
                    }
                    moreToggle
                    if sidebar.showsMore {
                        ForEach(Self.moreViews) { item in
                            row(item.selection, symbol: item.symbol, title: item.title, tint: nil)
                        }
                    }
                }
                section("Labels") {
                    if sidebar.labelsFailed {
                        Text("Couldn't load labels.")
                            .font(CookieFont.text(.regular, size: 15, relativeTo: .subheadline))
                            .foregroundStyle(Color(.secondaryText))
                            .padding(.horizontal, 12)
                    }
                    ForEach(sidebar.labels) { label in
                        row(.folder(.label(label.name)), symbol: "tag", title: label.name, tint: tint(for: label))
                    }
                }
            }
            .padding(.top, 60)
            .padding(.horizontal, 10)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color(.sidebarBackground))
        .onChange(of: sidebar.isOpen) { _, open in
            if open { focusedSelection = sidebar.selection }
        }
    }

    private func section<Rows: View>(_ title: LocalizedStringKey, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(CookieFont.text(.semibold, size: 13, relativeTo: .footnote))
                .foregroundStyle(Color(.secondaryText))
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            rows()
        }
    }

    private func row(_ selection: SidebarSelection, symbol: String, title: String, tint: Color?) -> some View {
        let selected = sidebar.selection == selection
        let count = badge(for: selection)
        return Button {
            onSelect(selection)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(tint ?? Color(.secondaryText))
                    .frame(width: 22)
                Text(LocalizedStringKey(title))
                    .font(CookieFont.text(.regular, size: 17, relativeTo: .body))
                    .foregroundStyle(Color(.primaryText))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let count {
                    Text(count, format: .number)
                        .font(CookieFont.mono(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Color(.secondaryText))
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(selected ? Color(.selectedRow) : .clear, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityValue(count.map { Text("\($0) items") } ?? Text(verbatim: ""))
        .accessibilityFocused($focusedSelection, equals: selection)
    }

    private var moreToggle: some View {
        Button {
            sidebar.showsMore.toggle()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: sidebar.showsMore ? "chevron.up" : "chevron.down")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color(.secondaryText))
                    .frame(width: 22)
                Text(sidebar.showsMore ? "Less" : "More")
                    .font(CookieFont.text(.regular, size: 17, relativeTo: .body))
                    .foregroundStyle(Color(.secondaryText))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
        }
        .buttonStyle(.plain)
        .accessibilityValue(sidebar.showsMore ? Text("Expanded") : Text("Collapsed"))
    }

    private func badge(for selection: SidebarSelection) -> Int? {
        switch selection {
        case .folder(.inbox): unreadCount > 0 ? unreadCount : nil
        case .drafts: sidebar.drafts.isEmpty ? nil : sidebar.drafts.count
        default: nil
        }
    }

    /// A label's own colour tints only its icon, so any hue stays readable.
    private func tint(for label: MailLabel) -> Color? {
        guard let hex = label.color, hex.count == 7, hex.hasPrefix("#"), let value = UInt32(hex.dropFirst(), radix: 16)
        else { return nil }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }
}
