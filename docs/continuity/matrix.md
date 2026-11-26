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
<!-- cells:end -->

## What a trace is checked for

Every cell is traced on the real island at the display's refresh rate (120 fps here): the
island's size, centre and the corner radii its shape was actually drawn with, and the frame and
opacity of each named element (artwork, bars, title, tabs, each control, the page, each toast,
each notice, each set of wings), read from the layers on screen that frame. `scripts/continuity/check.py`
fails a cell if:

| Rule | Fails when |
| --- | --- |
| opacity step | an element's opacity changes by more than 0.35 within one 16.7 ms frame |
| second copy, blink | two copies of one named element are on screen at once, or an element goes away and comes back within 400 ms (a swap instead of a travel) |
| teleport | any edge of anything visible moves more than 40 pt within one 16.7 ms frame |
| centre | the island's centre is more than 0.5 pt off the notch's, or its top leaves the top of the screen |
| radii | at rest (250 ms without resizing) the radii are not 6/14 closed or 14/24 open |
| page | the page at the end is not the expected one, or the page changes without a pick, an opening island or its own page going away |
| toast band, toast path | a toast is above the base band, moves sideways, does not come up through the bottom edge, or does not leave the same way |
| toast overlap | a toast covers a control or the page |
| toast missing, missing | a toast, notice or wings the cell expects never shows fully |
| still, quiet | during a toast, anything but the band changes (frame or opacity), or the island changes width; "quiet" cells allow no change at all |
| double resize | one event (a trigger, or the model changing state) moves the island's width or height more than once; a spring's own overshoot does not count |
| reduce motion | with Reduce Motion on, anything travels over several frames (changes of place must be immediate; opacity may fade) |
| slow frame | a frame takes more than 25 ms during a transition (enforced on the optimised build, `--optimized`; reported only on a debug build) |
| harness | the island was not at rest when the first trigger fired (the cell's setup is wrong, not the island) |

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
