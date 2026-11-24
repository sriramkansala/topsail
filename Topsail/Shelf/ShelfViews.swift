import SwiftUI
import UniformTypeIdentifiers

/// The clipboard tab: the clipboard history, the file shelf, or both with a switch above them.
struct ClipboardTabView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var shelf: ShelfStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: IslandLayout.pageSwitchGap) {
            if model.clipboardModes.count > 1 {
                PageSwitch(options: [
                    .init(title: "Clipboard", selected: model.visibleClipboardMode == .clipboard) {
                        model.showClipboardMode(.clipboard)
                    },
                    .init(title: "Shelf", count: shelf.items.isEmpty ? nil : shelf.items.count,
                          selected: model.visibleClipboardMode == .shelf) {
                        model.showClipboardMode(.shelf)
                    },
                ])
            }
            ZStack(alignment: .top) {
                if model.visibleClipboardMode == .shelf {
                    ShelfPageView(shelf: shelf, targeted: model.shelfTargeted)
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else {
                    ClipboardPageView(history: model.clipboard)
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// Files parked on the notch: a row of tiles under a header with AirDrop and Clear. Drag a tile
/// out to use the file; double-click opens it; right-click for the rest. Empty, it's a drop
/// zone; while files are dragged over the island, the drop zone lights up.
struct ShelfPageView: View {
    @ObservedObject var shelf: ShelfStore
    let targeted: Bool

    var body: some View {
        if shelf.items.isEmpty {
            DropZone(targeted: targeted)
        } else {
            VStack(alignment: .leading, spacing: IslandLayout.clipboardHeaderGap) {
                HStack(spacing: 14) {
                    Text("\(shelf.items.count) on the shelf")
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                    HeaderButton(title: "AirDrop", symbol: "dot.radiowaves.left.and.right") {
                        shelf.airDrop(shelf.items)
                    }
                    HeaderButton(title: "Clear", symbol: nil) { shelf.clear() }
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 4)
                .frame(height: IslandLayout.clipboardHeaderHeight)

                tiles
                    .overlay {
                        if targeted {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.6)))
                                .overlay {
                                    Label("Drop to add", systemImage: "tray.and.arrow.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                        }
                    }
            }
        }
    }

    @ViewBuilder private var tiles: some View {
        let row = HStack(spacing: 4) {
            ForEach(shelf.items) { item in
                ShelfTile(item: item, thumbnail: shelf.thumbnails[item.id], shelf: shelf)
            }
        }
        if shelf.items.count > IslandLayout.shelfVisibleTiles {
            ScrollView(.horizontal, showsIndicators: false) { row }
                .frame(height: IslandLayout.shelfTileHeight)
        } else {
            row
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: IslandLayout.shelfTileHeight)
        }
    }
}

/// The empty shelf: a dashed outline that says where files go, brighter while they're over it.
private struct DropZone: View {
    let targeted: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.white.opacity(targeted ? 0.6 : 0.2), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(targeted ? 0.08 : 0.03)))
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 18, weight: .medium))
                    Text(targeted ? "Drop to add to the shelf" : "Drag files here to keep them at hand")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(targeted ? 0.9 : 0.5))
            }
            .animation(Motion.fast, value: targeted)
    }
}

/// A file on the shelf: its thumbnail (or icon) over its name. Brightens under the pointer and
/// shows a remove button; drag it out to use it.
private struct ShelfTile: View {
    let item: ShelfItem
    let thumbnail: NSImage?
    @ObservedObject var shelf: ShelfStore

    @State private var hovering = false

    var body: some View {
        VStack(spacing: 5) {
            Image(nsImage: thumbnail ?? ShelfStore.icon(for: item.url))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: IslandLayout.shelfThumbnailSize, height: IslandLayout.shelfThumbnailSize)
            Text(item.name)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .frame(height: 26, alignment: .top)
        }
        .frame(width: IslandLayout.shelfTileWidth, height: IslandLayout.shelfTileHeight)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(hovering ? 0.08 : 0)))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button(action: { shelf.remove(item) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(white: 0.3))
                }
                .buttonStyle(.plain)
                .help("Remove from the shelf")
                .offset(x: 2, y: -2)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(Motion.hover, value: hovering)
        .onTapGesture(count: 2) { shelf.open(item) }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { shelf.open(item) }
            Button("Show in Finder") { shelf.reveal(item) }
            Button("Copy") { shelf.copy([item]) }
            Button("AirDrop…") { shelf.airDrop([item]) }
            Divider()
            Button("Remove from Shelf") { shelf.remove(item) }
        }
        .help(item.name)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityHint("Drag to use the file, double-click to open it")
    }
}

/// A quiet text button in a page header (AirDrop, Clear).
private struct HeaderButton: View {
    let title: LocalizedStringKey
    let symbol: String?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .foregroundColor(.white.opacity(hovering ? 0.85 : 0.45))
        }
        .buttonStyle(.pressable(.normal, hoverWash: false))
        .onHover { hovering = $0 }
        .animation(Motion.hover, value: hovering)
    }
}
