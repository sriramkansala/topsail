import SwiftUI

struct ArtworkView: View {
    var image: NSImage?
    var size: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct EqualizerView: View {
    var isPlaying: Bool
    var color: Color

    private let barWidth: CGFloat = 3
    private let spacing: CGFloat = 2
    private let maxHeight: CGFloat = 14

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(0..<4, id: \.self) { index in
                    let height = barHeight(index: index, time: t)
                    Capsule()
                        .fill(color)
                        .frame(width: barWidth, height: height)
                }
            }
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard isPlaying else { return maxHeight * 0.25 }

        let speeds: [Double] = [1.7, 2.3, 1.4, 2.0]
        let phases: [Double] = [0.0, 1.3, 2.6, 4.1]
        let amplitudes: [Double] = [0.35, 0.6, 0.8, 1.0]

        let s = speeds[index % speeds.count]
        let p = phases[index % phases.count]
        let a = amplitudes[index % amplitudes.count]

        // Sine oscillates in [-1, 1]; map to [0.35, 1.0] of max height.
        let wave = (sin(time * s + p) + 1) / 2.0
        let fraction = a * (0.35 + 0.65 * wave)
        return maxHeight * fraction
    }
}

/// A slim scrubber with the times inline at either end. Dragging previews the position and
/// seeks on release; the fill follows the finger directly (manipulation, no tween).
struct ProgressBarView: View {
    @ObservedObject var service: NowPlayingService
    var date: Date

    @State private var dragProgress: CGFloat?

    private let barHeight: CGFloat = 4
    private let timeFont = Font.system(size: 10, weight: .medium).monospacedDigit()

    var body: some View {
        HStack(spacing: 8) {
            Text(timeString(elapsed))
                .font(timeFont)
                .foregroundColor(.white.opacity(0.55))
                .frame(minWidth: 28, alignment: .leading)

            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: width * progress)
                }
                .frame(height: barHeight)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragProgress = max(0, min(1, value.location.x / width))
                        }
                        .onEnded { value in
                            let fraction = max(0, min(1, value.location.x / width))
                            dragProgress = nil
                            if let track = service.track {
                                service.seek(to: fraction * track.duration)
                            }
                        }
                )
            }
            .frame(height: 12)

            Text("-" + timeString(remaining))
                .font(timeFont)
                .foregroundColor(.white.opacity(0.55))
                .frame(minWidth: 32, alignment: .trailing)
        }
    }

    private var elapsed: TimeInterval {
        if let dragProgress, let track = service.track {
            return dragProgress * track.duration
        }
        return service.position(at: date)
    }

    private var remaining: TimeInterval {
        guard let track = service.track else { return 0 }
        return max(0, track.duration - elapsed)
    }

    private var progress: CGFloat {
        if let dragProgress { return dragProgress }
        guard let track = service.track, track.duration > 0 else { return 0 }
        return CGFloat(service.position(at: date) / track.duration)
    }

    private func timeString(_ value: TimeInterval) -> String {
        let total = max(0, Int(value.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// The scrubber's row while a level changes: what it's of, the level, and its percentage, laid
/// out like the scrubber (same bar, same ends) so the row trades one for the other in place.
private struct PlayerLevelRow: View {
    let kind: ActivityKind
    let reading: (value: Double, dimmed: Bool)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            LevelGlyph(kind: kind, size: 10)
                .frame(minWidth: 28, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                    Capsule()
                        .fill(Color.white.opacity(reading.dimmed ? 0.35 : 1))
                        .frame(width: max(4, geo.size.width * min(max(reading.value, 0), 1)))
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity)
                .animation(reduceMotion ? nil : Motion.snappy, value: reading.value)
            }
            .frame(height: 12)
            Text(verbatim: "\(kind.levelPercent ?? 0)%")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundColor(.white.opacity(0.55))
                .contentTransition(.numericText(value: reading.value))
                .animation(reduceMotion ? nil : Motion.base, value: reading.value)
                .frame(minWidth: 32, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(kind.levelPercent ?? 0)%"))
    }
}

/// The player: the artwork, title and artist and the bars in one row, the scrubber, then the
/// controls centred. The artwork and the bars are drawn by `MusicTraveler`, which carries them here
/// from the wings beside the notch; this view keeps their places. Anywhere along the top row
/// opens the app playing.
struct ExpandedPlayerView: View {
    @ObservedObject var service: NowPlayingService
    /// Volume or brightness being changed: the scrubber's row shows it until the keys rest.
    var level: ActivityKind? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { service.openPlayerApp() }) {
                HStack(spacing: 12) {
                    Color.clear
                        .frame(width: IslandLayout.playerArtwork, height: IslandLayout.playerArtwork)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(service.track?.title ?? "")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(.white)
                        Text(service.track?.artist ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .lineLimit(1)
                    .traced("title")
                    Spacer(minLength: 8)
                    Color.clear
                        .frame(width: IslandLayout.playerBarsWidth, height: 18)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(.subtle, hoverWash: false))
            .help(service.track.map { "Open \($0.app.displayName)" } ?? "")
            .frame(height: IslandLayout.playerArtwork)

            ZStack {
                if let level, let reading = level.levelReading {
                    PlayerLevelRow(kind: level, reading: reading)
                        .traced("toast.\(level.traceName)")
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else {
                    TimelineView(.periodic(from: .now, by: 0.5)) { context in
                        ProgressBarView(service: service, date: context.date)
                    }
                    .traced("player.scrubber", control: true)
                    .transition(.contentMorph(reduceMotion: reduceMotion))
                }
            }
            .frame(height: 16)
            .padding(.top, IslandLayout.playerRowGap)

            HStack(spacing: 30) {
                control("backward.fill", size: 13) { service.previous() }
                control(service.isPlaying ? "pause.fill" : "play.fill", size: 18) { service.playPause() }
                    .contentTransition(.symbolEffect(.replace))
                control("forward.fill", size: 13) { service.next() }
            }
            .frame(height: IslandLayout.playerControlsHeight)
            .traced("player.controls", control: true)
            .padding(.top, 6)
        }
        .frame(height: IslandLayout.playerHeight, alignment: .top)
    }

    private func control(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.pressable)
    }
}
