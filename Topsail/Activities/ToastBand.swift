import SwiftUI

/// The band at the base of the island where toasts show: "Copied", Keep Awake switched, a level
/// being adjusted. The island's shape reaches down by exactly this band, closed or open, and the
/// toast slides up into it from under the bottom edge on the same spring (`Motion.toast`); it
/// leaves the same way. Nothing above the band moves, so a toast never changes the page or
/// covers a control.
///
/// `NotchView` hangs the band from the bottom edge of what the island shows. Each kind of toast
/// has its own label here, always in place and shown or hidden by state rather than inserted and
/// removed: so a toast that is halfway in when something else happens (the island closing, a
/// second toast) simply carries on from where it is.
struct ToastBand: View {
    let toast: TransientActivity?

    /// What each kind last said, which it keeps saying while it leaves.
    @State private var last: [String: ActivityKind] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One label per kind, with what it says before it has ever been shown.
    private static let kinds: [ActivityKind] = [
        .copied(snippet: nil), .keepAwake(on: true), .volume(level: 0, muted: false), .brightness(level: 0),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Self.kinds, id: \.traceName) { placeholder in
                let name = placeholder.traceName
                let showing = toast?.kind.traceName == name
                ToastLabel(kind: (showing ? toast?.kind : last[name]) ?? placeholder)
                    .traced("toast.\(name)")
                    .modifier(ToastPlacement(showing: showing, reduceMotion: reduceMotion))
                    .accessibilityHidden(!showing)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: IslandLayout.toastBandHeight, alignment: .top)
        .allowsHitTesting(false)
        .onChange(of: toast) { _, toast in
            if let kind = toast?.kind { last[kind.traceName] = kind }
        }
    }
}

/// Where a toast's label is: in the band, or just under it and unseen. It moves between the two
/// on whatever animation changed the toast (`Motion.toast`), together with the island's shape.
/// With Reduce Motion it stays put and fades.
private struct ToastPlacement: ViewModifier {
    let showing: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content.animation(Motion.fadeFast) { $0.opacity(showing ? 1 : 0) }
        } else {
            content
                .opacity(showing ? 1 : 0)
                .offset(y: showing ? 0 : IslandLayout.toastSlide)
        }
    }
}

/// What a toast says: a neutral grey icon, the words, and a quieter detail.
private struct ToastLabel: View {
    let kind: ActivityKind

    /// Toast icons are never coloured: they confirm, they don't alert.
    private static let grey = Color(white: 0.62)
    private static let quiet = Color.white.opacity(0.45)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            switch kind {
            case .copied(let snippet):
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(white: 0.1), Self.grey)
                    .font(.system(size: 12, weight: .semibold))
                Text("Copied")
                    .foregroundStyle(.white)
                    .fixedSize()
                if let snippet, !snippet.isEmpty {
                    Text(verbatim: snippet)
                        .foregroundStyle(Self.quiet)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            case .keepAwake(let on):
                Image(systemName: on ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Self.grey)
                Text("Keep Awake")
                    .foregroundStyle(.white)
                    .fixedSize()
                Text(on ? "On" : "Off")
                    .foregroundStyle(Self.quiet)
                    .fixedSize()
            case .volume, .brightness:
                LevelGlyph(kind: kind, size: 11, tint: Self.grey)
                    .frame(width: 18)
                if let reading = kind.levelReading {
                    LevelMeter(level: reading.value, color: .white, dimmed: reading.dimmed, inset: 0)
                        .frame(width: 86)
                }
                Text(verbatim: "\(kind.levelPercent ?? 0)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(Self.quiet)
                    .contentTransition(.numericText(value: Double(kind.levelPercent ?? 0)))
                    .animation(reduceMotion ? nil : Motion.base, value: kind.levelPercent)
                    .frame(width: 24, alignment: .trailing)
            default:
                EmptyView()
            }
        }
        .font(.system(size: 12, weight: .medium))
        .tracking(-0.1)
        .padding(.horizontal, 14)
        // In the top of the band, clear of the island's rounded bottom corners.
        .frame(height: IslandLayout.toastBandHeight - 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: Text {
        switch kind {
        case .copied: return Text("Copied")
        case .keepAwake(let on): return on ? Text("Keep Awake, on") : Text("Keep Awake, off")
        default: return Text(verbatim: "\(kind.levelPercent ?? 0)%")
        }
    }
}
