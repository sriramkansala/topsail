import PondKit
import SwiftUI

/// The pond, redrawn twelve times a second while it is on screen; one still frame with Reduce
/// Motion. The scene (PondKit) does the drawing; this only asks it for frames.
struct PondCanvas: View {
    let scene: PondScene
    /// Called after each frame, for whoever owns the scene to look at what changed.
    var onFrame: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: reduceMotion)) { timeline in
            if let image = scene.frame(at: timeline.date) {
                let _ = onFrame?()
                Image(decorative: image, scale: scene.config.scale)
                    .interpolation(.none)
            }
        }
        .frame(width: scene.config.size.width, height: scene.config.size.height)
    }
}

/// The Koi pond page: the pond fills the open island, behind the notch row, and dissolves into the
/// island's black under the tabs. Clicking the water drops food, and the koi come for it.
struct PondPageView: View {
    /// The open island.
    let size: CGSize
    let notchHeight: CGFloat

    var body: some View {
        if let scene = PondStore.page(size: size, notchHeight: notchHeight) {
            PondCanvas(scene: scene)
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { scene.feed(at: $0) }
                .accessibilityElement()
                .accessibilityLabel(Text("Koi pond"))
                .accessibilityHint(Text("Click the water to feed the koi"))
        }
    }
}

/// Now and then, while nothing else is beside the notch: two short wings of pond, and one koi
/// crossing from one to the other, out of sight under the camera on the way.
struct KoiPassWings: View {
    let notchSize: CGSize
    let wingWidth: CGFloat
    /// The koi has crossed, or the wings were taken away.
    let onFinished: () -> Void

    @State private var pass: KoiPass?

    var body: some View {
        ZStack {
            if let pass {
                PondCanvas(scene: pass.scene) {
                    if pass.isOver { DispatchQueue.main.async { finish() } }
                }
            }
        }
        .frame(width: notchSize.width + 2 * wingWidth, height: notchSize.height)
        .accessibilityHidden(true)
        .onAppear {
            pass = KoiPass(size: CGSize(width: notchSize.width + 2 * wingWidth, height: notchSize.height))
        }
        .onDisappear(perform: finish)
    }

    private func finish() {
        guard pass?.finished == false else { return }
        pass?.finished = true
        onFinished()
    }
}

/// One koi crossing the closed island's wings.
@MainActor
private final class KoiPass {
    let scene: PondScene
    let fish: PondScene.Koi
    var finished = false

    /// Each pass goes the other way from the last and brings the next koi.
    private static var count = 0

    init?(size: CGSize) {
        // The middle of the art, so each wing is open water with a pad's tip at its far end.
        let cropWidth: CGFloat = 0.72, cropHeight = cropWidth * 2.5 * size.height / size.width
        guard let scene = PondScene(config: .init(size: size, cell: 4, line: 0.75,
                                                  crop: CGRect(x: 0.14, y: 0.5 - cropHeight / 2, width: cropWidth, height: cropHeight),
                                                  koiLines: false)) else { return nil }
        let n = Self.count
        Self.count += 1
        let direction: Float = n % 2 == 0 ? 1 : -1, length: Float = 54, speed: Float = 32
        // Starts a little further out, so it arrives as the wings finish opening.
        let start = length * 0.6 + speed * 0.35
        fish = PondScene.Koi(kind: KoiKind.allCases[n % KoiKind.allCases.count], length: length,
                             x: direction > 0 ? -start : Float(size.width) + start, y: Float(size.height) / 2,
                             heading: direction > 0 ? 0 : .pi, speed: speed, swim: .pass(direction: direction),
                             fat: 2.1, seed: Int32(77 + n * 13))
        scene.add(fish)
        self.scene = scene
    }

    var isOver: Bool { !finished && fish.hasCrossed(width: Float(scene.config.size.width)) }
}

/// The pond page's scene, kept while Topsail runs, so the koi are where you left them.
@MainActor
enum PondStore {
    private static var scene: PondScene?

    static func page(size: CGSize, notchHeight: CGFloat) -> PondScene? {
        if let scene, scene.config.size == size { return scene }
        let below = size.height - notchHeight
        guard let scene = PondScene(config: .init(
            size: size, cell: 5, line: 1,
            fade: notchHeight * 0.3...notchHeight + 40,
            bounds: CGRect(x: 10, y: notchHeight + 24, width: size.width - 20, height: below - 34)
        )) else { return nil }
        let w = Float(size.width), top = Float(notchHeight), h = Float(below), length = w * 0.16
        scene.add(.init(kind: .kohaku, length: length, x: w * 0.45, y: top + h * 0.45, heading: -0.2, speed: 20, seed: 31))
        scene.add(.init(kind: .showa, length: length * 0.92, x: w * 0.7, y: top + h * 0.72, heading: 2.8, speed: 18, seed: 48))
        scene.add(.init(kind: .beni, length: length * 0.86, x: w * 0.28, y: top + h * 0.8, heading: 0.4, speed: 22, seed: 65))
        self.scene = scene
        return scene
    }
}
