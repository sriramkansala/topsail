#if DEBUG
import AppKit
import QuartzCore
import SwiftUI

/// The marker behind a traced element: a real, empty view that SwiftUI moves, scales and fades
/// with the element, so the tracer reads what was actually applied on screen that frame (the
/// layer tree's own numbers), not what the model asked for.
final class TraceProbeView: NSView {
    private static var count = 0

    var name = ""
    var isControl = false
    /// Tells one instance of a name from another: two on screen at once is a second copy.
    let serial: Int

    override init(frame: NSRect) {
        Self.count += 1
        serial = Self.count
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct TraceProbe: NSViewRepresentable {
    let name: String
    let isControl: Bool

    func makeNSView(context: Context) -> TraceProbeView {
        let view = TraceProbeView(frame: .zero)
        view.name = name
        view.isControl = isControl
        MotionTracer.shared.add(view)
        return view
    }

    func updateNSView(_ view: TraceProbeView, context: Context) {
        view.name = name
        view.isControl = isControl
    }
}

/// The corner radii the island's shape was last drawn with. `NotchShape.path(in:)` reports them,
/// so they are the radii on screen, mid-spring included.
enum NotchRadiiTrace {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var radii: (top: CGFloat, bottom: CGFloat) = (0, 0)

    static func note(top: CGFloat, bottom: CGFloat) {
        guard Continuity.isActive else { return }
        lock.lock()
        radii = (top, bottom)
        lock.unlock()
    }

    static var last: (top: CGFloat, bottom: CGFloat) {
        lock.lock()
        defer { lock.unlock() }
        return radii
    }
}

/// Writes what the island did, one JSON line per display frame: the island's size, centre and
/// corner radii, and the frame and opacity of every element tagged with `.traced(_:)`. It also
/// fires a cell's triggers from the same display-link callback, so each lands on an exact frame.
///
/// Positions are in points, x from the notch's centre, y down from the top of the screen.
@MainActor
final class MotionTracer: NSObject {
    static let shared = MotionTracer()

    struct Step {
        /// Milliseconds after tracing starts.
        let at: Double
        let label: String
        let run: @MainActor () -> Void
    }

    /// The view the island is drawn in; positions are read against it.
    weak var host: NSView?
    /// The model's own account of the frame (state, page, toast…), added to each line.
    var state: @MainActor () -> [String: String] = { [:] }

    private let probes = NSHashTable<TraceProbeView>.weakObjects()
    private var link: CADisplayLink?
    private var lines: [String] = []
    private var steps: [Step] = []
    private var startTime: CFTimeInterval = 0
    private(set) var isTracing = false

    nonisolated func add(_ probe: TraceProbeView) {
        MainActor.assumeIsolated { probes.add(probe) }
    }

    /// Starts a trace. `header` is the cell's own description, written as the first line.
    func begin(header: String, steps: [Step]) {
        guard let host, !isTracing else { return }
        lines = [header]
        self.steps = steps.sorted { $0.at < $1.at }
        startTime = CACurrentMediaTime()
        isTracing = true
        let link = host.displayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// Stops the trace and returns its lines.
    func end() -> [String] {
        link?.invalidate()
        link = nil
        isTracing = false
        steps = []
        defer { lines = [] }
        return lines
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard isTracing, let host, let root = host.layer else { return }
        let elapsed = (CACurrentMediaTime() - startTime) * 1000

        var fired: [String] = []
        while let step = steps.first, step.at <= elapsed {
            steps.removeFirst()
            step.run()
            fired.append(step.label)
        }

        var line = "{\"t\":\(Self.number(elapsed))"
        // The first frame carries the host clock, so a film of the screen can be lined up with it.
        if lines.count == 1 { line += ",\"clock\":\(startTime)" }
        let centre = host.bounds.midX
        var elements: [String: [String]] = [:]
        var island = ""
        for probe in probes.allObjects {
            guard probe.window != nil, let layer = probe.layer else { continue }
            let rect = layer.convert(layer.bounds, to: root)
            var opacity: Float = 1
            var walker: CALayer? = layer
            while let current = walker, current !== root {
                opacity *= current.isHidden ? 0 : current.opacity
                walker = current.superlayer
            }
            // Detached from the island's tree (a view on its way out): not on screen.
            guard walker === root else { continue }
            let x = rect.minX - centre
            if probe.name == "island" {
                let radii = NotchRadiiTrace.last
                island = "[\(Self.number(rect.width)),\(Self.number(rect.height)),\(Self.number(rect.midX - centre)),"
                    + "\(Self.number(rect.minY)),\(Self.number(radii.top)),\(Self.number(radii.bottom))]"
                continue
            }
            let entry = "[\(probe.serial),\(Self.number(x)),\(Self.number(rect.minY)),\(Self.number(rect.width)),"
                + "\(Self.number(rect.height)),\(Self.number(Double(opacity))),\(probe.isControl ? 1 : 0)]"
            elements[probe.name, default: []].append(entry)
        }
        if !island.isEmpty { line += ",\"i\":\(island)" }
        line += ",\"e\":{"
        line += elements.keys.sorted().map { "\"\($0)\":[\(elements[$0]!.joined(separator: ","))]" }.joined(separator: ",")
        line += "},\"s\":{"
        let state = state()
        line += state.keys.sorted().map { "\"\($0)\":\"\(state[$0]!)\"" }.joined(separator: ",")
        line += "}"
        if !fired.isEmpty {
            line += ",\"ev\":[" + fired.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        }
        line += "}"
        lines.append(line)
    }

    /// The middle of a traced element, in its window's coordinates (for a click).
    func windowCentre(of name: String) -> CGPoint? {
        guard let probe = probes.allObjects.first(where: { $0.name == name && $0.window != nil }) else { return nil }
        let rect = probe.convert(probe.bounds, to: nil)
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    private static func number(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }

    private static func number(_ value: CGFloat) -> String { number(Double(value)) }
}

struct TracedModifier: ViewModifier {
    let name: String
    let isControl: Bool

    func body(content: Content) -> some View {
        if Continuity.isActive {
            content.background(TraceProbe(name: name, isControl: isControl).allowsHitTesting(false))
        } else {
            content
        }
    }
}
#endif
