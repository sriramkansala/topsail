import SwiftUI

/// Root view inside the notch panel. Motion is driven by the model (`Motion.perform`); this view
/// only declares how content enters and leaves (`Motion.swift` transitions), never its own timing.
struct NotchView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var nowPlaying: NowPlayingService

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            island
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var island: some View {
        ZStack(alignment: .top) {
            // Always mounted; its parts enter and leave with the expanded state.
            ExpandedContent(model: model, nowPlaying: nowPlaying, calendar: model.calendar,
                            linear: model.linear, clipboard: model.clipboard)

            if model.state == .collapsed {
                if let activity = model.activities.current {
                    TransientActivityView(activity: activity,
                                          notchSize: model.notchSize,
                                          wingWidth: model.activityWingWidth,
                                          meterHeight: model.activities.meterHeight,
                                          onRequestLowPowerMode: model.requestLowPowerMode,
                                          onMeetingAnswer: model.answerMeeting,
                                          nowPlaying: model.showsMusicActivity ? nowPlaying : nil)
                        .id(activity.id)
                        .transition(activity.kind.isNotice ? .noticeBlur(reduceMotion: reduceMotion)
                                                           : .cascade(0, reduceMotion: reduceMotion))
                } else if model.showsMeetingActivity, let meeting = model.calendar.imminentMeeting {
                    MeetingSoonView(meeting: meeting, notchSize: model.notchSize)
                        .id(meeting.id)
                        .transition(.cascade(0, reduceMotion: reduceMotion))
                } else if model.showsMusicActivity {
                    CompactMusicWings(nowPlaying: nowPlaying, notchSize: model.notchSize, wingWidth: model.compactWing)
                        .transition(.cascade(0, reduceMotion: reduceMotion))
                }
            }
        }
        .frame(width: model.islandSize.width, height: model.islandSize.height, alignment: .top)
        .frame(width: model.islandSize.width + 2 * model.topRadius, height: model.islandSize.height)
        .background(NotchShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius).fill(Color.black))
        .clipShape(NotchShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius))
        .modifier(ShelfDrop(model: model))
        .shadow(color: .black.opacity(model.state == .expanded ? 0.35 : 0), radius: 10, y: 4)
    }

    private struct ExpandedContent: View {
        @ObservedObject var model: NotchViewModel
        @ObservedObject var nowPlaying: NowPlayingService
        @ObservedObject var calendar: CalendarService
        @ObservedObject var linear: LinearService
        @ObservedObject var clipboard: ClipboardHistory

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Namespace private var pageNamespace

        var body: some View {
            VStack(spacing: 0) {
                if model.state == .expanded && model.voiceActive {
                    // A voice note fills the island below the camera, in place of the pages.
                    Color.clear.frame(height: model.notchSize.height)
                    VoiceIslandView(controller: model.voice, onHeightChange: model.setVoiceHeight)
                        .environment(\.colorScheme, .dark)
                        .transition(.cascade(1, reduceMotion: reduceMotion))
                } else if model.state == .expanded {
                    notchRow
                        .transition(.cascade(0, reduceMotion: reduceMotion))
                    page
                        .frame(height: model.expandedContentHeight, alignment: .top)
                        .padding(.horizontal, IslandLayout.horizontalPadding)
                        .padding(.top, IslandLayout.contentTopPadding)
                        .transition(.cascade(1, reduceMotion: reduceMotion))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }

        /// The row level with the camera: tabs to its left, the gear to its right, nothing under it.
        private var notchRow: some View {
            HStack(spacing: 0) {
                if model.showsPageTabs {
                    HStack(spacing: IslandLayout.tabSpacing) {
                        ForEach(model.availablePages, id: \.self) { page in
                            PageTab(symbol: Self.symbol(for: page, model: model), page: page, model: model,
                                    namespace: pageNamespace)
                        }
                    }
                    .transition(.opacity.animation(reduceMotion ? nil : Motion.fast))
                }
                Spacer(minLength: model.notchSize.width)
                HStack(spacing: 14) {
                    if model.settings.isEnabled(.keepAwake) {
                        KeepAwakeButton(keepAwake: model.features.keepAwake, action: model.toggleKeepAwake)
                    }
                    if model.linear.isConnected {
                        Button(action: { model.toggleVoice() }) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.pressable)
                        .help("Record a voice note for Linear")
                    }
                    Button(action: { model.openSettings() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.leading, IslandLayout.horizontalPadding - IslandLayout.tabPadding)
            .padding(.trailing, IslandLayout.horizontalPadding)
            .frame(height: model.notchSize.height)
        }

        /// One page at a time. Both branches live in a ZStack so the incoming page mounts at
        /// once and the two overlap under the morph's blur instead of waiting on each other.
        private var page: some View {
            ZStack(alignment: .top) {
                if model.visiblePage == .calendar {
                    CalendarTabView(model: model, calendar: calendar, reminders: model.features.reminders)
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else if model.visiblePage == .tasks {
                    TasksView(linear: linear, expanded: model.tasksExpanded, onViewMore: model.showMoreTasks)
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else if model.visiblePage == .system {
                    SystemPageView(system: model.system)
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else if model.visiblePage == .clipboard {
                    ClipboardTabView(model: model, shelf: model.features.shelf)
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else if nowPlaying.track != nil {
                    ExpandedPlayerView(service: nowPlaying)
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else {
                    MessageView(symbol: "music.note", text: "Nothing playing")
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                }
            }
            .frame(maxWidth: .infinity)
        }

        private static func symbol(for page: NotchViewModel.ExpandedPage, model: NotchViewModel) -> String {
            switch page {
            case .player: return "music.note"
            case .calendar: return "calendar"
            case .tasks: return "checklist"
            case .system: return "gauge.with.dots.needle.50percent"
            case .clipboard: return model.clipboardModes == [.shelf] ? "tray.full" : "doc.on.doc"
            }
        }
    }

    /// A notch-row page button. The selection is one pill that travels between tabs
    /// (`matchedGeometryEffect`, moved by the model on `Motion.snappy`), not two fills cross-fading.
    private struct PageTab: View {
        let symbol: String
        let page: NotchViewModel.ExpandedPage
        @ObservedObject var model: NotchViewModel
        let namespace: Namespace.ID

        private var isSelected: Bool { model.visiblePage == page }

        var body: some View {
            Button(action: { model.show(page) }) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.45))
                    .frame(width: IslandLayout.tabWidth)
                    .padding(.vertical, 3)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.14))
                                .matchedGeometryEffect(id: "pageSelection", in: namespace)
                        }
                    }
                    .contentShape(Rectangle())
            }
            // Selected items get no hover wash.
            .buttonStyle(.pressable(.normal, hoverWash: !isSelected))
        }
    }
}

/// What is playing, beside the notch on the collapsed island: the artwork in the left wing, the
/// bars in the right, each centred in its narrow wing.
struct CompactMusicWings: View {
    @ObservedObject var nowPlaying: NowPlayingService
    let notchSize: CGSize
    let wingWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ArtworkView(image: nowPlaying.artwork, size: 22, cornerRadius: 6)
                .frame(width: wingWidth, height: notchSize.height)

            Color.clear
                .frame(width: notchSize.width, height: notchSize.height)

            EqualizerView(isPlaying: nowPlaying.isPlaying, color: nowPlaying.accentColor)
                .frame(width: wingWidth, height: notchSize.height)
        }
    }
}

/// ☕ in the notch row: Keep Awake, amber while it's on.
private struct KeepAwakeButton: View {
    @ObservedObject var keepAwake: KeepAwake
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: keepAwake.isOn ? "cup.and.saucer.fill" : "cup.and.saucer")
                .font(.system(size: 12))
                .foregroundColor(keepAwake.isOn ? TransientActivityView.awake : .white.opacity(0.6))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.pressable)
        .help(keepAwake.isOn ? "Keep Awake is on: click to let your Mac sleep" : "Keep Awake: stop your Mac sleeping")
        .accessibilityLabel(keepAwake.isOn ? "Keep Awake, on" : "Keep Awake, off")
    }
}

/// The open island takes files dropped anywhere on it, for the shelf (when the shelf is on).
private struct ShelfDrop: ViewModifier {
    @ObservedObject var model: NotchViewModel

    func body(content: Content) -> some View {
        if model.state == .expanded && model.clipboardModes.contains(.shelf) {
            content.onDrop(of: [.fileURL], isTargeted: Binding(get: { model.shelfTargeted },
                                                               set: { model.setShelfTargeted($0) })) { providers in
                load(providers)
                return true
            }
        } else {
            content
        }
    }

    private func load(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url, url.isFileURL {
                    lock.lock(); urls.append(url); lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            MainActor.assumeIsolated {
                model.shelfDropped(urls)
            }
        }
    }
}
