import SwiftUI

/// Root view inside the notch panel. Motion is driven by the model (`Motion.perform`); this view
/// only declares how content enters and leaves (`Motion.swift` transitions), never its own timing.
struct NotchView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var nowPlaying: NowPlayingService

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        island
            // The teleprompter's handle hangs just below the island, outside it: pull it down.
            // It is fastened to the island's bottom edge, so it follows the edge exactly.
            .overlay(alignment: .top) {
                if model.state == .expanded && model.teleprompterActive {
                    TeleprompterHandle(onDrag: model.dragTeleprompter(by:), onEnd: model.endTeleprompterDrag(predicted:))
                        .traced("tele.handle", control: true)
                        // Below the content's bottom edge (padding, like the band), and below a
                        // toast's band when there is one (an offset, on the toast's spring).
                        .padding(.top, model.contentSize.height + IslandLayout.teleprompterHandleGap)
                        .fixedSize()
                        .offset(y: model.toastBandHeight)
                        .transition(.opacity.animation(Motion.fadeFast))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        #if DEBUG
        .modifier(ContinuityEnvironmentModifier())
        #endif
    }

    /// The island is what it shows (`content`, in its own frame) and, under that, the band a
    /// toast sits in. The band is not part of the frame: the black shape reaches down past the
    /// frame by `reach`, and the toast hangs from the frame's bottom edge. So the content's frame
    /// is only ever moved by what changes the content, the band only by a toast, and however
    /// the two overlap (a toast during an expand, a page switch during a toast) the band is at
    /// the island's base and nothing above it is moved by it.
    private var island: some View {
        content
            .modifier(IslandFrame(size: model.contentSize, band: ToastBand(toast: model.activities.toast)))
            .padding(.horizontal, model.topRadius)
            .background(NotchShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius,
                                   reach: model.toastBandHeight).fill(Color.black))
            .clipShape(NotchShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius,
                                  reach: model.toastBandHeight))
            .modifier(ShelfDrop(model: model))
            .environment(\.recorder, model.features.recorder)
            .shadow(color: .black.opacity(model.state == .expanded ? 0.35 : 0), radius: 10, y: 4)
            // A page coming into being or going away under the open island (a track starting or
            // ending): its tab, the page and the island's width adapt in one move.
            .animation(reduceMotion ? nil : Motion.gentle, value: model.availablePages)
    }

    private var content: some View {
        ZStack(alignment: .top) {
            // The Koi pond page fills the whole open island, behind the notch row.
            if model.state == .expanded, model.visiblePage == .pond, !model.voiceActive, !model.teleprompterActive {
                PondPageView(size: model.expandedSize, notchHeight: model.notchSize.height)
                    .traced("pond")
                    .transition(.opacity.animation(Motion.fadeFast))
            }

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
                                          showsNotificationText: model.settings.notificationText,
                                          onAgentAnswer: model.answerAgent)
                        .id(activity.id)
                        .transition(activity.kind.isNotice ? .noticeArrival(reduceMotion: reduceMotion)
                                                           : .cascade(0, reduceMotion: reduceMotion))
                } else if model.features.recorder.showsWings {
                    // The recording's wings, drawn below: one view, whether or not a notice hangs under it.
                } else if model.showsKoiPass && model.koiPassFirst {
                    KoiPassWings(notchSize: model.notchSize, wingWidth: IslandLayout.koiPassWing,
                                 onFinished: model.endKoiPass)
                        .traced("wings.koi")
                        .transition(.cascade(0, reduceMotion: reduceMotion))
                } else if model.showsMeetingActivity, let meeting = model.calendar.imminentMeeting {
                    MeetingSoonView(meeting: meeting, notchSize: model.notchSize)
                        .traced("wings.meeting")
                        .id(meeting.id)
                        .transition(.cascade(0, reduceMotion: reduceMotion))
                } else if model.showsAgentActivity, let agent = model.features.agents.workingAgent {
                    AgentWorkingWings(agent: agent, notchSize: model.notchSize, wingWidth: model.compactWing)
                        .traced("wings.agent")
                        .transition(.cascade(0, reduceMotion: reduceMotion))
                } else if model.showsMusicActivity {
                    CompactMusicWings(nowPlaying: nowPlaying, notchSize: model.notchSize, wingWidth: model.compactWing)
                        .transition(.cascade(0, reduceMotion: reduceMotion))
                } else if model.showsKoiPass {
                    KoiPassWings(notchSize: model.notchSize, wingWidth: IslandLayout.koiPassWing,
                                 onFinished: model.endKoiPass)
                        .traced("wings.koi")
                        .transition(.cascade(0, reduceMotion: reduceMotion))
                }
                // A recording stays in sight in the notch row while a notice hangs below it: the
                // same wings, which ride out to the notice's width and back.
                if model.showsRecordingWings {
                    let underNotice = model.activities.current != nil
                    RecordingWings(recorder: model.features.recorder, notchSize: model.notchSize,
                                   wingWidth: underNotice ? model.activityWingWidth : RecorderLayout.wing,
                                   rowOnly: underNotice)
                        .traced("wings.recording")
                        .transition(.cascade(0, reduceMotion: reduceMotion))
                }
            }

            // The music's artwork and bars: the same two views travel from the wings into the
            // player and back, as the island grows and shrinks.
            MusicTraveler(nowPlaying: nowPlaying, placement: model.musicPlacement, visible: model.showsMusicTraveler)
        }
    }

    /// Sizes what the island shows and hangs the toast's band from its bottom edge, both from
    /// one animated size. Because it is `Animatable`, SwiftUI hands it the size for each frame
    /// and the frame and the band's place are set from that same number: the band is on the
    /// edge at every frame, whatever else is animating. (Set as two modifiers, each kept its
    /// own animation, and a toast arriving while the island was closing sent the band up to
    /// 30 pt ahead of the edge.)
    private struct IslandFrame<Band: View>: ViewModifier, Animatable {
        var size: CGSize
        let band: Band

        var animatableData: CGSize.AnimatableData {
            get { size.animatableData }
            set { size.animatableData = newValue }
        }

        func body(content: Content) -> some View {
            content
                .frame(width: size.width, height: size.height, alignment: .top)
                // What is leaving the content never spills into the band.
                .clipped()
                .traced("island")
                .overlay(alignment: .top) {
                    band
                        .padding(.top, size.height)
                        .fixedSize(horizontal: false, vertical: true)
                }
        }
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
                if model.state == .expanded && model.teleprompterActive {
                    // The teleprompter fills the island below the camera, in place of the pages.
                    Color.clear.frame(height: model.notchSize.height)
                    TeleprompterView(controller: model.features.teleprompter,
                                     fontSize: CGFloat(model.settings.teleprompterFontSize))
                        .environment(\.colorScheme, .dark)
                        .traced("tele.script")
                        .transition(.cascade(1, reduceMotion: reduceMotion))
                } else if model.state == .expanded && model.voiceActive {
                    // A voice note fills the island below the camera, in place of the pages.
                    Color.clear.frame(height: model.notchSize.height)
                    VoiceIslandView(controller: model.voice, onHeightChange: model.setVoiceHeight)
                        .environment(\.colorScheme, .dark)
                        .transition(.cascade(1, reduceMotion: reduceMotion))
                } else if model.state == .expanded {
                    notchRow
                        .transition(.bloomReveal(reduceMotion: reduceMotion))
                    page
                        .frame(height: model.expandedContentHeight, alignment: .top)
                        .traced("page")
                        .padding(.horizontal, IslandLayout.horizontalPadding)
                        .padding(.top, IslandLayout.contentTopPadding)
                        .transition(.bloomReveal(reduceMotion: reduceMotion))
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
                                .traced("tab.\(page)", control: true)
                        }
                    }
                    .traced("tabs", control: true)
                    .transition(.opacity.animation(Motion.fadeFast))
                }
                Spacer(minLength: model.notchSize.width)
                HStack(spacing: 14) {
                    if model.settings.isEnabled(.recorder), model.visiblePage != .recorder {
                        RecordingRowBadge(recorder: model.features.recorder) { model.show(.recorder) }
                    }
                    if model.settings.isEnabled(.teleprompter) {
                        Button(action: { model.startTeleprompter() }) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.pressable)
                        .help("Start the teleprompter")
                    }
                    if model.settings.isEnabled(.keepAwake) {
                        KeepAwakeButton(keepAwake: model.features.keepAwake, action: model.toggleKeepAwake)
                            .traced("ctl.keepAwake", control: true)
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
                .traced("rowbuttons", control: true)
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
                        .traced("page.calendar")
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else if model.visiblePage == .tasks {
                    TasksView(linear: linear, expanded: model.tasksExpanded, onViewMore: model.showMoreTasks)
                        .traced("page.tasks")
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else if model.visiblePage == .system {
                    SystemPageView(system: model.system)
                        .traced("page.system")
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else if model.visiblePage == .apps {
                    AppsPageView(apps: model.features.apps)
                        .traced("page.apps")
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else if model.visiblePage == .agents {
                    AgentsPageView(hub: model.features.agents,
                                   connected: AgentKind.allCases.contains(where: AgentHooks.isConnected))
                        .traced("page.agents")
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else if model.visiblePage == .recorder {
                    RecorderPageView(recorder: model.features.recorder)
                        .traced("page.recorder")
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else if model.visiblePage == .clipboard {
                    ClipboardTabView(model: model, shelf: model.features.shelf)
                        .traced("page.clipboard")
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else if model.visiblePage == .pond {
                    // The pond itself is drawn behind the whole island (see `island`).
                    Color.clear
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else if nowPlaying.track != nil {
                    ExpandedPlayerView(service: nowPlaying)
                        .traced("page.player")
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else {
                    MessageView(symbol: "music.note", text: String(localized: "Nothing playing"))
                        .traced("page.nothing")
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
            case .agents: return "sparkles"
            case .apps: return "square.grid.2x2"
            case .recorder: return model.features.recorder.showsWings ? "record.circle.fill" : "record.circle"
            case .pond: return "fish"
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

        @State private var hovering = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var isSelected: Bool { model.visiblePage == page }

        var body: some View {
            Button(action: { model.show(page) }) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected || hovering ? .white : .white.opacity(0.45))
                    .frame(width: IslandLayout.tabWidth)
                    .padding(.vertical, 3)
                    .background {
                        // Hover lights the same shape the selection fills, inside the tab, so it
                        // never reaches a neighbour. A selected tab takes no hover.
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.14))
                                .matchedGeometryEffect(id: "pageSelection", in: namespace)
                        } else {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(hovering ? 0.07 : 0))
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(.normal, hoverWash: false))
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : Motion.hover, value: hovering)
        }
    }
}

/// What is playing, beside the notch on the collapsed island: the artwork in the left wing, the
/// bars in the right, each centred in its narrow wing. Both are drawn by `MusicTraveler`, so they
/// can travel into the player; this view keeps their places and says what is playing.
struct CompactMusicWings: View {
    @ObservedObject var nowPlaying: NowPlayingService
    let notchSize: CGSize
    let wingWidth: CGFloat

    var body: some View {
        Color.clear
            .frame(width: notchSize.width + 2 * wingWidth, height: notchSize.height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(nowPlaying.track?.title ?? ""))
    }
}

/// The music's artwork and bars, drawn once over the island and moved by the island's own spring
/// between the wings beside the notch and the open player. The wings and the player only keep
/// their places, so nothing pops in or swaps: the same two things grow and travel.
struct MusicTraveler: View {
    @ObservedObject var nowPlaying: NowPlayingService
    let placement: NotchViewModel.MusicPlacement
    let visible: Bool

    /// The last artwork, which the pair keeps while it fades out after the track has ended.
    @State private var lastArtwork: NSImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ArtworkView(image: nowPlaying.track == nil ? lastArtwork : nowPlaying.artwork,
                        size: placement.art.width, cornerRadius: placement.artRadius)
                .traced("art")
                .offset(x: placement.art.minX, y: placement.art.minY)
            EqualizerView(isPlaying: nowPlaying.isPlaying, color: nowPlaying.accentColor)
                .traced("bars")
                .scaleEffect(placement.barsScale)
                .position(placement.bars)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Only the fade runs on its own clock. (An `.animation(_:value:)` here also took over
        // the pair's travel whenever they appeared or left in the same update, so they shot
        // across on a tween instead of riding the island's spring.)
        .animation(Motion.fadeFast) { $0.opacity(visible ? 1 : 0) }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: nowPlaying.artwork, initial: true) { _, artwork in
            if let artwork { lastArtwork = artwork }
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
        // Always the same view: while the island is closed or the shelf is off, the drop simply
        // accepts nothing. (Wrapping `content` in an `if` here gave the whole island a new
        // identity each time it opened or closed, so it was torn down and cross-faded with a
        // fresh copy instead of growing.)
        let accepts = model.state == .expanded && model.clipboardModes.contains(.shelf)
        content.onDrop(of: accepts ? [.fileURL] : [], isTargeted: Binding(get: { model.shelfTargeted },
                                                                          set: { model.setShelfTargeted($0) })) { providers in
            guard accepts else { return false }
            load(providers)
            return true
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
