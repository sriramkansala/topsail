import SwiftUI

/// A Bluetooth device became the Mac's output: the island drops a card below the camera with the
/// device and its name on the left and its battery on the right, each earbud and the case for
/// AirPods, one level for headphones and speakers. Whatever is playing keeps its artwork and bars
/// beside the notch above the card, so connecting never hides the music: they are the island's
/// own travelling pair (`MusicTraveler`), which rides the wings out as they widen for the card.
struct DeviceConnectedNotice: View {
    let name: String
    /// Nil while it hasn't arrived (it can, a moment later) or when the build can't read it.
    let battery: DeviceBattery?
    let notchSize: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: notchSize.height)

            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.white.opacity(0.11))
                    .overlay {
                        Image(systemName: Self.symbol(for: name))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: IslandLayout.deviceTileSize, height: IslandLayout.deviceTileSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Text("Connected")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .tracking(-0.2)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let battery {
                    HStack(spacing: 10) {
                        ForEach(gauges(battery)) { gauge in
                            BatteryGauge(level: gauge.level, symbol: gauge.symbol)
                        }
                    }
                    .fixedSize()
                    .transition(.noticeBlur(reduceMotion: reduceMotion))
                }
            }
            .frame(height: IslandLayout.deviceTileSize)
            .padding(.horizontal, IslandLayout.deviceInset)
            .padding(.top, IslandLayout.noticeTopGap)
            .padding(.bottom, IslandLayout.deviceInset)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private struct Gauge: Identifiable {
        let level: Int
        let symbol: String
        var id: String { symbol }
    }

    /// Left bud, right bud, case; or the one level, around the device itself.
    private func gauges(_ battery: DeviceBattery) -> [Gauge] {
        let pro = name.lowercased().contains("pro")
        var gauges: [Gauge] = []
        if let left = battery.left {
            gauges.append(Gauge(level: left, symbol: pro ? "airpodpro.left" : "airpod.left"))
        }
        if let right = battery.right {
            gauges.append(Gauge(level: right, symbol: pro ? "airpodpro.right" : "airpod.right"))
        }
        if let chargingCase = battery.chargingCase {
            gauges.append(Gauge(level: chargingCase,
                                symbol: pro ? "airpodspro.chargingcase.wireless.fill" : "airpods.chargingcase.fill"))
        }
        if gauges.isEmpty, let single = battery.single {
            gauges.append(Gauge(level: single, symbol: Self.symbol(for: name)))
        }
        return gauges
    }

    private var accessibilityText: String {
        var parts = ["\(name) connected"]
        if let battery {
            if let left = battery.left { parts.append("left \(left)%") }
            if let right = battery.right { parts.append("right \(right)%") }
            if let chargingCase = battery.chargingCase { parts.append("case \(chargingCase)%") }
            if battery.left == nil, battery.right == nil, battery.chargingCase == nil, let single = battery.single {
                parts.append("battery \(single)%")
            }
        }
        return parts.joined(separator: ", ")
    }

    static func symbol(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpods.max" }
        if lower.contains("airpods pro") { return "airpods.pro" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") { return "beats.headphones" }
        if lower.contains("homepod") { return "homepod.fill" }
        if ["speaker", "soundlink", "echo"].contains(where: lower.contains) { return "hifispeaker.fill" }
        return "headphones"
    }
}

/// One battery: a ring filled to the level around the part it belongs to, then the level. Red
/// at 20 % or below, as iOS shows a low battery.
private struct BatteryGauge: View {
    let level: Int
    let symbol: String

    private let lineWidth: CGFloat = 2.5

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.16), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(level, 0), 100)) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(lineWidth / 2)
            .frame(width: IslandLayout.deviceGaugeSize, height: IslandLayout.deviceGaugeSize)

            Text("\(level)%")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(level <= 20 ? color : .white)
        }
    }

    private var color: Color { level <= 20 ? .red : .white }
}
