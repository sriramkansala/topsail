import SwiftUI

/// The Apps page: a YouTube video to play or pause, Chrome's active tab and newest others, and
/// the last lines of the front Terminal tab.
struct AppsPageView: View {
    @ObservedObject var apps: AppModules

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                if let problem = apps.problem {
                    Text(problem)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if apps.isEmpty, apps.problem == nil {
                    MessageView(symbol: "square.grid.2x2",
                                text: apps.terminalOpen || apps.chromeOpen ? String(localized: "Nothing to show yet")
                                                                           : String(localized: "Open Terminal or Chrome to see them here"))
                }
                if let video = apps.video {
                    HStack(spacing: 10) {
                        Image(systemName: "play.rectangle.fill").foregroundColor(.red)
                        Text(video.title).lineLimit(1)
                        Spacer(minLength: 8)
                        Button { apps.togglePlayback(video) } label: {
                            Image(systemName: "playpause.fill").foregroundColor(.white)
                        }
                        .buttonStyle(.pressable)
                        .help("Play or pause")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .frame(height: 22)
                }
                if !apps.listedTabs.isEmpty {
                    section("Chrome") {
                        ForEach(apps.listedTabs) { tab in TabRow(tab: tab, apps: apps) }
                    }
                }
                if let terminal = apps.terminal {
                    section(terminal.busy ? "Terminal · running" : "Terminal") {
                        Text(terminal.lines.joined(separator: "\n"))
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(AppModules.visibleLines)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.06)))
                    }
                }
            }
        }
        .onAppear { apps.setVisible(true) }
        .onDisappear { apps.setVisible(false) }
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
            content()
        }
    }
}

private struct TabRow: View {
    let tab: AppModules.Tab
    let apps: AppModules

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button { apps.show(tab) } label: {
                HStack(spacing: 8) {
                    Image(systemName: tab.active ? "circle.fill" : "globe")
                        .font(.system(size: tab.active ? 6 : 10))
                        .foregroundColor(tab.active ? .green : .white.opacity(0.5))
                        .frame(width: 12)
                    Text(tab.title).lineLimit(1)
                    Text(tab.url?.host() ?? "")
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                        .layoutPriority(-1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(.subtle, hoverWash: false))
            if hovering {
                Button { apps.copyLink(tab) } label: { Image(systemName: "link").foregroundColor(.white.opacity(0.7)) }
                    .buttonStyle(.pressable)
                    .help("Copy link")
            }
        }
        .font(.system(size: 12))
        .foregroundColor(.white)
        .frame(height: 20)
        .onHover { hovering = $0 }
    }
}
