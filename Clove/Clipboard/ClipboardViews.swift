import SwiftUI
import UniformTypeIdentifiers

/// The clipboard page: pinned items first, then recent copies, newest first, each under a small
/// header (Clear on the recent one). Text shows its first line, a link its address, a picture a
/// thumbnail and its size, files their icon and name. Clicking a row puts it back on the
/// clipboard; the pin that appears under the pointer keeps it forever. Until Clove may read the
/// clipboard, a row at the top asks for that. The page is never shorter than three rows.
struct ClipboardPageView: View {
    @ObservedObject var history: ClipboardHistory

    /// The row just clicked, which says "Copied" for a moment.
    @State private var justCopied: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var needsSetup: Bool { history.access != .allowed }

    var body: some View {
        let natural = IslandLayout.clipboardNaturalHeight(setup: needsSetup, pinned: history.pinned.count,
                                                          recent: history.items.count)
        if natural == 0 {
            MessageView(symbol: "doc.on.doc", text: String(localized: "Copy something and it shows up here"))
                .frame(maxHeight: .infinity)
        } else if natural > IslandLayout.clipboardMaxHeight {
            ScrollView(.vertical, showsIndicators: false) { sections }
        } else {
            VStack(spacing: 0) {
                // Asking for access, with nothing to list yet: in the middle of the page.
                if needsSetup, history.pinned.isEmpty, history.items.isEmpty { Spacer(minLength: 0) }
                sections
                Spacer(minLength: 0)
                // Room left under a short list: say what the pin is for.
                if history.pinned.isEmpty, !history.items.isEmpty,
                   IslandLayout.clipboardMinHeight - natural >= IslandLayout.clipboardRowHeight {
                    Label("Hover an item and pin it to keep it", systemImage: "pin")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(height: IslandLayout.clipboardRowHeight)
                }
            }
        }
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: IslandLayout.clipboardSectionGap) {
            if needsSetup {
                ClipboardSetupView(access: history.access, action: history.requestAccess)
                    .padding(.horizontal, ClipboardRow.inset)
            }
            if !history.pinned.isEmpty {
                section("Pinned", history.pinned, pinned: true)
            }
            if !history.items.isEmpty {
                section("Recently copied", history.items, pinned: false)
            }
        }
    }

    private func section(_ title: String, _ items: [ClipboardItem], pinned: Bool) -> some View {
        VStack(alignment: .leading, spacing: IslandLayout.clipboardHeaderGap) {
            HStack {
                Text(title)
                    .foregroundColor(.white.opacity(0.45))
                Spacer()
                if !pinned {
                    ClearButton(action: history.clear)
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, ClipboardRow.inset)
            .frame(height: IslandLayout.clipboardHeaderHeight)

            VStack(spacing: IslandLayout.clipboardRowSpacing) {
                ForEach(items) { item in
                    ClipboardRow(item: item, pinned: pinned, justCopied: justCopied == item.id,
                                 copy: { copy(item) },
                                 togglePin: { togglePin(item, pinned: pinned) })
                }
            }
        }
    }

    private func copy(_ item: ClipboardItem) {
        history.copy(item)
        Motion.perform(reduceMotion ? Motion.instant : Motion.fast) { justCopied = item.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard justCopied == item.id else { return }
            Motion.perform(reduceMotion ? Motion.instant : Motion.fast) { justCopied = nil }
        }
    }

    private func togglePin(_ item: ClipboardItem, pinned: Bool) {
        // The row moves between sections on the island's own spring as the page resizes.
        Motion.perform(Motion.snappy) {
            if pinned { history.unpin(item) } else { history.pin(item) }
        }
    }
}

/// "Clear" on the recent copies' header: forgets them (pinned items stay).
private struct ClearButton: View {
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text("Clear")
                .foregroundColor(.white.opacity(hovering ? 0.85 : 0.45))
        }
        .buttonStyle(.pressable(.normal, hoverWash: false))
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : Motion.hover, value: hovering)
        .accessibilityHint("Forgets the recent copies; pinned items stay")
    }
}

/// One copy: what it is on the left, what it says in the middle, how long ago on the right (a
/// pin for a pinned one). Brightens under the pointer, where the right side becomes the pin
/// button; a click anywhere else copies it again and says "Copied".
private struct ClipboardRow: View {
    let item: ClipboardItem
    let pinned: Bool
    let justCopied: Bool
    let copy: () -> Void
    let togglePin: () -> Void

    /// Inside the row's highlight, so text lines up with the header.
    static let inset: CGFloat = 4

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Button(action: copy) {
                HStack(spacing: 9) {
                    ClipboardThumbnail(content: item.content)
                    title
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(.subtle, hoverWash: false))
            .accessibilityLabel(accessibilityText)
            .accessibilityHint("Copies it again")

            trailing
                .frame(minWidth: 22, alignment: .trailing)
        }
        .padding(.horizontal, Self.inset)
        .frame(height: IslandLayout.clipboardRowHeight)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(hovering ? 0.08 : 0))
        )
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : Motion.hover, value: hovering)
        .animation(reduceMotion ? nil : Motion.fast, value: justCopied)
    }

    @ViewBuilder private var trailing: some View {
        ZStack(alignment: .trailing) {
            if justCopied {
                Label("Copied", systemImage: "checkmark")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.green)
                    .transition(.opacity)
            } else if hovering {
                PinButton(pinned: pinned, action: togglePin)
                    .transition(.opacity)
            } else if pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
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

/// Pins a copy (keeps it forever) or unpins it. Shown on the row under the pointer.
private struct PinButton: View {
    let pinned: Bool
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: pinned ? "pin.slash" : "pin")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(.white.opacity(hovering ? 1 : 0.6))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.white.opacity(hovering ? 0.12 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.pressable(.normal, hoverWash: false))
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : Motion.hover, value: hovering)
        .help(pinned ? "Unpin" : "Keep forever")
        .accessibilityLabel(pinned ? "Unpin" : "Pin, to keep it forever")
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
