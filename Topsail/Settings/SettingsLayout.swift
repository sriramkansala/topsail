import SwiftUI

// MARK: - Page

/// A pane: its title and what it's for, pinned above its sections.
struct SettingsPage<Content: View>: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @ViewBuilder let content: Content

    @State private var scrolled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: SettingsStyle.textGap) {
                Text(title)
                    .font(SettingsStyle.title)
                    .foregroundStyle(SettingsStyle.foreground)
                    .accessibilityAddTraits(.isHeader)
                Text(detail)
                    .font(SettingsStyle.caption)
                    .foregroundStyle(SettingsStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SettingsStyle.pagePadding)
            .padding(.top, SettingsStyle.headerTop)
            .padding(.bottom, SettingsStyle.headerBottom)

            SettingsSeparator()
                .opacity(scrolled ? 1 : 0)
                .animation(reduceMotion ? nil : Motion.fluidFast, value: scrolled)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: SettingsStyle.sectionGap) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SettingsStyle.pagePadding)
                .padding(.top, 6)
                .padding(.bottom, SettingsStyle.pagePadding)
            }
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 2 } action: { _, now in
                scrolled = now
            }
        }
    }
}

// MARK: - Section

/// A heading over a card, and a note under it.
struct SettingsSection<Content: View>: View {
    var title: LocalizedStringKey?
    var note: LocalizedStringKey?
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey? = nil, note: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsStyle.headingGap) {
            if let title {
                Text(title)
                    .font(SettingsStyle.heading)
                    .foregroundStyle(SettingsStyle.foreground)
                    .accessibilityAddTraits(.isHeader)
            }
            SettingsCard { content }
            if let note {
                Text(note)
                    .font(SettingsStyle.caption)
                    .lineSpacing(SettingsStyle.captionSpacing)
                    .foregroundStyle(SettingsStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Rows on one surface, with a hairline between them.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    if row.id != rows.first?.id {
                        SettingsSeparator()
                            .padding(.horizontal, SettingsStyle.rowHorizontal)
                    }
                    row
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: SettingsStyle.cardRadius, style: .continuous)
                .fill(SettingsStyle.card)
                .strokeBorder(SettingsStyle.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: SettingsStyle.cardRadius, style: .continuous))
    }
}

/// A feature's own options, set into the card under its row.
struct SettingsPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    if row.id != rows.first?.id {
                        SettingsSeparator()
                            .padding(.horizontal, SettingsStyle.rowVertical)
                    }
                    row
                }
            }
        }
        .environment(\.settingsRowInset, SettingsStyle.rowVertical)
        .background {
            RoundedRectangle(cornerRadius: SettingsStyle.panelRadius, style: .continuous)
                .fill(SettingsStyle.panel)
                .strokeBorder(SettingsStyle.border, lineWidth: 1)
        }
        .padding(.leading, SettingsStyle.textInset)
        .padding(.trailing, SettingsStyle.rowHorizontal)
        .padding(.bottom, SettingsStyle.rowHorizontal)
    }
}

struct SettingsSeparator: View {
    var body: some View {
        Rectangle()
            .fill(SettingsStyle.border)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

// MARK: - Row

extension EnvironmentValues {
    /// How far a row's content stands from its surface's sides.
    @Entry var settingsRowInset: CGFloat = SettingsStyle.rowHorizontal
}

/// A label, what it does, and its control on the right.
struct SettingsRow<Icon: View, Control: View>: View {
    let title: Text
    var detail: Text?
    /// A dot before the detail: how the thing stands.
    var status: Color?
    @ViewBuilder let icon: Icon
    @ViewBuilder let control: Control

    @Environment(\.settingsRowInset) private var inset

    init(_ title: Text, detail: Text? = nil, status: Color? = nil,
         @ViewBuilder icon: () -> Icon, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.status = status
        self.icon = icon()
        self.control = control()
    }

    var body: some View {
        HStack(spacing: SettingsStyle.rowGap) {
            HStack(spacing: SettingsStyle.iconGap) {
                icon
                VStack(alignment: .leading, spacing: SettingsStyle.textGap) {
                    title
                        .font(SettingsStyle.body)
                        .foregroundStyle(SettingsStyle.foreground)
                    if let detail {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            if let status {
                                Circle()
                                    .fill(status)
                                    .frame(width: SettingsStyle.statusDot, height: SettingsStyle.statusDot)
                                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                                    .accessibilityHidden(true)
                            }
                            detail
                                .font(SettingsStyle.caption)
                                .lineSpacing(SettingsStyle.captionSpacing)
                                .foregroundStyle(SettingsStyle.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            control
                .fixedSize()
        }
        .padding(.horizontal, inset)
        .padding(.vertical, detail == nil ? 8 : SettingsStyle.rowVertical)
        .frame(minHeight: SettingsStyle.rowMinHeight)
    }
}

extension SettingsRow where Icon == EmptyView {
    init(_ title: Text, detail: Text? = nil, status: Color? = nil, @ViewBuilder control: () -> Control) {
        self.init(title, detail: detail, status: status, icon: { EmptyView() }, control: control)
    }
}

/// A quiet line and the button that acts on it, in a panel.
struct SettingsHintRow<Control: View>: View {
    let text: Text
    @ViewBuilder let control: Control

    var body: some View {
        SettingsRow(text.font(SettingsStyle.caption).foregroundStyle(SettingsStyle.muted)) { control }
    }
}

/// A row that's a switch.
struct SettingsToggle<Icon: View>: View {
    let title: Text
    var detail: Text?
    @Binding var isOn: Bool
    @ViewBuilder let icon: Icon

    init(_ title: Text, detail: Text? = nil, isOn: Binding<Bool>, @ViewBuilder icon: () -> Icon) {
        self.title = title
        self.detail = detail
        _isOn = isOn
        self.icon = icon()
    }

    var body: some View {
        SettingsRow(title, detail: detail, icon: { icon }) {
            Toggle(isOn: $isOn) { title }
                .toggleStyle(.fluid)
        }
    }
}

extension SettingsToggle where Icon == EmptyView {
    init(_ title: LocalizedStringKey, detail: String? = nil, isOn: Binding<Bool>) {
        self.init(Text(title), detail: detail.map { Text($0) }, isOn: isOn, icon: { EmptyView() })
    }
}

/// A glyph on a quiet tile; lit while its feature is on.
struct SettingsGlyph: View {
    let symbol: String
    var lit = true

    var body: some View {
        RoundedRectangle(cornerRadius: SettingsStyle.iconRadius, style: .continuous)
            .fill(SettingsStyle.tint)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(lit ? SettingsStyle.foreground : SettingsStyle.muted)
            }
            .frame(width: SettingsStyle.iconSize, height: SettingsStyle.iconSize)
            .accessibilityHidden(true)
    }
}

/// An installed app's own icon.
struct SettingsAppIcon: View {
    let bundleID: String

    var body: some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
            } else {
                Color.clear
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

// MARK: - Callout

/// Something that needs doing (a permission, usually), under the row it's about.
struct SettingsCallout: View {
    let text: String
    let button: String
    /// Lined up with its row's text, past the row's icon.
    var indented = false
    let action: () -> Void

    @Environment(\.settingsRowInset) private var inset

    var body: some View {
        HStack(spacing: SettingsStyle.iconGap) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(SettingsStyle.warning)
                .accessibilityHidden(true)
            Text(text)
                .font(SettingsStyle.caption)
                .lineSpacing(SettingsStyle.captionSpacing)
                .foregroundStyle(SettingsStyle.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(button, action: action)
                .buttonStyle(.settings)
                .fixedSize()
        }
        .padding(.leading, SettingsStyle.rowVertical)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: SettingsStyle.panelRadius, style: .continuous)
                .fill(SettingsStyle.warning.opacity(0.10))
                .strokeBorder(SettingsStyle.warning.opacity(0.22), lineWidth: 1)
        }
        .padding(.leading, indented ? SettingsStyle.textInset : inset)
        .padding(.trailing, inset)
        .padding(.bottom, inset)
    }
}

/// A line of text under a row: an error, or something to know.
struct SettingsNote: View {
    let text: Text
    var color: Color = SettingsStyle.muted

    @Environment(\.settingsRowInset) private var inset

    var body: some View {
        text
            .font(SettingsStyle.caption)
            .lineSpacing(SettingsStyle.captionSpacing)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, inset)
            .padding(.vertical, SettingsStyle.rowVertical)
    }
}

/// A row and what belongs to it, as one: no hairline between them.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
    }
}

// MARK: - Sidebar

/// The panes. One highlight glides between rows under the pointer, and the selection glides when
/// it moves; a selected row takes no part in hover. Up and down arrows move it.
struct SettingsSidebar: View {
    @Binding var pane: SettingsView.Pane

    @State private var hovered: Int?
    @State private var highlight: Int = 0
    /// Focused from the keyboard, so it's shown; a click focuses it too, for the arrow keys.
    @State private var showsFocus = false
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let panes = SettingsView.Pane.allCases
    private static let step = SettingsStyle.sidebarRowHeight + SettingsStyle.sidebarRowGap

    var body: some View {
        ZStack(alignment: .topLeading) {
            fill(SettingsStyle.hover)
                .offset(y: CGFloat(highlight) * Self.step)
                .opacity(hovered == nil ? 0 : 1)
            fill(SettingsStyle.selected)
                .offset(y: CGFloat(selectedIndex) * Self.step)
            VStack(spacing: SettingsStyle.sidebarRowGap) {
                ForEach(panes) { item in
                    SidebarRow(pane: item, selected: item == pane) {
                        focused = true
                        select(item)
                    }
                }
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): hover(at: point.y)
            case .ended: leave()
            }
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onChange(of: focused) { _, now in
            showsFocus = now && NSApp.currentEvent?.type == .keyDown
        }
        .onKeyPress(.upArrow) { move(-1) }
        .onKeyPress(.downArrow) { move(1) }
        .padding(.horizontal, SettingsStyle.sidebarPadding)
        .padding(.top, SettingsStyle.sidebarTop)
        .frame(width: SettingsStyle.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: SettingsStyle.sidebarRadius, style: .continuous)
                .fill(SettingsStyle.sidebar)
                .strokeBorder(showsFocus ? SettingsStyle.fieldFocus : SettingsStyle.border, lineWidth: 1)
        }
        .padding(SettingsStyle.sidebarInset)
    }

    private var selectedIndex: Int { panes.firstIndex(of: pane) ?? 0 }

    private func fill(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: SettingsStyle.sidebarRowRadius, style: .continuous)
            .fill(color)
            .frame(height: SettingsStyle.sidebarRowHeight)
    }

    private func select(_ item: SettingsView.Pane) {
        leave()
        Motion.perform(Motion.fluidModerate) { pane = item }
    }

    private func move(_ offset: Int) -> KeyPress.Result {
        let target = selectedIndex + offset
        guard panes.indices.contains(target) else { return .ignored }
        select(panes[target])
        return .handled
    }

    private func hover(at y: CGFloat) {
        let index = Int(y / Self.step)
        guard y >= 0, panes.indices.contains(index), index != selectedIndex else { return leave() }
        guard index != hovered else { return }
        if hovered == nil {
            // Entering: appears on the row under the pointer, rather than sliding from the last one.
            highlight = index
            Motion.perform(Motion.fluidFast) { hovered = index }
        } else {
            Motion.perform(Motion.fluidFast) {
                highlight = index
                hovered = index
            }
        }
    }

    private func leave() {
        guard hovered != nil else { return }
        Motion.perform(Motion.fluidExit) { hovered = nil }
    }
}

private struct SidebarRow: View {
    let pane: SettingsView.Pane
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: pane.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 20, height: 20)
                Text(pane.title)
                    .font(selected ? SettingsStyle.label : SettingsStyle.body)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? SettingsStyle.foreground : SettingsStyle.muted)
            .padding(.horizontal, 8)
            .frame(height: SettingsStyle.sidebarRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
