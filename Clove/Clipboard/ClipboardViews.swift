import SwiftUI
import UniformTypeIdentifiers

/// The clipboard page: what was copied, newest first, under a small header with Clear. Text shows
/// its first line, a link its address, a picture a thumbnail and its size, files their icon and
/// name. Clicking a row puts it back on the clipboard. Until Clove may read the clipboard, one
/// row asks for that instead.
struct ClipboardPageView: View {
    @ObservedObject var history: ClipboardHistory

    /// The row just clicked, which says "Copied" for a moment.
    @State private var justCopied: UUID?
    @State private var clearHover = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if history.access != .allowed {
            ClipboardSetupView(access: history.access, action: history.requestAccess)
        } else if history.items.isEmpty {
            MessageView(symbol: "doc.on.doc", text: "Copy something and it shows up here")
        } else {
            VStack(alignment: .leading, spacing: IslandLayout.clipboardHeaderGap) {
                header
                // Five rows fit; more than that scroll.
                if history.items.count > IslandLayout.clipboardVisibleRows {
                    ScrollView(.vertical, showsIndicators: false) { rows }
                } else {
                    rows
                }
            }
        }
    }

    private var rows: some View {
        VStack(spacing: IslandLayout.clipboardRowSpacing) {
            ForEach(history.items) { item in
                ClipboardRow(item: item, justCopied: justCopied == item.id) { copy(item) }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Recently copied")
                .foregroundColor(.white.opacity(0.45))
            Spacer()
            Button(action: { history.clear() }) {
                Text("Clear")
                    .foregroundColor(.white.opacity(clearHover ? 0.85 : 0.45))
            }
            .buttonStyle(.pressable(.normal, hoverWash: false))
            .onHover { clearHover = $0 }
            .animation(reduceMotion ? nil : Motion.hover, value: clearHover)
            .accessibilityHint("Forgets everything copied")
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, ClipboardRow.inset)
        .frame(height: IslandLayout.clipboardHeaderHeight)
    }

    private func copy(_ item: ClipboardItem) {
        history.copy(item)
        Motion.perform(reduceMotion ? Motion.instant : Motion.fast) { justCopied = item.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard justCopied == item.id else { return }
            Motion.perform(reduceMotion ? Motion.instant : Motion.fast) { justCopied = nil }
        }
    }
}

/// One copy: what it is on the left, what it says in the middle, how long ago on the right.
/// Brightens under the pointer; a click copies it again and the time gives way to "Copied".
private struct ClipboardRow: View {
    let item: ClipboardItem
    let justCopied: Bool
    let action: () -> Void

    /// Inside the row's highlight, so text lines up with the header.
    static let inset: CGFloat = 4

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ClipboardThumbnail(content: item.content)

                title
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ZStack(alignment: .trailing) {
                    if justCopied {
                        Label("Copied", systemImage: "checkmark")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.green)
                            .transition(.opacity)
                    } else {
                        TimelineView(.everyMinute) { context in
                            Text(Self.age(of: item.copiedAt, at: context.date))
                                .font(.system(size: 10.5).monospacedDigit())
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .transition(.opacity)
                    }
                }
                .fixedSize()
            }
            .padding(.horizontal, Self.inset)
            .frame(height: IslandLayout.clipboardRowHeight)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(hovering ? 0.08 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(.subtle, hoverWash: false))
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : Motion.hover, value: hovering)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Copies it again")
    }

    @ViewBuilder private var title: some View {
        switch item.content {
        case .text(let string):
            Text(Self.oneLine(string))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        case .link(let url):
            Text(Self.address(of: url))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        case .image(_, let pixels):
            Text("Image\(Text("  \(String(Int(pixels.width))) × \(String(Int(pixels.height)))").foregroundStyle(.white.opacity(0.45)))")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)
        case .files(let urls):
            let more = urls.count > 1 ? "  +\(urls.count - 1)" : ""
            Text("\(urls.first?.lastPathComponent ?? "File")\(Text(more).foregroundStyle(.white.opacity(0.45)))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private var accessibilityText: String {
        switch item.content {
        case .text(let string): return Self.oneLine(string)
        case .link(let url): return "Link, \(Self.address(of: url))"
        case .image(_, let pixels): return "Image, \(Int(pixels.width)) by \(Int(pixels.height))"
        case .files(let urls):
            return urls.count == 1 ? "File, \(urls[0].lastPathComponent)" : "\(urls.count) files"
        }
    }

    /// The text on one line: runs of spaces and line breaks become one space.
    static func oneLine(_ string: String) -> String {
        string.prefix(300)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// "github.com/clove/issues", without the scheme or "www.".
    static func address(of url: URL) -> String {
        var host = url.host ?? url.absoluteString
        if host.hasPrefix("www.") { host.removeFirst(4) }
        let path = url.path == "/" ? "" : url.path
        return host + path
    }

    static func age(of date: Date, at now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "now"
        case ..<3600: return "\(Int(seconds / 60))m"
        case ..<86_400: return "\(Int(seconds / 3600))h"
        default: return "\(Int(seconds / 86_400))d"
        }
    }
}

/// What a copy is, at a glance: the picture itself, the file's icon, or a glyph for text and
/// links, in a 22 pt square.
private struct ClipboardThumbnail: View {
    let content: ClipboardItem.Content

    private let side: CGFloat = 22

    var body: some View {
        switch content {
        case .image(let thumbnail, _):
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        case .files(let urls):
            Image(nsImage: Self.icon(for: urls.first))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: side, height: side)
        case .text:
            glyph("text.alignleft")
        case .link:
            glyph("link")
        }
    }

    private func glyph(_ symbol: String) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: side, height: side)
    }

    /// The icon for the file's kind (read from its extension, so no access to the file itself
    /// is needed, which the App Store build wouldn't have).
    private static func icon(for url: URL?) -> NSImage {
        guard let url else { return NSWorkspace.shared.icon(for: .data) }
        if url.hasDirectoryPath { return NSWorkspace.shared.icon(for: .folder) }
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        return NSWorkspace.shared.icon(for: type)
    }
}

/// Until Clove may read the clipboard: what the page is for, and the button that allows it.
private struct ClipboardSetupView: View {
    let access: ClipboardHistory.Access
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Remember what you copy")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(access == .notDetermined
                     ? "macOS asks first: choose Always Allow for Clove."
                     : "Set Clove to Always Allow in Paste from Other Apps.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: action) {
                Text(access == .notDetermined ? "Allow…" : "Open Settings")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 11)
                    .frame(height: 24)
                    .background(Capsule().fill(Color.white.opacity(0.14)))
                    .contentShape(Capsule())
            }
            .buttonStyle(.pressable(.normal))
            .fixedSize()
        }
        .frame(height: IslandLayout.clipboardSetupHeight)
    }
}

/// A copy, beside the notch: the island reaches a little lower than the camera and says
/// "Copied to clipboard" under it, with a green check. Music keeps its artwork and bars beside the
/// notch. Hovering it opens the island on the clipboard page.
struct CopiedNotice: View {
    let notchSize: CGSize
    let wingWidth: CGFloat
    /// What is playing, kept beside the notch; nil when nothing is.
    let nowPlaying: NowPlayingService?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let nowPlaying {
                    CompactMusicWings(nowPlaying: nowPlaying, notchSize: notchSize, wingWidth: wingWidth)
                }
            }
            .frame(height: notchSize.height)

            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green)
                    .font(.system(size: 12, weight: .semibold))
                Text("Copied to clipboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .tracking(-0.1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: IslandLayout.copiedStageHeight - 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Copied to clipboard")
    }
}
