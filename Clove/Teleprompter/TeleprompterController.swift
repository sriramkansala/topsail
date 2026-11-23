import Combine
import Foundation

extension Notification.Name {
    /// Settings' "Start" button: the app delegate starts the teleprompter in the island.
    static let cloveStartTeleprompter = Notification.Name("CloveStartTeleprompter")
}

/// The teleprompter: a script that scrolls up out of the notch, right under the camera (so you
/// read while looking at it), at a speed you set. While it runs, the island stays open for it.
@MainActor
final class TeleprompterController: ObservableObject {
    static let speedRange: ClosedRange<Double> = 10...160
    static let speedStep: Double = 10

    @Published private(set) var isActive = false
    @Published private(set) var isPlaying = false
    /// Points per second.
    @Published private(set) var speed: Double = 40
    @Published private(set) var script = ""
    /// Reached the end of the script (it stops there).
    @Published private(set) var atEnd = false

    /// Where the script stood when it last started or stopped moving, and when it started.
    private var anchorOffset: CGFloat = 0
    private var anchorDate: Date?
    /// The script's laid-out height, reported by the view, to know where the end is.
    private var textHeight: CGFloat = .greatestFiniteMagnitude
    private var endTimer: Timer?

    /// How far the script has scrolled at `date`.
    func offset(at date: Date) -> CGFloat {
        guard let anchorDate else { return anchorOffset }
        return min(anchorOffset + CGFloat(date.timeIntervalSince(anchorDate) * speed), textHeight)
    }

    func start(script: String, speed: Double) {
        self.script = script
        self.speed = speed.clamped(to: Self.speedRange)
        anchorOffset = 0
        anchorDate = nil
        atEnd = false
        isActive = true
        // A moment to find your place before it moves.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.isActive, !self.isPlaying, self.anchorOffset == 0 else { return }
                self.play()
            }
        }
    }

    func stop() {
        pause()
        isActive = false
    }

    func togglePlay() {
        if isPlaying { pause() } else { play() }
    }

    func play() {
        guard isActive else { return }
        if atEnd { restart() }
        anchorDate = Date()
        isPlaying = true
        watchForEnd()
    }

    func pause() {
        anchorOffset = offset(at: Date())
        anchorDate = nil
        isPlaying = false
        endTimer?.invalidate()
        endTimer = nil
    }

    func restart() {
        anchorOffset = 0
        anchorDate = isPlaying ? Date() : nil
        atEnd = false
    }

    func faster() { setSpeed(speed + Self.speedStep) }
    func slower() { setSpeed(speed - Self.speedStep) }

    /// Changes speed without a jump: the script carries on from where it is.
    func setSpeed(_ newSpeed: Double) {
        let now = Date()
        anchorOffset = offset(at: now)
        if anchorDate != nil { anchorDate = now }
        speed = newSpeed.clamped(to: Self.speedRange)
    }

    /// Nudges the script by hand (scrolling over it), forward or back.
    func nudge(by points: CGFloat) {
        let now = Date()
        anchorOffset = max(0, min(offset(at: now) + points, textHeight))
        if anchorDate != nil { anchorDate = now }
        atEnd = anchorOffset >= textHeight
    }

    func setTextHeight(_ height: CGFloat) {
        textHeight = max(height, 1)
    }

    private func watchForEnd() {
        endTimer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying, self.offset(at: Date()) >= self.textHeight else { return }
                self.pause()
                self.atEnd = true
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        endTimer = timer
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
