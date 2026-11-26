import SwiftUI

/// The teleprompter inside the open island: the script, centred, scrolling up from just under the
/// camera and fading out at the top and bottom edges, over a row of controls (restart, play or
/// pause, speed, close). Space plays and pauses, ↑ ↓ change speed, Esc closes; scrolling over
/// the script moves it by hand.
struct TeleprompterView: View {
    @ObservedObject var controller: TeleprompterController
    let fontSize: CGFloat

    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            script
            controls
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.space) { controller.togglePlay(); return .handled }
        .onKeyPress(.upArrow) { controller.faster(); return .handled }
        .onKeyPress(.downArrow) { controller.slower(); return .handled }
        .onKeyPress(.escape) { controller.stop(); return .handled }
    }

    private var script: some View {
        GeometryReader { geometry in
            TimelineView(.animation(paused: !controller.isPlaying)) { context in
                Text(controller.script.isEmpty ? Self.placeholder : controller.script)
                    .font(.system(size: fontSize, weight: .semibold))
                    .lineSpacing(fontSize * 0.3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(controller.script.isEmpty ? 0.5 : 1))
                    .frame(width: geometry.size.width)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { controller.setTextHeight($0) }
                    // The first line starts a little below the top edge's fade.
                    .offset(y: IslandLayout.teleprompterLeadIn - controller.offset(at: context.date))
            }
        }
        .clipped()
        .mask(
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.15),
                                   .init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        )
        .contentShape(Rectangle())
        .onScrollWheel { controller.nudge(by: -$0) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Teleprompter script")
        .accessibilityValue(controller.script)
    }

    private var controls: some View {
        HStack(spacing: 18) {
            ControlButton(symbol: "backward.end.fill", help: "Back to the start", action: controller.restart)
            ControlButton(symbol: controller.isPlaying ? "pause.fill" : "play.fill",
                          help: controller.isPlaying ? "Pause (Space)" : "Play (Space)", prominent: true,
                          action: controller.togglePlay)
            HStack(spacing: 6) {
                ControlButton(symbol: "minus", help: "Slower (↓)", action: controller.slower)
                Text("\(Int(controller.speed))")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundColor(.white.opacity(0.6))
                    .frame(minWidth: 26)
                    .contentTransition(.numericText(value: controller.speed))
                    .animation(reduceMotion ? nil : Motion.base, value: controller.speed)
                ControlButton(symbol: "plus", help: "Faster (↑)", action: controller.faster)
            }
            ControlButton(symbol: "xmark", help: "Close (Esc)", action: controller.stop)
        }
        .frame(height: IslandLayout.teleprompterControlsHeight)
    }

    static let placeholder = String(localized: "Add your script in Settings › Features › Teleprompter.")
}

/// A round control under the script; the play button is the filled one.
private struct ControlButton: View {
    let symbol: String
    let help: LocalizedStringKey
    var prominent = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 12 : 10.5, weight: .bold))
                .foregroundColor(prominent ? .black : .white.opacity(hovering ? 1 : 0.7))
                .frame(width: prominent ? 30 : 24, height: prominent ? 30 : 24)
                .background(Circle().fill(prominent ? Color.white : Color.white.opacity(hovering ? 0.16 : 0.09)))
                .contentShape(Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.pressable(.normal, hoverWash: false))
        .onHover { hovering = $0 }
        .animation(Motion.hover, value: hovering)
        .help(help)
    }
}

private extension View {
    /// Scroll-wheel and trackpad scrolling over the view, in points (positive = content moves down).
    func onScrollWheel(_ action: @escaping (CGFloat) -> Void) -> some View {
        overlay(ScrollWheelCatcher(action: action))
    }
}

/// Catches scroll-wheel events over a SwiftUI view (SwiftUI has no modifier for it outside a
/// ScrollView).
private struct ScrollWheelCatcher: NSViewRepresentable {
    let action: (CGFloat) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.action = action
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.action = action
    }

    final class CatcherView: NSView {
        var action: ((CGFloat) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            action?(event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 10)
        }
    }
}

/// The grip below the teleprompter: drag it to pull the script down or push it back up. It follows
/// the pointer directly and settles on a spring when let go; ↑ ↓ adjust it for VoiceOver.
struct TeleprompterHandle: View {
    let onDrag: (CGFloat) -> Void
    let onEnd: (CGFloat) -> Void

    @State private var hovering = false
    @State private var dragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(hovering || dragging ? 0.95 : 0.7))
            .frame(width: hovering || dragging ? 48 : 40, height: 5)
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            .frame(width: 120, height: 22)
            .contentShape(Rectangle())
            .pointerStyle(.frameResize(position: .bottom))
            .onHover { hovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        dragging = true
                        onDrag(value.translation.height)
                    }
                    .onEnded { value in
                        dragging = false
                        onEnd(value.predictedEndTranslation.height)
                    }
            )
            .animation(reduceMotion ? nil : Motion.hover, value: hovering || dragging)
            .accessibilityElement()
            .accessibilityLabel("Teleprompter height")
            .accessibilityHint("Drag to pull the teleprompter down or push it up")
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = direction == .increment ? 40 : -40
                onDrag(step)
                onEnd(step)
            }
    }
}
