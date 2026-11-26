import SwiftUI

struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    /// How far the shape reaches below its frame: the band a toast sits in. The frame is what
    /// the island shows and moves with it; only a toast animates this, so the two never get
    /// out of step, whatever else is in motion.
    var reach: CGFloat = 0

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(topRadius, bottomRadius), reach) }
        set {
            topRadius = newValue.first.first
            bottomRadius = newValue.first.second
            reach = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let rt = topRadius
        let rb = bottomRadius
        #if DEBUG
        NotchRadiiTrace.note(top: rt, bottom: rb, reach: max(0, reach), frame: rect.size)
        #endif

        let rect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height + max(0, reach))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rt, y: rect.minY + rt),
            control: CGPoint(x: rect.minX + rt, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.minX + rt, y: rect.maxY - rb))

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rt + rb, y: rect.maxY),
            control: CGPoint(x: rect.minX + rt, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.maxX - rt - rb, y: rect.maxY))

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rt, y: rect.maxY - rb),
            control: CGPoint(x: rect.maxX - rt, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.maxX - rt, y: rect.minY + rt))

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - rt, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}
