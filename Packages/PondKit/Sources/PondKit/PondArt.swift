import CoreGraphics
import Foundation
import ImageIO

/// The three koi in the pond.
public enum KoiKind: Int, CaseIterable, Sendable {
    case kohaku, showa, beni
}

/// The koi pond's source art, read once from the app's resources (`Topsail/Pond/Art`, credits
/// beside it): the pond
/// rendered with its pads and lilies and without them, and three koi cut-outs with a mask of
/// their bodies.
@MainActor
final class PondArt {
    static let shared = PondArt()

    /// The pond with its pads and lilies, and the bare water under them.
    let flora: CGImage
    let water: CGImage
    /// The water's own light range, so tones are measured against the water, not the pads.
    let waterLo: Float
    let waterHi: Float
    /// The koi at 256, 128, 64 and 32 px long.
    let koi: [KoiLevel]

    /// One size of the koi sprites. All three fish share one pose, so they share the silhouette and
    /// the body mask; their colours are flat regions: 1 fin, 2 cream, 3 red, 4 orange, 5 black.
    struct KoiLevel {
        let width: Int
        let height: Int
        /// The body's axis, in rows from the top.
        let axis: Float
        let alpha: [Float]
        let body: [Float]
        let kinds: [[UInt8]]
    }

    private init?() {
        guard let flora = Self.image("pond-flora"), let water = Self.image("pond-water"),
              let kohaku = Self.image("koi-kohaku"), let showa = Self.image("koi-showa"),
              let beni = Self.image("koi-beni"), let body = Self.image("koi-body") else { return nil }
        self.flora = flora
        self.water = water

        let wp = Self.pixels(water, width: 260, height: 104)
        var lums: [Float] = []
        lums.reserveCapacity(wp.count / 4)
        for i in stride(from: 0, to: wp.count, by: 4) {
            lums.append((0.3 * Float(wp[i]) + 0.59 * Float(wp[i + 1]) + 0.11 * Float(wp[i + 2])) / 255)
        }
        lums.sort()
        waterLo = lums[Int(Float(lums.count) * 0.03)]
        waterHi = lums[Int(Float(lums.count) * 0.97)]

        koi = Self.levels(kinds: [kohaku, showa, beni], body: body)
    }

    private static func image(_ name: String) -> CGImage? {
        let url = Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Art")
        guard let url, let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// RGBA, 8 bits a channel, premultiplied, top row first.
    static func pixels(_ image: CGImage, width: Int? = nil, height: Int? = nil) -> [UInt8] {
        let w = width ?? image.width, h = height ?? image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        data.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                          bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return data
    }

    /// Koi as flat colour regions, the way a pixel artist would draw them: every pixel of a cut-out
    /// is read as one colour, then each smaller size takes the majority in each block rather than an
    /// average, so patches stay pure instead of mixing into beige.
    private static func levels(kinds images: [CGImage], body bodyImage: CGImage) -> [KoiLevel] {
        let W = bodyImage.width, H = bodyImage.height, n = W * H
        let bodyPx = pixels(bodyImage), alphaPx = pixels(images[0], width: W, height: H)
        var alpha = [Float](repeating: 0, count: n), body = [Float](repeating: 0, count: n)
        for i in 0..<n {
            alpha[i] = Float(alphaPx[i * 4 + 3]) / 255
            body[i] = Float(bodyPx[i * 4]) / 255
        }
        var full: [[UInt8]] = []
        for (k, image) in images.enumerated() {
            let px = pixels(image, width: W, height: H)
            var cls = [UInt8](repeating: 0, count: n)
            for i in 0..<n {
                let a = Float(px[i * 4 + 3])
                guard a >= 128 else { continue }
                guard bodyPx[i * 4] >= 128 else { cls[i] = 1; continue }
                let r = Float(px[i * 4]) * 255 / a, g = Float(px[i * 4 + 1]) * 255 / a, b = Float(px[i * 4 + 2]) * 255 / a
                let mx = max(r, g, b), mn = min(r, g, b)
                let lum = 0.3 * r + 0.59 * g + 0.11 * b, sat = mx > 0 ? (mx - mn) / mx : 0
                switch KoiKind(rawValue: k)! {
                case .kohaku: cls[i] = lum < 60 ? 5 : sat < 0.3 ? 2 : 3
                case .showa: cls[i] = lum < 85 ? 5 : sat < 0.3 ? 2 : 3
                case .beni: cls[i] = sat < 0.25 ? 2 : lum < 105 ? 3 : 4
                }
            }
            full.append(cls)
        }
        // Small red and black spots get a little extra weight so they survive shrinking.
        let weight: [Float] = [0, 1, 1, 1.25, 1, 1.5]
        var result: [KoiLevel] = []
        var f = 1
        while f <= 8 {
            let w = W / f, h = H / f
            var la = [Float](repeating: 0, count: w * h), lb = [Float](repeating: 0, count: w * h)
            var lk = [[UInt8]](repeating: [UInt8](repeating: 0, count: w * h), count: full.count)
            var count = [Float](repeating: 0, count: 6)
            for y in 0..<h {
                for x in 0..<w {
                    let j = y * w + x
                    var a: Float = 0, bo: Float = 0
                    for yy in 0..<f {
                        for xx in 0..<f {
                            let i = (y * f + yy) * W + x * f + xx
                            a += alpha[i]
                            bo += body[i]
                        }
                    }
                    la[j] = a / Float(f * f)
                    lb[j] = bo / Float(f * f)
                    for k in full.indices {
                        for c in 0..<6 { count[c] = 0 }
                        for yy in 0..<f {
                            for xx in 0..<f { count[Int(full[k][(y * f + yy) * W + x * f + xx])] += 1 }
                        }
                        var best: UInt8 = 0, top: Float = 0
                        for c in 1..<6 where count[c] * weight[c] > top {
                            top = count[c] * weight[c]
                            best = UInt8(c)
                        }
                        lk[k][j] = best
                    }
                }
            }
            result.append(KoiLevel(width: w, height: h, axis: Float(H) / Float(f) / 2, alpha: la, body: lb, kinds: lk))
            f *= 2
        }
        return result
    }
}
