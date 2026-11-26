# Continuity run: 218 of 220 cells pass

Build: release. Failing cells: 2. Failures in all: 2.

| Rule broken | Cells |
| --- | ---: |
| slow frame | 2 |

## The 2 worst cells

- `hover.idle`: slow frame
- `page.recorder-pond`: slow frame

## Every failing cell

### `hover.idle` (closed)

Expected: Leans, opens on calendar in one growth, then closes in one; what is beside the notch travels or fades, never pops.

- **slow frame** at 520 ms: 1 frame(s) over 25 ms during a transition (worst 28 ms)

### `page.recorder-pond` (open: recorder · music playing · all pages)

Expected: Height and page change together in one move; the selection pill travels; the island stays centred.

- **slow frame** at 315 ms: 1 frame(s) over 25 ms during a transition (worst 26 ms)

