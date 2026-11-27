# The continuity matrix

Every change on the island must be continuous: nothing pops, swaps, jumps or changes page without
being asked. This document maps every state the island can be in against everything that can
happen to it, says in one line what must happen in each case, and each of those lines is a test
that runs on the real island.

Run all of it with one command:

```bash
scripts/continuity.sh
```

It builds the direct flavour, takes over the notch for about twenty minutes (the Topsail that is
running is quit and reopened afterwards), runs every cell below with made-up data, checks each
frame-by-frame trace and prints which cells pass. `scripts/continuity.sh 'toast.*'` runs only
the cells whose id matches; `open topsail://test/<cell-id>` runs one from a debug build.

## The rules (settled; the tests hold the island to them)

- **Corner radii.** 6/14 closed and 14/24 open, never anything else, notices included.
- **Continuity.** Anything visible in two states is one view that travels (the music's artwork
  and bars are the model: `MusicTraveler`), never a second copy fading in.
- **Toasts** (Copied, Keep Awake, volume and brightness; outside copies and in-app confirmations
  alike). They sit in a band at the base of the island and slide up from the bottom edge. Their
  icon is a neutral grey. They leave the way they came. They never change the page and never
  cover a control. On the closed island, the island grows just enough to hold the band and the
  band slides up inside it.
- **Notices** (low battery, a call starting, a device, an agent asking, a notification, a
  recording saved) grow out of the notch: the shape leads and the words follow.
- **Pages** change only when the user picks one or a relevance rule fires as the island opens:
  a copy within 60 s opens the clipboard, a call within 10 min the calendar, music the player.
- **In the notch.** Everything except Settings happens in the notch.
- **Icons.** Free Pikaicons only (not something a trace can check; see the report).

## States

From `NotchViewModel` and `NotchView`. The island is `collapsed` or `expanded`.

**Closed**, by what is beside the notch. One thing shows at a time, in this order of precedence
(`NotchView.island`, `restingIslandSize`):

1. an activity or notice (`ActivityCenter.current`): the charging moment, a task due, an agent
   finished (wings); low battery, a call's reminder, a device, an agent's request, a
   notification, a recording saved (a card below the camera);
2. a recording (`Recorder.showsWings`);
3. a koi asked for (`koiPassFirst`);
4. a call within ten minutes (`showsMeetingActivity`);
5. an agent working (`showsAgentActivity`);
6. music (`showsMusicActivity`), whose artwork and bars are the travelling pair;
7. a passing koi (`showsKoiPass`);
8. nothing: the bare notch.

On top of any of them: **leaning** (the pointer within 44 pt: 6 pt wider, 3 pt taller) and a
**toast** in the band at the base.

**Open**, by what fills it:

- one of nine pages (`ExpandedPage`): pond, player, calendar, tasks, system, clipboard, agents,
  apps, recorder. Which exist depends on settings and on what is going on; the player exists
  only while there is a track;
- the teleprompter, any height from 120 to 400 pt, its handle hanging below the island;
- a voice note (not in the matrix: it needs the microphone and a Linear account; it shares the
  open island's code paths that are tested here).

With, in any of them: music or none, a recording (its badge in the notch row), agents (their
page), and a toast in the band at the base.

**Reduce Motion** on or off, in all of the above.

## Triggers

| Trigger | How the test fires it |
| --- | --- |
| Pointer comes near, rests on the island, moves inside, leaves | the test's own pointer, through the same `handleMouse` the real mouse drives (lean at once, open after 90 ms of rest, close 150 ms after leaving) |
| Click on a control (a tab, Keep Awake, a clipboard row) | a real mouse-down and mouse-up delivered to the window at the control's traced position |
| Page switch | a click on the page's tab |
| Each `ActivityKind` (13) | `ActivityCenter.post`, with made-up contents |
| Media keys | the posts a held volume or brightness key makes, 70 ms apart; mute |
| Keep Awake | a click on its button in the notch row |
| Copy | a copy "in another app" (the clipboard history's own `onCopy` path), and a click on a clipboard row (copy back) |
| Teleprompter | start, stop, and its handle dragged and let go with momentum |
| Display change | another display's notch size, as `reposition()` applies it |
| Something starting or stopping beside the notch | music, a recording, an agent, a call coming up, a koi |
| Reduce Motion | the cell's own setting, read by the views and by `Motion.perform` |

## Cells

Each line is one test: a starting state, the triggers with their exact times, and the expected
result. The table is written from the app's own list (`ContinuityCells.swift`) on every run, so
it is the suite.

<!-- cells:start -->

220 cells in 11 groups. Times are milliseconds after the trace starts.

### Hover (17)

| Cell | Starts | Triggers | Expected |
| --- | --- | --- | --- |
| `hover.idle` | closed | 250 pointer near; 400 pointer on the island; 1700 pointer away | Leans, opens on calendar in one growth, then closes in one; what is beside the notch travels or fades, never pops. *(ends closed, page calendar)* |
| `hover.music` | closed · music playing | 250 pointer near; 400 pointer on the island; 1700 pointer away | Leans, opens on player in one growth, then closes in one; what is beside the notch travels or fades, never pops. *(ends closed, page player)* |
| `hover.recording` | closed · recording | 250 pointer near; 400 pointer on the island; 1700 pointer away | Leans, opens on recorder in one growth, then closes in one; what is beside the notch travels or fades, never pops. *(ends closed, page recorder)* |
| `hover.agent` | closed · agent | 250 pointer near; 400 pointer on the island; 1700 pointer away | Leans, opens on calendar in one growth, then closes in one; what is beside the notch travels or fades, never pops. *(ends closed, page calendar)* |
| `hover.meeting` | closed · meeting | 250 pointer near; 400 pointer on the island; 1700 pointer away | Leans, opens on calendar in one growth, then closes in one; what is beside the notch travels or fades, never pops. *(ends closed, page calendar)* |
| `hover.koi` | closed · koi | 250 pointer near; 400 pointer on the island; 1700 pointer away | Leans, opens on calendar in one growth, then closes in one; what is beside the notch travels or fades, never pops. *(ends closed, page calendar)* |
| `hover.music+recording` | closed · music playing · recording | 250 pointer near; 400 pointer on the island; 1700 pointer away | Leans, opens on recorder in one growth, then closes in one; what is beside the notch travels or fades, never pops. *(ends closed, page recorder)* |
| `hover.music+agent` | closed · music playing · agent | 250 pointer near; 400 pointer on the island; 1700 pointer away | Leans, opens on player in one growth, then closes in one; what is beside the notch travels or fades, never pops. *(ends closed, page player)* |
| `hover.music+meeting` | closed · music playing · meeting | 250 pointer near; 400 pointer on the island; 1700 pointer away | Leans, opens on calendar in one growth, then closes in one; what is beside the notch travels or fades, never pops. *(ends closed, page calendar)* |
| `hover.charging` | closed · charging | 250 pointer on the island; 1500 pointer away | The charging moment gives way to the open island in one growth; closing returns to the notch. *(ends closed, page calendar)* |
| `hover.music-paused` | closed · music paused | 250 pointer on the island; 1500 pointer away | Paused music still opens on the player; the artwork travels both ways. *(ends closed, page player)* |
| `lean.idle` | closed | 250 pointer near; 1100 pointer away | The closed island leans 6 pt wider and 3 pt taller toward the pointer and settles back; nothing else changes. *(ends closed)* |
| `hover.from-leaning.idle` | leaning | 250 pointer on the island; 1500 pointer away | From leaning, resting on the island opens it in one growth; leaving closes it. *(ends closed)* |
| `lean.music` | closed · music playing | 250 pointer near; 1100 pointer away | The closed island leans 6 pt wider and 3 pt taller toward the pointer and settles back; nothing else changes. *(ends closed)* |
| `hover.from-leaning.music` | leaning · music playing | 250 pointer on the island; 1500 pointer away | From leaning, resting on the island opens it in one growth; leaving closes it. *(ends closed)* |
| `hover.all-pages.music` | closed · music playing · all pages | 250 pointer near; 400 pointer on the island; 1700 pointer away | With every page on (nine tabs), the island still opens on the player and closes in one move each. *(ends closed, page player)* |
| `hover.all-pages.idle` | closed · all pages | 250 pointer near; 400 pointer on the island; 1700 pointer away | With nothing going on and the pond on, the island opens on the pond. *(ends closed, page pond)* |

### Pages (15)

| Cell | Starts | Triggers | Expected |
| --- | --- | --- | --- |
| `page.pond-player` | open: pond · music playing · all pages | 250 click tab.player | Height and page change together in one move; the selection pill travels; the island stays centred. *(ends open, page player)* |
| `page.player-calendar` | open: player · music playing · all pages | 250 click tab.calendar | Height and page change together in one move; the selection pill travels; the island stays centred. *(ends open, page calendar)* |
| `page.calendar-tasks` | open: calendar · music playing · all pages | 250 click tab.tasks | Height and page change together in one move; the selection pill travels; the island stays centred. *(ends open, page tasks)* |
| `page.tasks-system` | open: tasks · music playing · all pages | 250 click tab.system | Height and page change together in one move; the selection pill travels; the island stays centred. *(ends open, page system)* |
| `page.system-clipboard` | open: system · music playing · all pages | 250 click tab.clipboard | Height and page change together in one move; the selection pill travels; the island stays centred. *(ends open, page clipboard)* |
| `page.clipboard-agents` | open: clipboard · music playing · all pages | 250 click tab.agents | Height and page change together in one move; the selection pill travels; the island stays centred. *(ends open, page agents)* |
| `page.agents-apps` | open: agents · music playing · all pages | 250 click tab.apps | Height and page change together in one move; the selection pill travels; the island stays centred. *(ends open, page apps)* |
| `page.apps-recorder` | open: apps · music playing · all pages | 250 click tab.recorder | Height and page change together in one move; the selection pill travels; the island stays centred. *(ends open, page recorder)* |
| `page.recorder-pond` | open: recorder · music playing · all pages | 250 click tab.pond | Height and page change together in one move; the selection pill travels; the island stays centred. *(ends open, page pond)* |
| `page.no-music.calendar-system` | open: calendar | 250 click tab.system | Height and page change together in one move. *(ends open, page system)* |
| `page.no-music.system-clipboard` | open: system | 250 click tab.clipboard | Height and page change together in one move. *(ends open, page clipboard)* |
| `page.no-music.clipboard-calendar` | open: clipboard | 250 click tab.calendar | Height and page change together in one move. *(ends open, page calendar)* |
| `page.player-calendar-player` | open: player · music playing | 250 click tab.calendar; 1000 click tab.player | Away from the player and back: the artwork and bars leave and return without a second copy. *(ends open, page player)* |
| `page.quick-three` | open: player · music playing | 250 click tab.calendar; 400 click tab.system; 550 click tab.clipboard | Three picks 150 ms apart: the island retargets each time and ends on the last, with no jump. *(ends open, page clipboard)* |
| `page.clipboard-shelf` | open: clipboard · music playing · all pages | 250 pick Shelf; 1100 pick Clipboard | The Clipboard / Shelf switch changes the page's height in one move each way. *(ends open, page clipboard)* |

### Toasts (88)

| Cell | Starts | Triggers | Expected |
| --- | --- | --- | --- |
| `toast.copied.closed.idle` | closed | 250 copy | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.copied.closed.music` | closed · music playing | 250 copy | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.copied.closed.recording` | closed · recording | 250 copy | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.copied.closed.agent` | closed · agent | 250 copy | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.copied.closed.meeting` | closed · meeting | 250 copy | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.copied.closed.koi` | closed · koi | 250 copy | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.copied.closed.leaning` | leaning | 250 copy | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.copied.closed.leaning+music` | leaning · music playing | 250 copy | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.copied.open.pond` | open: pond · music playing · all pages | 250 copy | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page pond)* |
| `toast.copied.open.player` | open: player · music playing · all pages | 250 copy | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page player)* |
| `toast.copied.open.calendar` | open: calendar · music playing · all pages | 250 copy | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page calendar)* |
| `toast.copied.open.tasks` | open: tasks · music playing · all pages | 250 copy | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page tasks)* |
| `toast.copied.open.system` | open: system · music playing · all pages | 250 copy | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page system)* |
| `toast.copied.open.clipboard` | open: clipboard · music playing · all pages | 250 copy | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page clipboard)* |
| `toast.copied.open.agents` | open: agents · music playing · all pages | 250 copy | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page agents)* |
| `toast.copied.open.apps` | open: apps · music playing · all pages | 250 copy | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page apps)* |
| `toast.copied.open.recorder` | open: recorder · music playing · all pages | 250 copy | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page recorder)* |
| `toast.copied.open.calendar.no-music` | open: calendar | 250 copy | Same as with music: the band at the base, the page untouched. *(ends open, page calendar)* |
| `toast.copied.open.system.no-music` | open: system | 250 copy | Same as with music: the band at the base, the page untouched. *(ends open, page system)* |
| `toast.copied.open.clipboard.no-music` | open: clipboard | 250 copy | Same as with music: the band at the base, the page untouched. *(ends open, page clipboard)* |
| `toast.copied.teleprompter` | teleprompter | 250 copy | The teleprompter keeps its height and script; the band is added at the base and the handle follows the edge. *(ends open)* |
| `toast.keepAwake.closed.idle` | closed | 250 Keep Awake | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.keepAwake.closed.music` | closed · music playing | 250 Keep Awake | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.keepAwake.closed.recording` | closed · recording | 250 Keep Awake | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.keepAwake.closed.agent` | closed · agent | 250 Keep Awake | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.keepAwake.closed.meeting` | closed · meeting | 250 Keep Awake | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.keepAwake.closed.koi` | closed · koi | 250 Keep Awake | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.keepAwake.closed.leaning` | leaning | 250 Keep Awake | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.keepAwake.closed.leaning+music` | leaning · music playing | 250 Keep Awake | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.keepAwake.open.pond` | open: pond · music playing · all pages | 250 click ctl.keepAwake | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page pond)* |
| `toast.keepAwake.open.player` | open: player · music playing · all pages | 250 click ctl.keepAwake | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page player)* |
| `toast.keepAwake.open.calendar` | open: calendar · music playing · all pages | 250 click ctl.keepAwake | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page calendar)* |
| `toast.keepAwake.open.tasks` | open: tasks · music playing · all pages | 250 click ctl.keepAwake | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page tasks)* |
| `toast.keepAwake.open.system` | open: system · music playing · all pages | 250 click ctl.keepAwake | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page system)* |
| `toast.keepAwake.open.clipboard` | open: clipboard · music playing · all pages | 250 click ctl.keepAwake | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page clipboard)* |
| `toast.keepAwake.open.agents` | open: agents · music playing · all pages | 250 click ctl.keepAwake | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page agents)* |
| `toast.keepAwake.open.apps` | open: apps · music playing · all pages | 250 click ctl.keepAwake | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page apps)* |
| `toast.keepAwake.open.recorder` | open: recorder · music playing · all pages | 250 click ctl.keepAwake | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page recorder)* |
| `toast.keepAwake.open.calendar.no-music` | open: calendar | 250 Keep Awake | Same as with music: the band at the base, the page untouched. *(ends open, page calendar)* |
| `toast.keepAwake.open.system.no-music` | open: system | 250 Keep Awake | Same as with music: the band at the base, the page untouched. *(ends open, page system)* |
| `toast.keepAwake.open.clipboard.no-music` | open: clipboard | 250 Keep Awake | Same as with music: the band at the base, the page untouched. *(ends open, page clipboard)* |
| `toast.keepAwake.teleprompter` | teleprompter | 250 Keep Awake | The teleprompter keeps its height and script; the band is added at the base and the handle follows the edge. *(ends open)* |
| `toast.volume.closed.idle` | closed | 250 volume 60 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.volume.closed.music` | closed · music playing | 250 volume 60 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.volume.closed.recording` | closed · recording | 250 volume 60 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.volume.closed.agent` | closed · agent | 250 volume 60 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.volume.closed.meeting` | closed · meeting | 250 volume 60 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.volume.closed.koi` | closed · koi | 250 volume 60 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.volume.closed.leaning` | leaning | 250 volume 60 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.volume.closed.leaning+music` | leaning · music playing | 250 volume 60 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.volume.open.pond` | open: pond · music playing · all pages | 250 volume 60 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page pond)* |
| `toast.volume.open.player` | open: player · music playing · all pages | 250 volume 60 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page player)* |
| `toast.volume.open.calendar` | open: calendar · music playing · all pages | 250 volume 60 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page calendar)* |
| `toast.volume.open.tasks` | open: tasks · music playing · all pages | 250 volume 60 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page tasks)* |
| `toast.volume.open.system` | open: system · music playing · all pages | 250 volume 60 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page system)* |
| `toast.volume.open.clipboard` | open: clipboard · music playing · all pages | 250 volume 60 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page clipboard)* |
| `toast.volume.open.agents` | open: agents · music playing · all pages | 250 volume 60 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page agents)* |
| `toast.volume.open.apps` | open: apps · music playing · all pages | 250 volume 60 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page apps)* |
| `toast.volume.open.recorder` | open: recorder · music playing · all pages | 250 volume 60 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page recorder)* |
| `toast.volume.open.calendar.no-music` | open: calendar | 250 volume 60 | Same as with music: the band at the base, the page untouched. *(ends open, page calendar)* |
| `toast.volume.open.system.no-music` | open: system | 250 volume 60 | Same as with music: the band at the base, the page untouched. *(ends open, page system)* |
| `toast.volume.open.clipboard.no-music` | open: clipboard | 250 volume 60 | Same as with music: the band at the base, the page untouched. *(ends open, page clipboard)* |
| `toast.volume.teleprompter` | teleprompter | 250 volume 60 | The teleprompter keeps its height and script; the band is added at the base and the handle follows the edge. *(ends open)* |
| `toast.brightness.closed.idle` | closed | 250 brightness 70 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.brightness.closed.music` | closed · music playing | 250 brightness 70 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.brightness.closed.recording` | closed · recording | 250 brightness 70 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.brightness.closed.agent` | closed · agent | 250 brightness 70 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.brightness.closed.meeting` | closed · meeting | 250 brightness 70 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.brightness.closed.koi` | closed · koi | 250 brightness 70 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.brightness.closed.leaning` | leaning | 250 brightness 70 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.brightness.closed.leaning+music` | leaning · music playing | 250 brightness 70 | The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move. *(ends closed)* |
| `toast.brightness.open.pond` | open: pond · music playing · all pages | 250 brightness 70 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page pond)* |
| `toast.brightness.open.player` | open: player · music playing · all pages | 250 brightness 70 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page player)* |
| `toast.brightness.open.calendar` | open: calendar · music playing · all pages | 250 brightness 70 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page calendar)* |
| `toast.brightness.open.tasks` | open: tasks · music playing · all pages | 250 brightness 70 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page tasks)* |
| `toast.brightness.open.system` | open: system · music playing · all pages | 250 brightness 70 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page system)* |
| `toast.brightness.open.clipboard` | open: clipboard · music playing · all pages | 250 brightness 70 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page clipboard)* |
| `toast.brightness.open.agents` | open: agents · music playing · all pages | 250 brightness 70 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page agents)* |
| `toast.brightness.open.apps` | open: apps · music playing · all pages | 250 brightness 70 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page apps)* |
| `toast.brightness.open.recorder` | open: recorder · music playing · all pages | 250 brightness 70 | The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were. *(ends open, page recorder)* |
| `toast.brightness.open.calendar.no-music` | open: calendar | 250 brightness 70 | Same as with music: the band at the base, the page untouched. *(ends open, page calendar)* |
| `toast.brightness.open.system.no-music` | open: system | 250 brightness 70 | Same as with music: the band at the base, the page untouched. *(ends open, page system)* |
| `toast.brightness.open.clipboard.no-music` | open: clipboard | 250 brightness 70 | Same as with music: the band at the base, the page untouched. *(ends open, page clipboard)* |
| `toast.brightness.teleprompter` | teleprompter | 250 brightness 70 | The teleprompter keeps its height and script; the band is added at the base and the handle follows the edge. *(ends open)* |
| `toast.copy-back.open.clipboard.music` | open: clipboard · music playing | 250 click clip.row.#1 | Clicking a row copies it again: the same Copied toast in the base band, not a label swapped into the row. *(ends open, page clipboard)* |
| `toast.copy-back.open.clipboard.no-music` | open: clipboard | 250 click clip.row.#1 | Clicking a row copies it again: the same Copied toast in the base band, not a label swapped into the row. *(ends open, page clipboard)* |
| `toast.keepAwake.open.player.recording` | open: player · music playing · recording | 250 click ctl.keepAwake | With a recording's badge in the row: the band at the base, the row untouched. *(ends open, page player)* |
| `toast.keepAwake.off.open.player` | open: player · music playing | 250 click ctl.keepAwake; 3200 click ctl.keepAwake | On, then off three seconds later: each is its own toast in the band. *(ends open, page player)* |

### Notices (31)

| Cell | Starts | Triggers | Expected |
| --- | --- | --- | --- |
| `act.charging.closed.idle` | closed | 250 charging | The wings grow out of the notch in one resize and fold back in one. *(ends closed)* |
| `act.charging.closed.music` | closed · music playing | 250 charging | The wings grow out of the notch in one resize and fold back in one. *(ends closed)* |
| `act.charging.open.player` | open: player · music playing | 250 charging | Arriving while the island is open changes nothing on screen: no resize, no page change. *(ends open, page player)* |
| `act.lowBattery.closed.idle` | closed | 250 lowBattery | The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each. *(ends closed)* |
| `act.lowBattery.closed.music` | closed · music playing | 250 lowBattery | The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each. *(ends closed)* |
| `act.lowBattery.open.player` | open: player · music playing | 250 lowBattery | Arriving while the island is open changes nothing on screen: no resize, no page change. *(ends open, page player)* |
| `act.audioDevice.closed.idle` | closed | 250 audioDevice | The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each. *(ends closed)* |
| `act.audioDevice.closed.music` | closed · music playing | 250 audioDevice | The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each. *(ends closed)* |
| `act.audioDevice.open.player` | open: player · music playing | 250 audioDevice | Arriving while the island is open changes nothing on screen: no resize, no page change. *(ends open, page player)* |
| `act.taskDue.closed.idle` | closed | 250 taskDue | The wings grow out of the notch in one resize and fold back in one. *(ends closed)* |
| `act.taskDue.closed.music` | closed · music playing | 250 taskDue | The wings grow out of the notch in one resize and fold back in one. *(ends closed)* |
| `act.taskDue.open.player` | open: player · music playing | 250 taskDue | Arriving while the island is open changes nothing on screen: no resize, no page change. *(ends open, page player)* |
| `act.meetingReminder.closed.idle` | closed | 250 meetingReminder; 2200 Ignore | The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each. *(ends closed)* |
| `act.meetingReminder.closed.music` | closed · music playing | 250 meetingReminder; 2200 Ignore | The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each. *(ends closed)* |
| `act.meetingReminder.open.player` | open: player · music playing | 250 meetingReminder | Arriving while the island is open changes nothing on screen: no resize, no page change. *(ends open, page player)* |
| `act.agentApproval.closed.idle` | closed | 250 agentApproval; 2200 answered | The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each. *(ends closed)* |
| `act.agentApproval.closed.music` | closed · music playing | 250 agentApproval; 2200 answered | The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each. *(ends closed)* |
| `act.agentApproval.open.player` | open: player · music playing | 250 agentApproval | Arriving while the island is open changes nothing on screen: no resize, no page change. *(ends open, page player)* |
| `act.agentFinished.closed.idle` | closed | 250 agentFinished | The wings grow out of the notch in one resize and fold back in one. *(ends closed)* |
| `act.agentFinished.closed.music` | closed · music playing | 250 agentFinished | The wings grow out of the notch in one resize and fold back in one. *(ends closed)* |
| `act.agentFinished.open.player` | open: player · music playing | 250 agentFinished | Arriving while the island is open changes nothing on screen: no resize, no page change. *(ends open, page player)* |
| `act.notification.closed.idle` | closed | 250 notification | The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each. *(ends closed)* |
| `act.notification.closed.music` | closed · music playing | 250 notification | The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each. *(ends closed)* |
| `act.notification.open.player` | open: player · music playing | 250 notification | Arriving while the island is open changes nothing on screen: no resize, no page change. *(ends open, page player)* |
| `act.recorder.closed.idle` | closed | 250 recorder | The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each. *(ends closed)* |
| `act.recorder.closed.music` | closed · music playing | 250 recorder | The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each. *(ends closed)* |
| `act.recorder.open.player` | open: player · music playing | 250 recorder | Arriving while the island is open changes nothing on screen: no resize, no page change. *(ends open, page player)* |
| `act.lowBattery.closed.recording` | closed · recording | 250 lowBattery | The recording stays in the notch row while the notice hangs below it. *(ends closed)* |
| `act.charging.closed.recording` | closed · recording | 250 charging | The charging moment takes the wings and gives them back to the recording. *(ends closed)* |
| `act.lowBattery.pointer-rests` | closed | 250 lowBattery; 1400 pointer on the island; 2600 pointer away | A notice stays put under the pointer instead of opening the island, then leaves after the pointer does. *(ends closed)* |
| `act.notice-then-close.meetingReminder` | open: player · music playing | 250 meetingReminder; 900 pointer away; 3000 Ignore | A reminder that arrived while open shows as the island closes: one resize from open to the notice. *(ends closed)* |

### Interruptions (22)

| Cell | Starts | Triggers | Expected |
| --- | --- | --- | --- |
| `int.toast-during-expand.copied.idle` | closed | 250 pointer on the island; 430 copy | A toast arriving while the island is still growing joins at its base without a second bounce. *(ends open)* |
| `int.toast-during-expand.copied.music` | closed · music playing | 250 pointer on the island; 430 copy | A toast arriving while the island is still growing joins at its base without a second bounce. *(ends open)* |
| `int.toast-during-collapse.copied` | open: player · music playing | 250 pointer away; 480 copy | A toast arriving while the island is closing rides its base down to the closed island. *(ends closed)* |
| `int.toast-during-expand.volume.idle` | closed | 250 pointer on the island; 430 volume 60 | A toast arriving while the island is still growing joins at its base without a second bounce. *(ends open)* |
| `int.toast-during-expand.volume.music` | closed · music playing | 250 pointer on the island; 430 volume 60 | A toast arriving while the island is still growing joins at its base without a second bounce. *(ends open)* |
| `int.toast-during-collapse.volume` | open: player · music playing | 250 pointer away; 480 volume 60 | A toast arriving while the island is closing rides its base down to the closed island. *(ends closed)* |
| `int.two-toasts.same-kind` | closed · music playing | 250 volume 50; 450 volume 60 | Two of the same toast 200 ms apart: one band, updated in place; the island resizes once. *(ends closed)* |
| `int.two-toasts.different.open` | open: player · music playing | 250 click ctl.keepAwake; 450 copy | Two different toasts 200 ms apart: the band stays, the second replaces the first inside it. *(ends open, page player)* |
| `int.two-toasts.different.closed` | closed | 250 copy; 450 volume 60 | Two different toasts 200 ms apart on the closed island: the band stays down, no second bounce. *(ends closed)* |
| `int.pointer-leaves-while-toast-slides` | open: player · music playing | 250 click ctl.keepAwake; 340 pointer away | The pointer leaves while the toast slides in: the island closes and the toast stays at its base. *(ends closed, page player)* |
| `int.hover-while-toast-slides` | closed · music playing | 250 copy; 320 pointer on the island | Hovering as Copied slides in opens the island on the clipboard, with the toast still at the base. *(ends open, page clipboard)* |
| `int.page-switch-during-toast` | open: player · music playing | 250 click ctl.keepAwake; 480 click tab.calendar | Picking a page while a toast shows: the page changes in one move and the band stays at the new base. *(ends open, page calendar)* |
| `int.toast-during-page-switch` | open: player · music playing | 250 click tab.calendar; 330 volume 60 | A toast arriving mid page switch joins the base; the page the user picked stays. *(ends open, page calendar)* |
| `int.toast-during-notice` | closed · lowBattery | 250 volume 60 | A level changed while a notice shows: the band is added under the notice, which does not move. *(ends closed)* |
| `int.notice-during-toast` | closed | 250 copy; 700 charging | A charger connected while Copied shows: the wings grow out above the band; each leaves in its own time. *(ends closed)* |
| `int.hover-during-toast-exit` | closed · music playing | 250 volume 60; 1850 pointer on the island | Hovering as a toast leaves: the island opens in one growth while the band finishes leaving. *(ends open, page player)* |
| `int.out-and-back-in` | open: player · music playing | 250 pointer away; 330 pointer inside | Leaving and coming back within 150 ms: the island never starts to close. *(ends open, page player)* |
| `int.reopen-mid-close` | open: player · music playing | 250 pointer away; 560 pointer on the island | Coming back while the island is closing: it turns round from where it is, with no jump. *(ends open, page player)* |
| `int.close-mid-open` | closed · music playing | 250 pointer on the island; 500 pointer away | Leaving while the island is opening: it turns round from where it is. *(ends closed)* |
| `int.music-starts-during-toast` | closed | 250 copy; 700 music playing | Music starting while a toast shows: the wings grow out, the band stays where it is. *(ends closed)* |
| `int.lean-during-toast` | closed | 250 copy; 800 pointer near; 1500 pointer away | The pointer coming near while a toast shows: the island leans, the toast stays in its band. *(ends closed)* |
| `int.expand-during-notice-exit` | closed · music playing | 250 taskDue; 3300 pointer on the island | Hovering as an activity's wings fold back: one growth into the open island. *(ends open, page player)* |

### Media keys (7)

| Cell | Starts | Triggers | Expected |
| --- | --- | --- | --- |
| `keys.volume-held.closed.idle` | closed | 7 × volume from 250 to 670 (volume 40 … volume 76) | A held volume key: one band, the level following the key; the island resizes once in and once out. *(ends closed)* |
| `keys.volume-held.closed.music` | closed · music playing | 7 × volume from 250 to 670 (volume 40 … volume 76) | With music beside the notch: the band below it; the artwork and bars do not move or swap. *(ends closed)* |
| `keys.volume-held.open.player` | open: player · music playing | 7 × volume from 250 to 670 (volume 40 … volume 76) | Open on the player: the level is in the base band; the scrubber stays where it is. *(ends open, page player)* |
| `keys.volume-held.open.calendar` | open: calendar · music playing | 7 × volume from 250 to 670 (volume 40 … volume 76) | Open on another page: the same band at the base. *(ends open, page calendar)* |
| `keys.mute.closed.music` | closed · music playing | 250 volume 50; 700 mute | Mute after a level: the same toast dims in place. *(ends closed)* |
| `keys.brightness-held.closed.idle` | closed | 7 × brightness from 250 to 670 (brightness 40 … brightness 76) | A held brightness key behaves like volume: one band, one resize each way. *(ends closed)* |
| `keys.volume-then-brightness.closed.music` | closed · music playing | 250 volume 50; 650 brightness 70 | Volume then brightness: the band stays, the second level replaces the first inside it. *(ends closed)* |

### Teleprompter (7)

| Cell | Starts | Triggers | Expected |
| --- | --- | --- | --- |
| `tele.start.from-open` | open: calendar | 250 teleprompter starts | The open island widens and the script takes the page's place in one move. *(ends open)* |
| `tele.start.from-closed` | closed | 250 teleprompter starts | From closed: one growth into the teleprompter. *(ends open)* |
| `tele.stop.pointer-inside` | teleprompter | 250 teleprompter stops | Stopping with the pointer inside: back to the pages in one move. *(ends open)* |
| `tele.stop.pointer-away` | teleprompter | 240 pointer away; 250 teleprompter stops | Stopping with the pointer away: the island closes in one move. *(ends closed)* |
| `tele.drag.down` | teleprompter | 280 drag 7; 310 drag 15; 340 drag 22; 370 drag 30; 400 drag 37; 430 drag 45; 460 drag 52; 490 drag 60; 520 drag 67; 550 drag 75; 580 drag 82; 610 drag 90; 640 let go 120 | The height follows the handle directly, then settles where its momentum carries it. *(ends open)* |
| `tele.drag.up` | teleprompter | 280 drag -3; 310 drag -6; 340 drag -10; 370 drag -13; 400 drag -16; 430 drag -20; 460 drag -23; 490 drag -26; 520 drag -30; 550 drag -33; 580 drag -36; 610 drag -40; 640 let go -48 | Pushed up: follows directly, settles once. *(ends open)* |
| `tele.drag.past-max` | teleprompter | 280 drag 27; 310 drag 55; 340 drag 82; 370 drag 110; 400 drag 137; 430 drag 165; 460 drag 192; 490 drag 220; 520 drag 247; 550 drag 275; 580 drag 302; 610 drag 330; 640 let go 360 | Past the limit it resists, then settles back to the limit in one move. *(ends open)* |

### Display (3)

| Cell | Starts | Triggers | Expected |
| --- | --- | --- | --- |
| `display.closed.idle` | closed | 250 display 200×24 | Another display's notch: the island re-seats on it at once, centred, radii unchanged. *(ends closed)* |
| `display.closed.music` | closed · music playing | 250 display 200×24 | With music: the wings re-seat with the island; no second copy of the artwork. *(ends closed)* |
| `display.open.player` | open: player · music playing | 250 display 200×24 | Open: the island re-seats, the page stays. *(ends open, page player)* |

### Reduce Motion (10)

| Cell | Starts | Triggers | Expected |
| --- | --- | --- | --- |
| `rm.hover.idle` | closed · Reduce Motion | 250 pointer on the island; 1400 pointer away | Opens and closes with fades only: nothing travels. *(ends closed, page calendar)* |
| `rm.hover.music` | closed · music playing · Reduce Motion | 250 pointer on the island; 1400 pointer away | With music: the artwork changes place without travelling. *(ends closed, page player)* |
| `rm.lean` | closed · Reduce Motion | 250 pointer near; 1000 pointer away | The lean happens without a spring. *(ends closed)* |
| `rm.page.player-calendar` | open: player · music playing · Reduce Motion | 250 click tab.calendar | The page changes with a fade; the height changes at once. *(ends open, page calendar)* |
| `rm.toast.keepAwake.open.player` | open: player · music playing · Reduce Motion | 250 click ctl.keepAwake | The toast fades in at the base; no slide. *(ends open, page player)* |
| `rm.toast.copied.closed.idle` | closed · Reduce Motion | 250 copy | Closed: the band appears at once and the toast fades in it. *(ends closed)* |
| `rm.toast.volume.closed.music` | closed · music playing · Reduce Motion | 250 volume 60 | With music: the same, music untouched. *(ends closed)* |
| `rm.act.lowBattery.closed` | closed · Reduce Motion | 250 lowBattery | The notice fades in and out; nothing travels. *(ends closed)* |
| `rm.act.charging.closed` | closed · Reduce Motion | 250 charging | The charging moment appears without motion. *(ends closed)* |
| `rm.tele.start` | open: calendar · Reduce Motion | 250 teleprompter starts | The teleprompter takes the island with a fade. *(ends open)* |

### Arrivals (13)

| Cell | Starts | Triggers | Expected |
| --- | --- | --- | --- |
| `arrive.music.start` | closed | 250 music playing | The wings grow out of the notch in one resize; the artwork and bars fade in, in place. *(ends closed)* |
| `arrive.music.pause-hide` | closed · music playing | 250 music paused | Paused: the wings stay 3 s, then fold back in one resize. *(ends closed)* |
| `arrive.music.stop` | closed · music playing | 250 music off | The track ends: the wings fold back in one resize. *(ends closed)* |
| `arrive.music.start.open.calendar` | open: calendar | 250 music playing | Music starting while open on the calendar adds the player's tab; the page does not change. *(ends open, page calendar)* |
| `arrive.music.stop.open.player` | open: player · music playing | 250 music off | The track ending while open on the player: the page falls back to the first one in a single move. *(ends open)* |
| `arrive.recording.idle` | closed | 250 recording starts; 1700 recording stops | Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies. *(ends closed)* |
| `arrive.recording.music` | closed · music playing | 250 recording starts; 1700 recording stops | Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies. *(ends closed)* |
| `arrive.agent.idle` | closed | 250 agent starts; 1700 agent stops | Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies. *(ends closed)* |
| `arrive.agent.music` | closed · music playing | 250 agent starts; 1700 agent stops | Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies. *(ends closed)* |
| `arrive.meeting.idle` | closed | 250 call in 8 min; 1700 no call | Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies. *(ends closed)* |
| `arrive.meeting.music` | closed · music playing | 250 call in 8 min; 1700 no call | Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies. *(ends closed)* |
| `arrive.koi.idle` | closed | 250 koi starts; 1700 koi ends | Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies. *(ends closed)* |
| `arrive.koi.music` | closed · music playing | 250 koi starts; 1700 koi ends | Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies. *(ends closed)* |

### Relevance (7)

| Cell | Starts | Triggers | Expected |
| --- | --- | --- | --- |
| `rel.copy-then-hover` | closed · music playing | 250 copy; 3600 pointer on the island | A copy a few seconds ago: the island opens on the clipboard, though music is playing. *(ends open, page clipboard)* |
| `rel.copy-59s` | closed · music playing | 100 copied 59 s ago; 250 pointer on the island | A copy 59 s ago still opens the clipboard. *(ends open, page clipboard)* |
| `rel.copy-61s` | closed · music playing | 100 copied 61 s ago; 250 pointer on the island | A copy 61 s ago no longer does: music opens the player. *(ends open, page player)* |
| `rel.meeting-9min` | closed · music playing | 100 call in 9 min; 700 pointer on the island | A call 9 min away opens the calendar, over music. *(ends open, page calendar)* |
| `rel.meeting-11min` | closed · music playing | 100 call in 11 min; 700 pointer on the island | A call 11 min away does not: music opens the player. *(ends open, page player)* |
| `rel.copy-over-meeting` | closed · music playing · meeting | 100 copied 10 s ago; 250 pointer on the island | A fresh copy outranks a call about to start. *(ends open, page clipboard)* |
| `rel.pick-holds` | open: player · music playing | 250 click tab.system; 900 copy; 1500 call in 8 min; 2300 music paused | While the island is open, a copy, a call coming up and music pausing never change the page the user picked. *(ends open, page system)* |

<!-- cells:end -->

## What a trace is checked for

Every cell is traced on the real island at the display's refresh rate (120 fps here). Each frame
records the island's size, centre and the corner radii its shape was actually drawn with (the
shape reports them as it draws), and the frame and opacity of each named element (artwork, bars,
title, tabs, each control, the page, each toast, each notice, each set of wings), read from the
layers on screen that frame. `scripts/continuity/check.py` fails a cell if:

| Rule | Fails when |
| --- | --- |
| opacity step | what can be seen of an element (its opacity, times the part of it inside the island) changes by more than 0.35 within one 16.7 ms frame; that includes being cut off by the island's edge jumping over it |
| second copy, blink | two copies of one named element are on screen at once, or an element goes away and comes back within 400 ms inside one event (a swap instead of a travel) |
| teleport | any edge of anything visible, or of the island, moves more than 40 pt within one 16.7 ms frame |
| centre | the island's centre is more than 0.5 pt off the notch's, or its top leaves the top of the screen |
| radii | at rest (250 ms without resizing) the radii are not 6/14 closed or 14/24 open |
| page | the page at the end is not the expected one, or the page changes without a pick, an opening island or its own page going away |
| toast band, toast path | a toast is above the base band, moves sideways, does not come up through the bottom edge, or does not leave the same way |
| toast overlap | a toast covers a control or the page |
| toast missing, missing | a toast, notice or wings the cell expects never shows fully |
| still, quiet | during a toast, anything but the band changes (frame or opacity), or the island changes width; "quiet" cells allow no change at all |
| notice order | a notice's words are more than 40% there when its shape is half open (the shape must lead), or still that visible when it is half closed |
| double resize | one event (a trigger, or the model changing state) moves the island's width, its content's height or its toast band more than once; a spring's own overshoot and its momentum when retargeted do not count |
| outside | what hangs below the island (the teleprompter's handle) is inside it |
| reduce motion | with Reduce Motion on, anything travels over several frames (changes of place must be immediate; opacity may fade) |
| slow frame | a frame takes more than 25 ms during a transition (enforced on the optimised build, `--optimized`; reported only on a debug build) |
| stall | three or more frames of over 50 ms within 300 ms during a transition, on any build: the island stopped being drawn mid-move |
| keyboard | the island is closed but its panel still holds the keyboard (clicking or typing in the island takes it; closing must hand it back to the app the user is in) |
| harness | the island was not at rest when the first trigger fired (the cell's setup is wrong, not the island) |

Rules that compare a toast with the island's edge allow one frame (17 ms) either way: inside
SwiftUI a view's animated size and something placed against it can be a frame apart.

## Coverage

The full product of states and triggers is in the thousands, and most of it repeats itself. The
cells are chosen so that every *kind* of state meets every *kind* of trigger at least once, and
the cases the rules single out are run in full:

- **Opening and closing** runs from every closed state (nine, with the combinations where one
  thing outranks another), from leaning, from the charging moment and with every page on.
- **Page switches** go once round all nine pages, so each page is left once and arrived at
  once, plus the cases without music, a quick run of three picks and the clipboard's own switch.
- **Toasts** are the rule most at risk, so they run in full: all four kinds from every closed
  state, on every one of the nine pages, on three pages without music, and on the teleprompter;
  plus the in-app copy from a clipboard row, a toast turned on then off, and one with a
  recording's badge in the row.
- **Notices and wings**: all nine non-toast kinds on the bare notch, over music, and arriving
  while the island is open; plus a notice over a recording, a pointer resting on a notice, and
  a reminder that arrived while open.
- **Interruptions**: a toast during expand and during collapse, two toasts 200 ms apart (same
  kind and different kinds, closed and open), the pointer leaving while a toast slides, a hover
  while one slides, a page switch during a toast and a toast during a page switch, a toast under
  a notice and a notice over a toast, reversals mid-open and mid-close, and more.
- **Reduce Motion** repeats one cell of each kind (open and close, lean, page switch, toast
  closed and open, notice, charging, teleprompter).
- **Relevance** tests each rule on both sides of its limit (59 s and 61 s, 9 min and 11 min),
  the order between rules, and that nothing changes the page while the island stays open.

What is not in the matrix, and why: voice notes (they need the microphone and Linear); real
drags of files onto the shelf (a drag session cannot be made up without controlling the
mouse); the Settings window (not the island). Icons and colours are not something a motion
trace can judge; the filmstrips in `evidence/` are there for the eye.

## Evidence

`docs/continuity/evidence/` holds filmstrips cut from 60 fps ScreenCaptureKit films of the real
notch window (made-up data only): `<cell>.before.png` on the code before the fixes and
`<cell>.after.png` after. `docs/continuity/report.md` has the counts before and after.
