# Continuity report

What the suite found on the island as it was (main at `769f42c`), what was changed, and where
it stands now. The matrix and the rules are in [matrix.md](matrix.md).

Rerun everything with:

```bash
scripts/continuity.sh
```

## At the start

220 cells. **17 passed, 203 failed** ([baseline-report.md](baseline-report.md) lists every
failure with its time in the trace).

| Rule broken | Cells |
| --- | ---: |
| opacity step (something popped in or out) | 152 |
| still (a toast moved or replaced something else) | 75 |
| toast path (did not come up through the bottom edge, or left another way) | 73 |
| toast band (above the base band, or moved sideways) | 45 |
| toast missing (no toast where there should be one) | 37 |
| toast overlap (a toast over the page or a control) | 32 |
| notice order (words arrived with the shape, or were cut by it) | 15 |
| quiet (something changed that should not have) | 10 |
| second copy | 4 |
| teleport | 4 |
| blink | 4 |
| page (opened on the wrong page) | 3 |
| double resize | 1 |
| missing | 1 |

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

## Now

RESULTS_PLACEHOLDER

## Leftovers

LEFTOVERS_PLACEHOLDER

## Filmstrips

FILMS_PLACEHOLDER
