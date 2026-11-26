# Continuity report

What the suite found on the island as it was (main at `769f42c`), what was changed, and where
it stands now. The matrix and the rules are in [matrix.md](matrix.md).

Rerun everything with:

```bash
scripts/continuity.sh
```

## At the start

220 cells. **18 passed, 202 failed** ([baseline-report.md](baseline-report.md) lists every
failure with its time in the trace). A cell usually broke several rules at once:

| Rule broken | Cells |
| --- | ---: |
| opacity step (something popped in or out) | 148 |
| still (a toast moved or replaced something else) | 75 |
| toast path (did not come up through the bottom edge, or left another way) | 73 |
| toast band (above the base band, or moved sideways) | 45 |
| toast missing (no toast where there should be one) | 37 |
| toast overlap (a toast over the page or a control) | 32 |
| notice order (words arrived with the shape, or were cut by it) | 15 |
| quiet (something changed that should not have) | 10 |
| second copy | 4 |
| teleport | 4 |
| page (opened on the wrong page) | 3 |
| double resize | 1 |
| missing | 1 |
| blink | 1 |

The 18 that passed: the three display changes, the three leans, five page switches between
pages that don't show the music's artwork, the three teleprompter drags, music starting, one
Reduce Motion toast, and the two cells on the far side of a relevance limit (61 s, 11 min).

## What was wrong, and the fix for each cause

1. **Toasts took the island over.** Keep Awake and the levels were wings that replaced whatever
   was beside the notch (music, a recording, an agent, a call); a level on the open player was
   swapped into the scrubber's row and on other pages drawn over the page's bottom margin;
   Keep Awake and a copy showed nothing at all on the open island; a clipboard row swapped a
   green "Copied" label into itself. Now every toast is one thing: `ActivityCenter.toast`, shown
   by `ToastBand` in a 24 pt band at the island's base, closed or open. The island reaches down
   by the band, the toast slides up from under the bottom edge on the same spring
   (`Motion.toast`), and leaves the same way. It has a neutral grey icon. Nothing above the band
   moves, so the page and the controls are untouched, and an activity or notice already showing
   carries on. A second, different toast replaces the first inside the band without the island
   resizing. The clipboard row's copy uses the same toast.
2. **The whole island was rebuilt each time it opened or closed, when the File shelf was on.**
   `ShelfDrop` wrapped the island in an `if`, which gave it a new identity on every state
   change: the old island was torn down and cross-faded with a fresh copy, and the size jumped
   by up to 200 pt in one frame. It is one `onDrop` now, which accepts nothing while closed.
3. **Fades were cuts.** Opacity rode the sharp house curve, which spends most of its travel in
   the first two frames: a 0.09 s fade lost 60% in one frame, a 0.14 s one 44%. Fades now use
   `Motion.fade` (a soft start), and leaving content has its own token (`Motion.leave`).
4. **The artwork and bars shot across when they appeared or left during a move.** Their fade
   was an `.animation(_:value:)` on the pair, which also took over their travel; they crossed
   on a 0.16 s tween (41 pt a frame) instead of riding the island's spring. The fade is scoped
   to opacity alone.
5. **The bars floated.** Their box was as tall as the tallest bar at that instant, so the row
   bobbed up and down. They stand on a fixed baseline now.
6. **Notices arrived with their shape and were cut by it on the way out.** The words now come
   in a beat behind the shape (`Motion.Duration.noticeLead`) and are gone before it closes
   over them.
7. **A device connecting drew a second copy of the artwork and bars** while the travelling
   pair faded out. The pair now stays and rides the wings out to the notice's width.
8. **A recording's wings were two views** (one alone, one above a notice) that swapped. One
   view now, which rides out to the notice's width and back.
9. **Picking a page changed the height a beat after the page**, so a quick second pick showed
   two resizes. The height now changes in the same frame as the page.
10. **What changed under the open island was redrawn, not moved**: a track starting added its
    tab at full opacity in one frame; a track ending moved the title 98 pt in one frame. Those
    changes now happen inside one animation.
11. **A copy only steered the page while its toast was on screen** (2.5 s). The rule is 60 s
    now, measured from the copy.
12. **Reduce Motion cut content off.** Shrinking snapped the shape shut over content that was
    still fading, and several transitions were plain cuts. Content now fades, and when the
    island shrinks the shape changes in one step after the fade.
13. **Clipboard rows were redrawn** when the list changed. They travel to their new places.
14. **Two animations at once pulled things apart.** SwiftUI gives each animated value the
    animation that last touched it, so a toast arriving while the island was closing put its
    band up to 30 pt ahead of the island's edge. The island is now built so that cannot happen:
    one animated size sets both the content's frame and where the band hangs
    (`IslandFrame`), and the band's height is a separate value only a toast animates (the
    shape's `reach`).

## Now

| Build | Cells passing |
| --- | ---: |
| The installed app, `/Applications/Topsail.app` (debug build of this branch, `scripts/build.sh --direct --install`) | **220 of 220** |
| The same build run from `build/` | 220 of 220 |
| Optimised build (`scripts/continuity.sh --optimized`), where frame times count | 218 of 220 |

The two that fail on the optimised build are single slow frames, explained under Leftovers
([optimized-report.md](optimized-report.md)). Nothing else fails on any build.

The headline case, `toast.keepAwake.open.player` (music page open, click Keep Awake): the toast
slides up into the band at the island's base and the player does not move. The trace says so
(the "still" rule holds every other element to within half a point for the whole life of the
toast) and the strips show it: [before](evidence/toast.keepAwake.open.player.before.png),
[after](evidence/toast.keepAwake.open.player.after.png).

How it got there: 18 of 220 at the start; 205 after the first batch of fixes (causes 1 to 13);
220 after the second (cause 14, and the checker taught the difference between a real break and
SwiftUI's one frame of slack). The whole matrix was rerun after each batch.

To run it yourself: `scripts/continuity.sh` (everything), `scripts/continuity.sh 'toast.*'`
(a group), `scripts/continuity.sh --app /Applications/Topsail.app` (the installed copy),
`open topsail://test/toast.keepAwake.open.player` (one cell, to watch). A run needs the display
on; it wakes it and holds it on by itself, and works with the screen locked.

## Leftovers

- **Screen films.** See the note under Filmstrips: strips are in-app pictures because the
  screen was locked; the ScreenCaptureKit film is one command away once it is unlocked.
- **Two slow frames on the optimised build.** The very first time the island opens after launch,
  one frame takes 28 ms (fonts and symbols being drawn for the first time); and when the koi
  pond page comes in, one frame takes 26 ms (the pond's canvas starting). Out of 88,304 frames
  traced on that build these are the only two over 25 ms. The pond is another session's work in
  progress and was left alone; warming the open island's content once after launch would deal
  with the first, and is not done.
- **Icons.** The rule is free Pikaicons only. The repository has no Pikaicons yet (everything
  on main is an SF Symbol), so the toast's icons are SF Symbols too, in neutral grey. The switch
  is its own piece of work and nothing here stands in its way.
- **"Saved".** A saved recording keeps its card (it has Show in Finder and Open on it), so it is
  a notice, not a toast. If a bare "Saved" toast is wanted instead, it is one more `ActivityKind`
  marked as a toast.
- **A notice that arrives while the island is open** is not shown until the island closes
  (unchanged; the suite checks that nothing moves when it arrives). Whether notices should grow
  out of the open island is a design question, not a continuity bug.
- **Music beside a call, and under other pages.** The picks from the island studies (the music
  sharing the wings with a call's countdown; a music strip under the calendar or clipboard) are
  not built. Until they are, music gives way with a fade, which the rules allow.
- **Not in the matrix:** voice notes (microphone and Linear), real file drags onto the shelf,
  the Settings window.
- **One frame of slack.** Rules that compare a toast with the island's edge allow 17 ms either
  way, because inside SwiftUI an animated size and something placed against it can be a frame
  apart. Real breaks at the start were 30 to 70 pt and lasted the whole toast.
- **An undershoot nobody can see.** When two things beside the notch end in the same instant
  (seen once, when a test ended an agent and its request together), the island's spring dips
  below the notch's own size before settling. On a Mac with a notch that is hidden behind the
  notch itself.

## Filmstrips

Before and after strips for 18 cells: the ten the checker ranked worst at the start, the
headline case, and one for each other cause. Each strip has two rows: every frame for a quarter
second from the first trigger, and the whole cell at even steps.

| Cell | Before | After | What to look at |
| --- | --- | --- | --- |
| `toast.keepAwake.open.player` | [before](evidence/toast.keepAwake.open.player.before.png) | [after](evidence/toast.keepAwake.open.player.after.png) | **The headline case.** Music page open, click Keep Awake. Before: no toast at all, only the cup turning amber. After: the island reaches down at its base and "Keep Awake On" slides up into the band; the player does not move. |
| `toast.keepAwake.closed.music` | [before](evidence/toast.keepAwake.closed.music.before.png) | [after](evidence/toast.keepAwake.closed.music.after.png) | Before: the toast took the wings, and the artwork and bars vanished. After: the band under the music, which stays. |
| `toast.copied.closed.music` | [before](evidence/toast.copied.closed.music.before.png) | [after](evidence/toast.copied.closed.music.after.png) | Before: green tick, "Copied to clipboard", fading out in place. After: grey tick, "Copied" and a glimpse of the copy, up through the bottom edge and back. |
| `toast.volume.open.player` | [before](evidence/toast.volume.open.player.before.png) | [after](evidence/toast.volume.open.player.after.png) | Before: the level was swapped into the scrubber's row. After: the scrubber stays; the level is in the band. |
| `toast.brightness.open.player` | [before](evidence/toast.brightness.open.player.before.png) | [after](evidence/toast.brightness.open.player.after.png) | The same for brightness. |
| `toast.copy-back.open.clipboard.music` | [before](evidence/toast.copy-back.open.clipboard.music.before.png) | [after](evidence/toast.copy-back.open.clipboard.music.after.png) | A clipboard row clicked. Before: a green "Copied" label swapped into the row. After: the same toast as every other copy. |
| `hover.all-pages.music` | [before](evidence/hover.all-pages.music.before.png) | [after](evidence/hover.all-pages.music.after.png) | With the File shelf on. Before: the island was rebuilt on opening (it jumps to full size in one frame and two copies cross-fade). After: it grows. |
| `hover.music-paused` | [before](evidence/hover.music-paused.before.png) | [after](evidence/hover.music-paused.after.png) | Closing with paused music. Before: the artwork shot across on a quick tween. After: it fades where it is as the island closes. |
| `arrive.music.stop.open.player` | [before](evidence/arrive.music.stop.open.player.before.png) | [after](evidence/arrive.music.stop.open.player.after.png) | The track ends while the player is open. Before: the title jumped 98 pt and the tab vanished in one frame. After: the page keeps its last track while it leaves and the tabs close up in one move. |
| `act.lowBattery.closed.music` | [before](evidence/act.lowBattery.closed.music.before.png) | [after](evidence/act.lowBattery.closed.music.after.png) | A notice over music. Before: words arrive with the shape and are cut by it as it closes. After: the shape leads, the words follow, and leave first. |
| `keys.volume-then-brightness.closed.music` | [before](evidence/keys.volume-then-brightness.closed.music.before.png) | [after](evidence/keys.volume-then-brightness.closed.music.after.png) | Volume then brightness, 400 ms apart. Before: wings and glyphs swapping, the island resizing each time. After: one band, the second level replaces the first inside it. |
| `int.pointer-leaves-while-toast-slides` | [before](evidence/int.pointer-leaves-while-toast-slides.before.png) | [after](evidence/int.pointer-leaves-while-toast-slides.after.png) | The pointer leaves as the toast arrives. After: the toast stays on the island's base all the way down. |
| `int.toast-during-page-switch` | [before](evidence/int.toast-during-page-switch.before.png) | [after](evidence/int.toast-during-page-switch.after.png) | A level changed mid page switch. After: the band joins the base of the page being switched to. |
| `toast.keepAwake.closed.agent` | [before](evidence/toast.keepAwake.closed.agent.before.png) | [after](evidence/toast.keepAwake.closed.agent.after.png) | Over an agent's wings. Before: the toast replaced them. After: they stay. |
| `toast.keepAwake.closed.recording` | [before](evidence/toast.keepAwake.closed.recording.before.png) | [after](evidence/toast.keepAwake.closed.recording.after.png) | Over a recording's wings: the same. |
| `toast.volume.closed.agent` | [before](evidence/toast.volume.closed.agent.before.png) | [after](evidence/toast.volume.closed.agent.after.png) | A level over an agent's wings. |
| `toast.brightness.closed.agent` | [before](evidence/toast.brightness.closed.agent.before.png) | [after](evidence/toast.brightness.closed.agent.after.png) | Brightness over an agent's wings. |
| `toast.brightness.closed.recording` | [before](evidence/toast.brightness.closed.recording.before.png) | [after](evidence/toast.brightness.closed.recording.after.png) | Brightness over a recording. |

**These strips are not screen films.** The brief asked for 60 fps ScreenCaptureKit films of the
screen. The film tool is written and wired in (`scripts/continuity/film.swift`, `--film`), and
it does capture Topsail's window; but the Mac's screen locked at 02:34 while its owner was away,
and ScreenCaptureKit delivers only about five frames a second of a window behind the lock
screen (most frames come back marked idle or suspended). So the strips here are pictures the
app takes of its own window's layers at the same exact times (`--snap`): true positions, sizes
and opacities, without blur effects. With the screen unlocked, this makes the real films of the
fixed build:

```bash
scripts/continuity.sh --no-build --label after --film all 'toast.keepAwake.open.player,toast.keepAwake.closed.music,hover.all-pages.music'
```

(For "before" films, build commit `5ae9b09`, which is the suite on the unchanged island, and pass
its app with `--app`.)
