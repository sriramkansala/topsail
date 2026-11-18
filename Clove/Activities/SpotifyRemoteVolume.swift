import Combine
import Foundation

/// Spotify playing on another device — a phone, a speaker, a TV, through Spotify Connect: the
/// volume keys turn that device up and down instead of this Mac.
///
/// The Spotify app on the Mac says it is playing either way; it is playing elsewhere when it
/// sends no audio to this Mac's output. Its `sound volume` is the volume of whichever device is
/// playing, so setting it reaches the device. Spotify has no mute, so the mute key takes the
/// volume to 0 and back.
@MainActor
final class SpotifyRemoteVolume {
    /// Called when the volume keys start or stop going to Spotify.
    var onActiveChange: ((Bool) -> Void)?

    private(set) var isActive = false {
        didSet { if isActive != oldValue { onActiveChange?(isActive) } }
    }

    private let center: ActivityCenter
    private var poll: Timer?
    /// Checks in a row that found Spotify playing but silent here; one alone may be a track
    /// starting, before its audio does.
    private var silentChecks = 0
    /// Spotify's volume, 0...100, as last read or set, and when.
    private var level: Int?
    private var levelDate = Date.distantPast
    /// The volume the mute key took to 0, to go back to.
    private var unmutedLevel: Int?
    /// Keys pressed while the volume is being read.
    private var waiting: [(key: VolumeKeyTap.Key, fine: Bool)] = []
    private var cancellables = Set<AnyCancellable>()

    private static let bundleID = "com.spotify.client"
    private static let readScript = "tell application \"Spotify\" to return sound volume"
    /// A level older than this is read again: it may have been changed on the device itself.
    private static let levelLifetime: TimeInterval = 2

    init(nowPlaying: NowPlayingService, center: ActivityCenter) {
        self.center = center
        nowPlaying.$isPlaying
            .combineLatest(nowPlaying.$track.map { $0?.app })
            .map { playing, app in playing && app == .spotify }
            .removeDuplicates()
            .sink { [weak self] spotifyPlaying in self?.watch(spotifyPlaying) }
            .store(in: &cancellables)
    }

    /// A volume key, while `isActive`.
    func change(_ key: VolumeKeyTap.Key, fine: Bool) {
        guard let level, Date().timeIntervalSince(levelDate) < Self.levelLifetime else {
            waiting.append((key, fine))
            guard waiting.count == 1 else { return }  // the read is already on its way
            AppleScriptRunner.run(Self.readScript) { [weak self] outcome in
                guard let self else { return }
                let keys = waiting
                waiting = []
                guard let read = outcome.descriptor?.int32Value else { return }
                level = Int(read)
                levelDate = Date()
                for (key, fine) in keys { change(key, fine: fine) }
            }
            return
        }

        let step: Float = fine ? 1.0 / 64 : 1.0 / 16
        let next: Int
        switch key {
        case .mute:
            if level > 0 {
                unmutedLevel = level
                next = 0
            } else {
                next = unmutedLevel ?? 50
                unmutedLevel = nil
            }
        case .volumeUp:
            next = Self.stepped(level == 0 ? unmutedLevel ?? 0 : level, by: step)
            unmutedLevel = nil
        case .volumeDown:
            next = Self.stepped(level, by: -step)
            unmutedLevel = nil
        case .brightnessUp, .brightnessDown:
            return
        }

        self.level = next
        levelDate = Date()
        AppleScriptRunner.run("tell application \"Spotify\" to set sound volume to \(next)")
        // Muted shows the level it will come back to, dimmed, as the Mac's own volume does.
        let shown = unmutedLevel ?? next
        center.post(.volume(level: Float(shown) / 100, muted: unmutedLevel != nil, remote: true))
    }

    private func watch(_ spotifyPlaying: Bool) {
        poll?.invalidate()
        poll = nil
        silentChecks = 0
        guard spotifyPlaying else {
            isActive = false
            return
        }
        check()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        poll = timer
    }

    private func check() {
        // If macOS won't say where Spotify's audio goes, the keys stay with this Mac.
        guard let playingHere = AudioHardware.isPlayingAudio(bundleID: Self.bundleID) else {
            isActive = false
            return
        }
        silentChecks = playingHere ? 0 : silentChecks + 1
        isActive = silentChecks >= 2
    }

    /// Spotify's 0...100 in the Mac's own steps, so both move alike.
    private static func stepped(_ level: Int, by step: Float) -> Int {
        Int((VolumeKeyTap.stepped(Float(level) / 100, by: step) * 100).rounded())
    }
}
