import CoreGraphics
import Foundation

/// A koi pond in pixel art, drawn on a 45° diamond lattice.
///
/// Every cell is one "pixel", a small diamond. Neighbouring cells of one colour merge; wherever two
/// colours meet, a thin ink line runs along the boundary, like a text-mode grid tilted 45°. The
/// still pond is sampled from `PondArt` and pushed through hue ramps with horizontal brush-streak
/// noise and ordered dithering; koi, their shadows, ripples and glints are drawn into the same
/// lattice every frame. The palette is the night one: the water sinks almost to black, so the
/// pond reads as part of the island and only the koi and the lilies keep their light.
///
/// The prototype this was ported from, with the day palette and the pipeline stage by stage, is in
/// `prototypes/koi-pond` at the top of the repository.
@MainActor
public final class PondScene {
    public struct Config {
        /// The pond, in points.
        public var size: CGSize
        public var scale: CGFloat = 2
        /// A diamond's width, in points.
        public var cell: CGFloat = 5
        /// The ink lines' width, in points.
        public var line: CGFloat = 1
        /// The part of the art (0...1 each way) that fills the pond; nil fits it to cover.
        public var crop: CGRect? = nil
        /// Black above the lower bound, dissolving into the pond by the upper one, in points from the top.
        public var fade: ClosedRange<CGFloat>? = nil
        /// Where wandering koi stay, in points; nil is the whole pond.
        public var bounds: CGRect? = nil
        public var ripples = true
        public var glints = true
        public var blossoms = true
        /// Ink lines between a koi's own colour patches; off for very small koi, which read better
        /// as one shape with one outline.
        public var koiLines = true
        public var seed: Int32 = 7

        public init(size: CGSize, scale: CGFloat = 2, cell: CGFloat = 5, line: CGFloat = 1, crop: CGRect? = nil,
                    fade: ClosedRange<CGFloat>? = nil, bounds: CGRect? = nil, koiLines: Bool = true) {
            self.size = size
            self.scale = scale
            self.cell = cell
            self.line = line
            self.crop = crop
            self.fade = fade
            self.bounds = bounds
            self.koiLines = koiLines
        }
    }

    public final class Koi {
        public enum Swim {
            /// Roams the pond, steering clear of its edges and of other koi.
            case wander
            /// Crosses the pond once, left to right (1) or right to left (-1).
            case pass(direction: Float)
        }

        public let kind: KoiKind
        public let length: Float
        public var x: Float
        public var y: Float
        public var heading: Float
        public var speed: Float
        public var swim: Swim
        /// Drawn this much wider than the render: pixel proportions.
        public var fat: Float
        fileprivate var phase: Float
        fileprivate var depth: Float = 0.3
        fileprivate var turn: Float = 0
        fileprivate var bend: Float = 0
        fileprivate let amplitude: Float = 0.07
        fileprivate let seed: Int32
        fileprivate var t: Float
        fileprivate var level = 0
        fileprivate var cosH: Float = 1
        fileprivate var sinH: Float = 0

        public init(kind: KoiKind, length: Float, x: Float, y: Float, heading: Float, speed: Float,
             swim: Swim = .wander, fat: Float = 1.6, seed: Int32) {
            self.kind = kind
            self.length = length
            self.x = x
            self.y = y
            self.heading = heading
            self.speed = speed
            self.swim = swim
            self.fat = fat
            self.seed = seed
            phase = Float(seed % 7)
            t = Float(seed % 50)
        }

        /// Gone past the pond's edge after crossing it.
        public func hasCrossed(width: Float) -> Bool {
            guard case let .pass(direction) = swim else { return false }
            return direction > 0 ? x > width + length * 0.6 : x < -length * 0.6
        }
    }

    public let config: Config
    public private(set) var koi: [Koi] = []

    private let art: PondArt
    private let pw: Int, ph: Int, d: Float
    private let aMin: Int, aMax: Int, bMin: Int, bMax: Int, B: Int, N: Int
    private var cx: [Float], cy: [Float], ca: [Int32], cb: [Int32], live: [Bool]
    private var cellOf: [Int32], nbA: [Int32], nbB: [Int32]
    private var idx: [UInt8], idx2: [UInt8], tone: [Float]
    private var mat: [UInt8], base: [Float], earth: [Float], still: [UInt8]
    private var white: [Bool], finAlpha: [Float], touched: [Int] = []
    /// Cells a koi's body covers this frame.
    private var koiCell: [Bool], koiCells: [Int] = []
    private var blossoms: [Blossom] = []
    private var ripples: [Ripple] = []
    private var glints: [(cell: Int, until: Float)] = []
    private var lure: (x: Float, y: Float, until: Float)?
    private var time: Float = 0
    private var lastDate: Date?
    private let context: CGContext

    private struct Ripple {
        let x: Float, y: Float, t0: Float, speed: Float, life: Float, seed: Int32, splash: Bool
    }

    private struct Blossom {
        let cell: Int, petals: [Int], heart: UInt8, petal: UInt8, phase: Float
    }

    /// Nil if the art is missing from the bundle.
    public init?(config: Config) {
        guard let art = PondArt.shared else { return nil }
        self.config = config
        self.art = art

        // a = floor((X + Y) / d), b = floor((X - Y) / d), X and Y in device pixels.
        let s = Float(config.scale)
        pw = Int((config.size.width * config.scale).rounded())
        ph = Int((config.size.height * config.scale).rounded())
        d = Float(config.cell * config.scale)
        aMin = -1
        aMax = Int(Float(pw + ph) / d) + 1
        bMin = Int((Float(-ph) / d).rounded(.down)) - 1
        bMax = Int(Float(pw) / d) + 1
        B = bMax - bMin + 1
        N = (aMax - aMin + 1) * B
        cx = [Float](repeating: 0, count: N)
        cy = cx
        ca = [Int32](repeating: 0, count: N)
        cb = ca
        live = [Bool](repeating: false, count: N)
        for a in aMin...aMax {
            for b in bMin...bMax {
                let i = (a - aMin) * B + (b - bMin)
                let X = Float(a + b + 1) * d / 2, Y = Float(a - b) * d / 2
                cx[i] = X / s
                cy[i] = Y / s
                ca[i] = Int32(a)
                cb[i] = Int32(b)
                live[i] = X > -d && X < Float(pw) + d && Y > -d && Y < Float(ph) + d
                    && a > aMin && a < aMax && b > bMin && b < bMax
            }
        }
        // Per device pixel: its cell, and the neighbour across each nearby edge (-1 if not near one).
        let np = pw * ph
        var cellOf = [Int32](repeating: 0, count: np), nbA = cellOf, nbB = cellOf
        let tf = Float(config.line * config.scale / 2) * Float(2).squareRoot() / d
        let (aMin, bMin, B, pw, ph, d) = (aMin, bMin, B, pw, ph, d)
        cellOf.withUnsafeMutableBufferPointer { cellOf in
            nbA.withUnsafeMutableBufferPointer { nbA in
                nbB.withUnsafeMutableBufferPointer { nbB in
                    var p = 0
                    for y in 0..<ph {
                        for x in 0..<pw {
                            let sa = Float(x + y + 1) / d, sb = Float(x - y) / d
                            let fa0 = sa.rounded(.down), fb0 = sb.rounded(.down)
                            let fa = sa - fa0, fb = sb - fb0
                            let c = (Int(fa0) - aMin) * B + (Int(fb0) - bMin)
                            cellOf[p] = Int32(c)
                            nbA[p] = fa < tf ? Int32(c - B) : fa > 1 - tf ? Int32(c + B) : -1
                            nbB[p] = fb < tf ? Int32(c - 1) : fb > 1 - tf ? Int32(c + 1) : -1
                            p += 1
                        }
                    }
                }
            }
        }
        self.cellOf = cellOf
        self.nbA = nbA
        self.nbB = nbB
        idx = [UInt8](repeating: 0, count: N)
        idx2 = idx
        tone = [Float](repeating: 0, count: N)
        mat = idx
        base = tone
        earth = tone
        still = idx
        white = [Bool](repeating: false, count: N)
        koiCell = white
        finAlpha = tone
        guard let context = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: pw * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        self.context = context
        buildStill()
    }

    // MARK: - Koi, food

    public func add(_ fish: Koi) {
        fish.level = Self.level(length: fish.length, cell: Float(config.cell))
        koi.append(fish)
    }

    public func remove(_ fish: Koi) {
        koi.removeAll { $0 === fish }
    }

    /// Food dropped on the water: a ripple, and the koi come for it.
    public func feed(at point: CGPoint) {
        let x = Float(point.x), y = Float(point.y)
        ripple(x: x, y: y, splash: false)
        lure = (x, y, time + 9)
    }

    /// The sprite size for a koi this long: about three sprite pixels across each cell.
    private static func level(length: Float, cell: Float) -> Int {
        let perCell = 256 / length * cell
        return min(3, max(0, Int(log2(perCell / 3).rounded(.down))))
    }

    // MARK: - Frames

    /// Moves the pond on to `date` and draws it.
    public func frame(at date: Date) -> CGImage? {
        let dt = lastDate.map { Float(min(0.25, max(0, date.timeIntervalSince($0)))) } ?? 0
        lastDate = date
        step(dt)
        compose()
        rasterize()
        return context.makeImage()
    }

    private func step(_ dt: Float) {
        time += dt
        if let lure, time > lure.until { self.lure = nil }
        for fish in koi {
            switch fish.swim {
            case .wander: wander(fish, dt)
            case let .pass(direction): cross(fish, direction, dt)
            }
            fish.cosH = cos(fish.heading)
            fish.sinH = sin(fish.heading)
        }
        if config.ripples, Float.random(in: 0..<1) < dt / 7 {
            let r = swimBounds
            ripple(x: Float(r.minX) + Float.random(in: 0..<1) * Float(r.width),
                   y: Float(r.minY) + Float.random(in: 0..<1) * Float(r.height), splash: false)
        }
        ripples.removeAll { time - $0.t0 >= $0.life }
    }

    private var swimBounds: CGRect {
        config.bounds ?? CGRect(origin: .zero, size: config.size)
    }

    private func ripple(x: Float, y: Float, splash: Bool) {
        ripples.append(Ripple(x: x, y: y, t0: time, speed: 15 + Float.random(in: 0..<6), life: 2.4 + Float.random(in: 0..<1),
                              seed: Int32.random(in: 0..<1_000_000), splash: splash))
    }

    private func wander(_ k: Koi, _ dt: Float) {
        k.t += dt
        let r = swimBounds
        let x0 = Float(r.minX), y0 = Float(r.minY), x1 = Float(r.maxX), y1 = Float(r.maxY)
        var turn = (Noise.value(k.t * 0.13, 0.5, k.seed) - 0.5) * 1.3
        // Look ahead and steer back inside the bounds.
        let la = k.length * 0.8, ax = k.x + cos(k.heading) * la, ay = k.y + sin(k.heading) * la
        let m = min(k.length * 0.55, (y1 - y0) * 0.3)
        var fx: Float = 0, fy: Float = 0
        if ax < x0 + m { fx += (x0 + m - ax) / m }
        if ax > x1 - m { fx -= (ax - (x1 - m)) / m }
        if ay < y0 + m { fy += (y0 + m - ay) / m }
        if ay > y1 - m { fy -= (ay - (y1 - m)) / m }
        if let lure {
            // Food on the water: every koi turns toward it; the first to reach it takes it.
            let hx = k.x + cos(k.heading) * k.length * 0.45, hy = k.y + sin(k.heading) * k.length * 0.45
            turn += Self.wrap(atan2(lure.y - k.y, lure.x - k.x) - k.heading) * 2.2
            fx *= 0.3
            fy *= 0.3
            if hypot(lure.x - hx, lure.y - hy) < k.length * 0.18 {
                ripple(x: lure.x, y: lure.y, splash: true)
                self.lure = nil
            }
        }
        if fx != 0 || fy != 0 {
            turn += Self.wrap(atan2(fy, fx) - k.heading) * min(1.6, hypot(fx, fy)) * 1.4
        }
        // Give the others room: turn away from any koi close ahead.
        for q in koi where q !== k {
            let dx = q.x - k.x, dy = q.y - k.y, dist = hypot(dx, dy), near = (k.length + q.length) * 0.55
            guard dist < near, dist > 1e-3 else { continue }
            let da = Self.wrap(atan2(dy, dx) - k.heading)
            if abs(da) < 1.6 { turn -= (da < 0 ? -1 : 1) * (1 - dist / near) * 1.6 }
        }
        turn = min(1.3, max(-1.3, turn))
        k.turn += (turn - k.turn) * (1 - exp(-dt * 2.2))
        k.heading += k.turn * dt
        let speed = k.speed * (lure != nil ? 1.9 : 0.5 + 0.75 * Noise.value(k.t * 0.07, 3.3, k.seed + 9))
        k.x += cos(k.heading) * speed * dt
        k.y += sin(k.heading) * speed * dt
        k.phase += dt * (1.5 + 3.4 * speed / k.speed)
        // The body follows the arc it turns along.
        k.bend = min(0.3, max(-0.3, 0.5 * (k.turn / max(speed, 1)) * k.length))
        k.depth = 0.5 + 0.5 * sin(k.t * 0.045 + Float(k.seed))
        if config.ripples, k.depth < 0.1, Float.random(in: 0..<1) < dt * 0.25 {
            ripple(x: k.x + cos(k.heading) * k.length * 0.42, y: k.y + sin(k.heading) * k.length * 0.42, splash: true)
        }
    }

    /// A koi crossing once, with a slight weave, near the surface.
    private func cross(_ k: Koi, _ direction: Float, _ dt: Float) {
        k.t += dt
        let wave = k.t * 0.8 + Float(k.seed)
        k.heading = (direction > 0 ? 0 : .pi) + 0.1 * cos(wave) * direction
        k.x += cos(k.heading) * k.speed * dt
        k.y = Float(config.size.height) / 2 + sin(wave) * 3
        k.phase += dt * 5
        k.bend = 0
        k.depth = 0.15
        if config.ripples, Float.random(in: 0..<1) < dt * 0.15 {
            ripple(x: k.x + direction * k.length * 0.42, y: k.y, splash: true)
        }
    }

    private static func wrap(_ a: Float) -> Float { atan2(sin(a), cos(a)) }

    // MARK: - The still pond

    private struct Sampler {
        let w: Int, h: Int, q: Float
        let px: [Float]

        /// The art drawn small, one texel to three quarters of a cell, so tone is calm; then read
        /// back bilinearly at each cell's centre.
        init(image: CGImage, size: CGSize, cell: CGFloat, crop: CGRect?) {
            let q = cell * 0.75
            self.q = Float(q)
            w = Int((size.width / q).rounded(.up)) + 1
            h = Int((size.height / q).rounded(.up)) + 1
            let iw = CGFloat(image.width), ih = CGFloat(image.height)
            let fit: CGRect
            if let crop {
                fit = crop
            } else {
                let sa = size.width / size.height, ia = iw / ih
                fit = sa > ia ? CGRect(x: 0, y: (1 - ia / sa) / 2, width: 1, height: ia / sa)
                              : CGRect(x: (1 - sa / ia) / 2, y: 0, width: sa / ia, height: 1)
            }
            let part = image.cropping(to: CGRect(x: fit.minX * iw, y: fit.minY * ih,
                                                 width: fit.width * iw, height: fit.height * ih).integral) ?? image
            var data = [UInt8](repeating: 0, count: w * h * 4)
            let (w, h) = (w, h)
            data.withUnsafeMutableBytes { raw in
                guard let context = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
                context.interpolationQuality = .high
                // Top-left aligned, like the pond.
                context.draw(part, in: CGRect(x: 0, y: CGFloat(h) - size.height / q, width: size.width / q, height: size.height / q))
            }
            px = data.map { Float($0) / 255 }
        }

        func sample(_ X: Float, _ Y: Float) -> (Float, Float, Float) {
            let fx = min(max(X / q - 0.5, 0), Float(w) - 1.001), fy = min(max(Y / q - 0.5, 0), Float(h) - 1.001)
            let x0 = Int(fx), y0 = Int(fy), tx = fx - Float(x0), ty = fy - Float(y0)
            func at(_ k: Int) -> Float {
                let p00 = px[(y0 * w + x0) * 4 + k], p10 = px[(y0 * w + x0 + 1) * 4 + k]
                let p01 = px[((y0 + 1) * w + x0) * 4 + k], p11 = px[((y0 + 1) * w + x0 + 1) * 4 + k]
                return (p00 + (p10 - p00) * tx) * (1 - ty) + (p01 + (p11 - p01) * tx) * ty
            }
            return (at(0), at(1), at(2))
        }
    }

    private func buildStill() {
        let cell = Float(config.cell), s = config.seed
        let flora = Sampler(image: art.flora, size: config.size, cell: config.cell, crop: config.crop)
        let water = Sampler(image: art.water, size: config.size, cell: config.cell, crop: config.crop)
        let lo = art.waterLo, hi = art.waterHi
        let lum = { (c: (Float, Float, Float)) in 0.3 * c.0 + 0.59 * c.1 + 0.11 * c.2 }
        for i in 0..<N where live[i] {
            let X = cx[i], Y = cy[i]
            // Glitch: some half-row segments sample the art a little to the side.
            let row = Int32((Y / (cell / 2)).rounded(.down))
            let seg = Int32(((X + Noise.hash(row, 0, s) * 400) / (cell * 9)).rounded(.down))
            let jit: Float = Noise.hash(row, seg, s + 1) < 0.3 ? (Noise.hash(row, seg, s + 2) - 0.5) * cell * 3.2 : 0
            let streak = 0.36 * (Noise.fbm(X / (cell * 10), Y / (cell * 0.75), s + 3) - 0.5)
            earth[i] = Noise.value(X / (cell * 13), Y / (cell * 2.1), s + 7)
            let F = flora.sample(X + jit, Y)
            var W = water.sample(X + jit, Y)
            let diff = abs(F.0 - W.0) + abs(F.1 - W.1) + abs(F.2 - W.2)
            let mx = max(F.0, F.1, F.2), mn = min(F.0, F.1, F.2), l = lum(F)
            // Where the pads shade the bed, the flora render is darker than the bare water.
            let shade = max(0, lum(W) - l)
            // Brush smear: the water's light averaged along a short horizontal run.
            let dx = cell * 1.4
            let wl = water.sample(X + jit - dx, Y), wr = water.sample(X + jit + dx, Y)
            W = ((W.0 + wl.0 + wr.0) / 3, (W.1 + wl.1 + wr.1) / 3, (W.2 + wl.2 + wr.2) / 3)
            var m = Material.water
            if diff > 0.24 {
                if F.0 > 0.6 && F.1 > 0.42 && F.2 < 0.42 && F.0 >= F.1 * 0.95 { m = .gold }
                else if F.0 > 0.55 && F.0 > F.1 + 0.12 && F.2 > F.1 - 0.08 { m = .pink }
                else if mn > 0.66 && mx - mn < 0.22 { m = .white }
                else if F.1 > F.2 + 0.04 && F.1 >= F.0 * 0.85 { m = .pad }
            }
            mat[i] = m.rawValue
            if m == .water {
                // Bottoms out at navy and moss: the shade under a pad is deep, not a hole.
                let t = max(-0.25, (lum(W) - lo) / (hi - lo) - shade * 2.4 / (hi - lo))
                base[i] = 0.3 + 0.58 * t + streak
            } else {
                let t: Float = m == .pad ? (l - 0.22) / 0.5 : m == .gold ? (l - 0.45) / 0.45 : (l - 0.45) / 0.5
                still[i] = Self.pick(m.ramp, min(1, max(0, t + streak * 0.8)), threshold(i), 2.6)
            }
        }
        // Blossoms: little five-cell flowers scattered over the pads.
        guard config.blossoms else { return }
        for i in 0..<N where mat[i] == Material.pad.rawValue && Noise.hash(ca[i], cb[i], s + 11) <= 0.018 {
            let petals = [i - B, i + B, i - 1, i + 1]
            guard petals.allSatisfy({ $0 >= 0 && $0 < N && mat[$0] == Material.pad.rawValue }) else { continue }
            let kind = Noise.hash(ca[i], cb[i], s + 12)
            blossoms.append(Blossom(cell: i, petals: petals, heart: kind < 0.5 ? P.white : P.pink,
                                    petal: kind < 0.5 ? P.pink : P.white, phase: kind * 50))
        }
    }

    // MARK: - One frame of colour indices

    @inline(__always) private func threshold(_ i: Int) -> Float {
        Self.bayer[Int(((ca[i] & 3) << 2) | (cb[i] & 3))]
    }

    /// Visits the live cells whose centres fall in a rect (points).
    private func cells(_ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float, _ body: (Int, Float, Float) -> Void) {
        let s = Float(config.scale)
        let X0 = x0 * s, Y0 = y0 * s, X1 = x1 * s, Y1 = y1 * s
        let a0 = max(aMin + 1, Int(((X0 + Y0) / d).rounded(.down)) - 1), a1 = min(aMax - 1, Int(((X1 + Y1) / d).rounded(.up)))
        let b0 = max(bMin + 1, Int(((X0 - Y1) / d).rounded(.down)) - 1), b1 = min(bMax - 1, Int(((X1 - Y0) / d).rounded(.up)))
        guard a0 <= a1, b0 <= b1 else { return }
        for a in a0...a1 {
            for b in b0...b1 {
                let i = (a - aMin) * B + (b - bMin)
                guard live[i] else { continue }
                let x = cx[i], y = cy[i]
                if x >= x0 && x <= x1 && y >= y0 && y <= y1 { body(i, x, y) }
            }
        }
    }

    private enum KoiHit { case none, body(UInt8, Float), fin(Float) }

    /// What of koi `k` covers the point (X, Y).
    private func koiAt(_ k: Koi, _ X: Float, _ Y: Float) -> KoiHit {
        let dx = X - k.x, dy = Y - k.y
        let u = dx * k.cosH + dy * k.sinH, v = -dx * k.sinH + dy * k.cosH
        let t = 0.5 - u / k.length
        guard t >= 0, t <= 1 else { return .none }
        let w = k.length * (k.amplitude * sin(k.phase - 5.5 * t) * (0.12 + 0.88 * t * t) + k.bend * t * t)
        let S = art.koi[k.level], sc = Float(S.width) / k.length
        let px = t * Float(S.width - 1), py = S.axis - (v - w) * sc / k.fat
        guard py >= 0, py <= Float(S.height - 1) else { return .none }
        let x0 = min(Int(px), S.width - 2), y0 = min(Int(py), S.height - 2)
        let tx = px - Float(x0), ty = py - Float(y0), j = y0 * S.width + x0
        func bilinear(_ m: [Float]) -> Float {
            (m[j] * (1 - tx) + m[j + 1] * tx) * (1 - ty) + (m[j + S.width] * (1 - tx) + m[j + S.width + 1] * tx) * ty
        }
        let a = bilinear(S.alpha)
        guard a >= 0.45 else { return .none }
        let body = bilinear(S.body)
        guard body >= 0.5 else { return .fin(a) }
        return .body(S.kinds[k.kind.rawValue][Int(py.rounded()) * S.width + Int(px.rounded())], body)
    }

    /// A koi colour region to a palette entry. Cream turns beige at the body's rim, a pixel
    /// artist's roundness.
    private static func koiColour(_ region: UInt8, body: Float) -> UInt8 {
        let rim = body < 0.72
        switch region {
        case 5: return P.ink
        case 3: return P.red
        case 4: return rim ? P.red : P.orange
        default: return rim ? P.beige : P.cream
        }
    }

    private func compose() {
        let cell = Float(config.cell), s = config.seed, t = time
        let water = Material.water.rawValue
        for i in 0..<N where live[i] && mat[i] == water {
            let X = cx[i], Y = cy[i]
            tone[i] = base[i] - 0.12
                + 0.1 * (Noise.value(X / (cell * 6) - t * 0.35, Y / (cell * 1.1), s + 21) - 0.5)
                + 0.07 * (Noise.value(X / (cell * 3) + t * 0.22, Y / (cell * 0.8) + t * 0.05, s + 22) - 0.5)
        }
        for i in touched { white[i] = false; finAlpha[i] = 0 }
        touched.removeAll(keepingCapacity: true)
        let fishes = koi.sorted { $0.depth > $1.depth }
        // Shadows on the bed, and fins, which are translucent.
        for k in fishes {
            let off = 1.1 - 0.7 * k.depth, r = k.length * 0.62
            let ox = max(k.length * 0.09, cell * 0.8) * off, oy = max(k.length * 0.16, cell * 1.6) * off
            cells(k.x - r + ox, k.y - r + oy, k.x + r + ox, k.y + r + oy) { i, x, y in
                guard mat[i] == water, case .body = koiAt(k, x - ox, y - oy), Noise.hash(ca[i], cb[i], 99) > 0.12 else { return }
                tone[i] -= 0.3
            }
            cells(k.x - r, k.y - r, k.x + r, k.y + r) { i, x, y in
                guard mat[i] == water, case let .fin(a) = koiAt(k, x, y) else { return }
                finAlpha[i] = max(finAlpha[i], a)
                touched.append(i)
            }
        }
        // Ripples: broken rings of lighter water; a splash of white where a koi broke the surface.
        for r in ripples {
            let age = t - r.t0, R = age * r.speed, fade = 1 - age / r.life, band = cell * 0.55
            cells(r.x - R - cell, r.y - R - cell, r.x + R + cell, r.y + R + cell) { i, x, y in
                guard mat[i] == water else { return }
                let dist = hypot(x - r.x, y - r.y), e = abs(dist - R)
                if e < band && Noise.hash(ca[i], cb[i], r.seed) > 0.3 {
                    tone[i] += 0.42 * fade
                    if age < 0.6 && e < band * 0.5 { white[i] = true; touched.append(i) }
                }
                if r.splash && age < 0.45 && dist < cell * 2.4
                    && Noise.hash(ca[i], cb[i], r.seed + Int32(age * 12)) > 0.62 {
                    white[i] = true
                    touched.append(i)
                }
            }
        }
        // Quantize the water.
        for i in 0..<N where live[i] {
            guard mat[i] == water else { idx[i] = still[i]; continue }
            var k = Self.pick(Self.waterRamp, tone[i], threshold(i), 2.6)
            if k == P.navy && earth[i] > 0.6 { k = P.moss } else if k == P.cobalt && earth[i] > 0.72 { k = P.sage }
            idx[i] = k
        }
        // Despeckle: most lone cells take the colour all four of their neighbours share, so the
        // water reads as runs and bands rather than a mesh.
        idx2 = idx
        for i in (B + 1)..<(N - B - 1) where live[i] && mat[i] == water {
            let n0 = idx2[i - 1]
            if n0 != idx2[i] && n0 == idx2[i + 1] && n0 == idx2[i - B] && n0 == idx2[i + B]
                && Noise.hash(ca[i], cb[i], s + 41) < 0.7 { idx[i] = n0 }
        }
        for i in touched {
            if white[i] { idx[i] = P.white }
            // Fins: dithered pale over whatever water is under them.
            else if finAlpha[i] * 0.8 > threshold(i) { idx[i] = P.pale }
        }
        // Koi bodies, deepest first; pads and flowers stay on top of them. A koi swimming deep
        // lets the water through in an ordered dither, as if seen through it.
        for i in koiCells { koiCell[i] = false }
        koiCells.removeAll(keepingCapacity: true)
        for k in fishes {
            let r = k.length * 0.62, sunk = max(0, k.depth - 0.6) * 1.2
            cells(k.x - r, k.y - r, k.x + r, k.y + r) { i, x, y in
                guard mat[i] == water, threshold(i) >= sunk, case let .body(region, body) = koiAt(k, x, y) else { return }
                idx[i] = Self.koiColour(region, body: body)
                koiCell[i] = true
                koiCells.append(i)
            }
        }
        // Glints: a cell of light water flashes white for a frame or two.
        if config.glints {
            glints.removeAll { $0.until <= t }
            let n = Float.random(in: 0..<1) < 0.6 ? 1 + Int.random(in: 0...1) : 0
            for _ in 0..<n {
                let i = Int.random(in: 0..<N)
                if live[i] && mat[i] == water && base[i] > 0.62 { glints.append((i, t + 0.12 + Float.random(in: 0..<0.2))) }
            }
            for g in glints where idx[g.cell] == P.pale || idx[g.cell] == P.steel { idx[g.cell] = P.white }
        }
        for bl in blossoms {
            idx[bl.cell] = bl.heart
            let lit = sin(t * 0.9 + bl.phase) > -0.2
            for j in bl.petals { idx[j] = lit ? bl.petal : P.lime }
        }
        // Dissolve into the island's black, ordered-dithered like everything else.
        if let fade = config.fade {
            let f0 = Float(fade.lowerBound), f1 = Float(fade.upperBound)
            for i in 0..<N where live[i] && cy[i] < f1 && (cy[i] - f0) / (f1 - f0) < threshold(i) {
                idx[i] = P.void
            }
        }
    }

    private func rasterize() {
        guard let data = context.data else { return }
        let out = data.bindMemory(to: UInt32.self, capacity: pw * ph)
        let count = pw * ph, inner = config.koiLines
        koiCell.withUnsafeBufferPointer { koiCell in
        idx.withUnsafeBufferPointer { idx in
            cellOf.withUnsafeBufferPointer { cellOf in
                nbA.withUnsafeBufferPointer { nbA in
                    nbB.withUnsafeBufferPointer { nbB in
                        Self.fill.withUnsafeBufferPointer { fill in
                            Self.ink.withUnsafeBufferPointer { ink in
                                for p in 0..<count {
                                    let c = Int(cellOf[p]), k = idx[c]
                                    // An ink line where this cell's colour meets a different one,
                                    // except between two patches of one koi when those are off.
                                    var q = Int(nbA[p])
                                    if q >= 0 && idx[q] != k && (inner || !(koiCell[c] && koiCell[q])) {
                                        out[p] = ink[Int(k)]
                                        continue
                                    }
                                    q = Int(nbB[p])
                                    out[p] = q >= 0 && idx[q] != k && (inner || !(koiCell[c] && koiCell[q])) ? ink[Int(k)] : fill[Int(k)]
                                }
                            }
                        }
                    }
                }
            }
        }
        }
    }

    // MARK: - Palette

    /// Palette entries.
    private enum P {
        static let ink: UInt8 = 0, moss: UInt8 = 1, navy: UInt8 = 2, cobalt: UInt8 = 3, steel: UInt8 = 4
        static let pale: UInt8 = 5, white: UInt8 = 6, sage: UInt8 = 7, darkGreen: UInt8 = 8, olive: UInt8 = 9
        static let lime: UInt8 = 10, cream: UInt8 = 11, beige: UInt8 = 12, orange: UInt8 = 13, red: UInt8 = 14
        static let pink: UInt8 = 15
        /// Not part of the art: the island's own black, for the fade.
        static let void: UInt8 = 16
    }

    /// Sixteen earthy colours at night, plus the island's black.
    private static let palette: [UInt32] = [
        0x030402, 0x151409, 0x091621, 0x112B42, 0x1F4A6A, 0x4E7C98, 0xD9E2DB, 0x1F291E,
        0x0F1C04, 0x203007, 0x43560F, 0xECDFBF, 0xB8955F, 0xDF7A2B, 0xBB3A21, 0xC98BA0, 0x000000,
    ]

    /// RGBA in memory, as the bitmap wants it.
    private static func pack(_ rgb: UInt32, darken: Float = 0) -> UInt32 {
        let k = 1 - darken
        let r = UInt32(Float((rgb >> 16) & 255) * k), g = UInt32(Float((rgb >> 8) & 255) * k), b = UInt32(Float(rgb & 255) * k)
        return 0xFF00_0000 | (b << 16) | (g << 8) | r
    }

    private static let fill = palette.map { pack($0) }
    /// The ink line between two colours: the cell's own colour taken most of the way to black.
    private static let ink = palette.map { pack($0, darken: 0.8) }

    private enum Material: UInt8 {
        case water, pad, pink, white, gold

        /// The entries a material steps through from dark to light, and the tone each sits at.
        var ramp: Ramp {
            switch self {
            case .water: return Ramp(idx: [P.ink, P.navy, P.cobalt, P.steel, P.pale, P.white], at: [0.02, 0.2, 0.43, 0.67, 0.88, 1])
            case .pad: return Ramp(idx: [P.ink, P.darkGreen, P.olive, P.lime], at: [0, 0.3, 0.62, 0.95])
            case .pink: return Ramp(idx: [P.red, P.pink, P.white], at: [0.05, 0.5, 0.97])
            case .white: return Ramp(idx: [P.sage, P.pale, P.white], at: [0.1, 0.5, 0.92])
            case .gold: return Ramp(idx: [P.orange, P.beige, P.cream], at: [0.15, 0.55, 0.95])
            }
        }
    }

    private struct Ramp {
        let idx: [UInt8]
        let at: [Float]
    }

    private static let waterRamp = Material.water.ramp

    /// Ordered dithering, 4×4 Bayer, indexed in the lattice's own (a, b) coordinates.
    private static let bayer: [Float] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map { (Float($0) + 0.5) / 16 }

    /// `sharp` > 1 keeps each band's core solid and dithers only near the edges between bands.
    private static func pick(_ r: Ramp, _ t: Float, _ threshold: Float, _ sharp: Float) -> UInt8 {
        let at = r.at, n = at.count
        if t <= at[0] { return r.idx[0] }
        if t >= at[n - 1] { return r.idx[n - 1] }
        var i = 0
        while t > at[i + 1] { i += 1 }
        let f = ((t - at[i]) / (at[i + 1] - at[i]) - 0.5) * sharp + 0.5
        return f > threshold ? r.idx[i + 1] : r.idx[i]
    }
}

/// Hash and value noise for the pond.
private enum Noise {
    static func hash(_ x: Int32, _ y: Int32, _ s: Int32) -> Float {
        var h = (UInt32(bitPattern: x) &* 0x27D4_EB2D) ^ (UInt32(bitPattern: y) &* 0x1656_67B1) ^ (UInt32(bitPattern: s) &* 0x9E37_79B1)
        h = (h ^ (h >> 15)) &* 0x85EB_CA6B
        h = (h ^ (h >> 13)) &* 0xC2B2_AE35
        return Float(h ^ (h >> 16)) / 4_294_967_296
    }

    static func value(_ x: Float, _ y: Float, _ s: Int32) -> Float {
        let xf0 = x.rounded(.down), yf0 = y.rounded(.down)
        let xi = Int32(xf0), yi = Int32(yf0), xf = x - xf0, yf = y - yf0
        let u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf)
        let a = hash(xi, yi, s), b = hash(xi + 1, yi, s), c = hash(xi, yi + 1, s), d = hash(xi + 1, yi + 1, s)
        return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
    }

    static func fbm(_ x: Float, _ y: Float, _ s: Int32) -> Float {
        0.62 * value(x, y, s) + 0.38 * value(x * 2.13 + 5.3, y * 2.07 + 1.7, s + 1)
    }
}
