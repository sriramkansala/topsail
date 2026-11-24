import Combine
import Foundation
import IOKit.pwr_mgt

/// Keeps the Mac from going to sleep on its own while a long job runs: an IOKit power assertion,
/// the same thing `caffeinate` takes. Optionally keeps the display on too, and turns itself off
/// after a chosen time. Closing the lid still sleeps the Mac.
@MainActor
final class KeepAwake: ObservableObject {
    @Published private(set) var isOn = false
    /// When it turns itself off; nil for "until turned off".
    @Published private(set) var until: Date?

    /// Shown beside the notch when it turns on or off.
    var onChange: ((Bool) -> Void)?

    private var assertion = IOPMAssertionID(0)
    private var timer: Timer?

    /// `duration` nil keeps it on until turned off.
    func turnOn(keepingDisplayOn: Bool, for duration: TimeInterval?) {
        releaseAssertion()
        let type = keepingDisplayOn ? kIOPMAssertionTypePreventUserIdleDisplaySleep
                                    : kIOPMAssertionTypePreventUserIdleSystemSleep
        let status = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 "Topsail Keep Awake" as CFString, &assertion)
        guard status == kIOReturnSuccess else {
            assertion = 0
            return
        }
        timer?.invalidate()
        timer = nil
        if let duration {
            until = Date().addingTimeInterval(duration)
            let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.turnOff() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else {
            until = nil
        }
        let wasOn = isOn
        isOn = true
        if !wasOn { onChange?(true) }
    }

    func turnOff() {
        let wasOn = isOn
        releaseAssertion()
        timer?.invalidate()
        timer = nil
        until = nil
        isOn = false
        if wasOn { onChange?(false) }
    }

    private func releaseAssertion() {
        if assertion != 0 {
            IOPMAssertionRelease(assertion)
            assertion = 0
        }
    }
}
