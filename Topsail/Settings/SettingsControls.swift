import SwiftUI

// MARK: - Switch

/// Fluid Functionalism's switch: the thumb stretches under the pointer, squashes when pressed, and
/// can be dragged across. The label isn't drawn (a row has its own), but VoiceOver reads it.
struct FluidSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        FluidSwitch(isOn: configuration.$isOn)
            .accessibilityRepresentation {
                Toggle(isOn: configuration.$isOn) { configuration.label }
            }
    }
}

extension ToggleStyle where Self == FluidSwitchStyle {
    static var fluid: FluidSwitchStyle { FluidSwitchStyle() }
}

private struct FluidSwitch: View {
    @Binding var isOn: Bool

    private static let track = CGSize(width: 34, height: 20)
    private static let thumb: CGFloat = 16
    private static let inset: CGFloat = 2
    private static let hoverStretch: CGFloat = 2
    private static let pressStretch: CGFloat = 4
    private static let pressSquash: CGFloat = 4
    /// Pointer travel before a press becomes a drag; under it, it's still a click.
    private static let deadZone: CGFloat = 2

    @State private var hovering = false
    @State private var pressed = false
    /// The thumb's leading edge while it's dragged.
    @State private var dragged: CGFloat?
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var thumbSize: CGSize {
        let stretch = pressed ? Self.pressStretch : hovering ? Self.hoverStretch : 0
        return CGSize(width: Self.thumb + stretch, height: Self.thumb - (pressed ? Self.pressSquash : 0))
    }

    /// The far end, where the extra width grows inward so the outer edge stays put.
    private var end: CGFloat { Self.track.width - Self.inset - thumbSize.width }
    private var leading: CGFloat { dragged ?? (isOn ? end : Self.inset) }

    var body: some View {
        Capsule()
            .fill(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(hovering ? SettingsStyle.trackHover : SettingsStyle.track))
            .brightness(isOn && hovering ? -0.04 : 0)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
                    .frame(width: thumbSize.width, height: thumbSize.height)
                    .offset(x: leading)
            }
            .frame(width: Self.track.width, height: Self.track.height)
            .overlay {
                Capsule()
                    .inset(by: -3)
                    .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 2)
                    .opacity(focused ? 1 : 0)
            }
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle().inset(by: -6))
            .animation(reduceMotion ? nil : Motion.fluidModerate, value: isOn)
            .animation(reduceMotion ? nil : Motion.fluidModerate, value: pressed)
            .animation(reduceMotion ? nil : Motion.fluidModerate, value: hovering)
            .animation(reduceMotion ? nil : Motion.fluidModerate, value: dragged == nil)
            .onHover { hovering = $0 && isEnabled }
            .gesture(drag)
            .focusable(isEnabled, interactions: .activate)
            .focused($focused)
            .focusEffectDisabled()
            .onKeyPress(keys: [.space, .return]) { _ in
                isOn.toggle()
                return .handled
            }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isEnabled else { return }
                pressed = true
                guard dragged != nil || abs(value.translation.width) >= Self.deadZone else { return }
                let end = Self.track.width - Self.inset - Self.thumb - Self.pressStretch
                let start = isOn ? end : Self.inset
                dragged = min(max(start + value.translation.width, Self.inset), end)
            }
            .onEnded { value in
                guard isEnabled else { return }
                pressed = false
                if let x = dragged {
                    dragged = nil
                    let middle = x + (Self.thumb + Self.pressStretch) / 2
                    if (middle > Self.track.width / 2) != isOn { isOn.toggle() }
                } else if abs(value.translation.height) < Self.track.height * 2 {
                    isOn.toggle()
                }
            }
    }
}

// MARK: - Button

/// 28 pt buttons. Pressing pulls the surface in by exactly 1 pt on every side, at any width.
struct SettingsButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost }

    var kind: Kind = .secondary

    func makeBody(configuration: Configuration) -> some View {
        SettingsButtonBody(configuration: configuration, kind: kind)
    }
}

private struct SettingsButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: SettingsButtonStyle.Kind

    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(SettingsStyle.control)
            .lineLimit(1)
            .foregroundStyle(kind == .primary ? AnyShapeStyle(Color.white) : AnyShapeStyle(SettingsStyle.foreground))
            .padding(.horizontal, SettingsStyle.controlPadding)
            .frame(height: SettingsStyle.controlHeight)
            .background {
                RoundedRectangle(cornerRadius: SettingsStyle.controlRadius, style: .continuous)
                    .fill(fill)
                    .brightness(kind == .primary && hovering ? -0.05 : 0)
                    .padding(configuration.isPressed ? 1 : 0)
            }
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : Motion.fluidFast, value: configuration.isPressed)
            .animation(reduceMotion ? nil : Motion.fluidFast, value: hovering)
            .onHover { hovering = $0 && isEnabled }
    }

    private var fill: Color {
        switch kind {
        case .primary: return .accentColor
        case .secondary: return hovering ? SettingsStyle.tintHover : SettingsStyle.tint
        case .ghost: return hovering ? SettingsStyle.hover : .clear
        }
    }
}

extension ButtonStyle where Self == SettingsButtonStyle {
    static var settings: SettingsButtonStyle { SettingsButtonStyle() }
    static func settings(_ kind: SettingsButtonStyle.Kind) -> SettingsButtonStyle { SettingsButtonStyle(kind: kind) }
}

// MARK: - Select

/// A bordered trigger that opens a native menu.
struct SettingsSelect<Value: Hashable>: View {
    struct Option {
        let value: Value
        let title: LocalizedStringKey
        init(_ title: LocalizedStringKey, _ value: Value) {
            self.value = value
            self.title = title
        }
    }

    let label: LocalizedStringKey
    @Binding var selection: Value
    let options: [Option]

    var body: some View {
        Menu {
            Picker(label, selection: $selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Text(option.title).tag(option.value)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 8) {
                if let current = options.first(where: { $0.value == selection }) {
                    Text(current.title)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SettingsStyle.muted)
            }
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(SelectTriggerStyle())
        .fixedSize()
        .accessibilityLabel(Text(label))
    }
}

private struct SelectTriggerStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SelectTriggerBody(configuration: configuration)
    }
}

private struct SelectTriggerBody: View {
    let configuration: ButtonStyleConfiguration

    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(SettingsStyle.control)
            .foregroundStyle(SettingsStyle.foreground)
            .padding(.horizontal, SettingsStyle.fieldPadding)
            .frame(height: SettingsStyle.controlHeight)
            .background {
                RoundedRectangle(cornerRadius: SettingsStyle.controlRadius, style: .continuous)
                    .fill(hovering || configuration.isPressed ? SettingsStyle.hover : .clear)
                    .strokeBorder(SettingsStyle.fieldBorder, lineWidth: 1)
            }
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : Motion.fluidFast, value: hovering)
            .onHover { hovering = $0 && isEnabled }
    }
}

// MARK: - Fields

/// A bordered field's frame: the border darkens while it's focused.
struct SettingsFieldFrame: ViewModifier {
    let focused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: SettingsStyle.controlRadius, style: .continuous)
                    .fill(SettingsStyle.field)
                    .strokeBorder(focused ? SettingsStyle.fieldFocus : SettingsStyle.fieldBorder, lineWidth: 1)
            }
            .animation(reduceMotion ? nil : Motion.fluidFast, value: focused)
    }
}

/// A secret, on one line.
struct SettingsSecureField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    let onSubmit: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        SecureField("", text: $text)
            .textFieldStyle(.plain)
            .font(SettingsStyle.body)
            .focused($focused)
            .onSubmit(onSubmit)
            .padding(.horizontal, SettingsStyle.fieldPadding)
            .frame(height: SettingsStyle.controlHeight)
            .modifier(SettingsFieldFrame(focused: focused))
            .accessibilityLabel(Text(label))
    }
}

/// Several lines of text.
struct SettingsTextEditor: View {
    let label: LocalizedStringKey
    @Binding var text: String
    let height: CGFloat

    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(SettingsStyle.body)
            .scrollContentBackground(.hidden)
            .focused($focused)
            .padding(.horizontal, 5)
            .padding(.vertical, 8)
            .frame(height: height)
            .modifier(SettingsFieldFrame(focused: focused))
            .accessibilityLabel(Text(label))
    }
}
