# Continuity run: 18 of 220 cells pass

Build: debug. Failing cells: 202. Failures in all: 976.
Cells with a slow frame (not counted on a debug build): 8.

| Rule broken | Cells |
| --- | ---: |
| opacity step | 148 |
| still | 75 |
| toast path | 73 |
| toast band | 45 |
| toast missing | 37 |
| toast overlap | 32 |
| notice order | 15 |
| quiet | 10 |
| second copy | 4 |
| teleport | 4 |
| page | 3 |
| double resize | 1 |
| missing | 1 |
| blink | 1 |

## The 10 worst cells

- `keys.volume-then-brightness.closed.music`: blink; opacity step; second copy; still; toast band; toast missing; toast path
- `toast.volume.open.player`: opacity step; still; toast band; toast overlap; toast path
- `toast.brightness.open.player`: opacity step; still; toast band; toast overlap; toast path
- `int.pointer-leaves-while-toast-slides`: opacity step; toast band; toast overlap; toast path
- `int.toast-during-page-switch`: opacity step; toast band; toast overlap; toast path
- `toast.brightness.closed.agent`: opacity step; still; toast band; toast path
- `toast.brightness.closed.recording`: opacity step; still; toast band; toast path
- `toast.keepAwake.closed.agent`: opacity step; still; toast band; toast path
- `toast.keepAwake.closed.recording`: opacity step; still; toast band; toast path
- `toast.volume.closed.agent`: opacity step; still; toast band; toast path

## Every failing cell

### `act.agentApproval.closed.idle` (closed)

Expected: The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each.

- **notice order** at 420 ms: notice.agentApproval was 52% there when the shape was half open: the shape must lead
- **notice order** at 2345 ms: notice.agentApproval was still 57% there when the shape was half closed
- **double resize** at 2211 ms: one event resized the island's height more than once (-178 pt, then +27 pt)

### `act.agentApproval.closed.music` (closed · music playing)

Expected: The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each.

- **opacity step** at 295 ms: art changed opacity by 0.83 in one frame
- **opacity step** at 295 ms: bars changed opacity by 0.87 in one frame
- **notice order** at 422 ms: notice.agentApproval was 54% there when the shape was half open: the shape must lead
- **notice order** at 2361 ms: notice.agentApproval was still 50% there when the shape was half closed

### `act.agentApproval.open.player` (open: player · music playing)

Expected: Arriving while the island is open changes nothing on screen: no resize, no page change.

- **quiet** at 465 ms: bars changed (frame or opacity) though nothing should have changed

### `act.agentFinished.closed.idle` (closed)

Expected: The wings grow out of the notch in one resize and fold back in one.

- **opacity step** at 3453 ms: wings.agentFinished changed opacity by 0.59 in one frame

### `act.agentFinished.closed.music` (closed · music playing)

Expected: The wings grow out of the notch in one resize and fold back in one.

- **opacity step** at 292 ms: art changed opacity by 0.80 in one frame
- **opacity step** at 292 ms: bars changed opacity by 0.84 in one frame
- **opacity step** at 3325 ms: wings.agentFinished changed opacity by 0.60 in one frame

### `act.agentFinished.open.player` (open: player · music playing)

Expected: Arriving while the island is open changes nothing on screen: no resize, no page change.

- **quiet** at 310 ms: bars changed (frame or opacity) though nothing should have changed

### `act.audioDevice.closed.idle` (closed)

Expected: The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each.

- **notice order** at 428 ms: notice.audioDevice was 52% there when the shape was half open: the shape must lead
- **notice order** at 4619 ms: notice.audioDevice was still 50% there when the shape was half closed

### `act.audioDevice.closed.music` (closed · music playing)

Expected: The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each.

- **notice order** at 422 ms: notice.audioDevice was 52% there when the shape was half open: the shape must lead
- **notice order** at 4622 ms: notice.audioDevice was still 50% there when the shape was half closed

### `act.audioDevice.open.player` (open: player · music playing)

Expected: Arriving while the island is open changes nothing on screen: no resize, no page change.

- **quiet** at 287 ms: bars changed (frame or opacity) though nothing should have changed

### `act.charging.closed.idle` (closed)

Expected: The wings grow out of the notch in one resize and fold back in one.

- **opacity step** at 3304 ms: wings.charging changed opacity by 0.61 in one frame

### `act.charging.closed.music` (closed · music playing)

Expected: The wings grow out of the notch in one resize and fold back in one.

- **opacity step** at 294 ms: art changed opacity by 0.80 in one frame
- **opacity step** at 294 ms: bars changed opacity by 0.84 in one frame
- **opacity step** at 3302 ms: wings.charging changed opacity by 0.59 in one frame

### `act.charging.closed.recording` (closed · recording)

Expected: The charging moment takes the wings and gives them back to the recording.

- **opacity step** at 298 ms: wings.recording changed opacity by 0.62 in one frame
- **opacity step** at 3306 ms: wings.charging changed opacity by 0.61 in one frame
- **opacity step** at 3315 ms: wings.recording changed opacity by 0.54 in one frame

### `act.charging.open.player` (open: player · music playing)

Expected: Arriving while the island is open changes nothing on screen: no resize, no page change.

- **quiet** at 301 ms: bars changed (frame or opacity) though nothing should have changed

### `act.lowBattery.closed.idle` (closed)

Expected: The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each.

- **notice order** at 424 ms: notice.lowBattery was 54% there when the shape was half open: the shape must lead
- **notice order** at 6457 ms: notice.lowBattery was still 50% there when the shape was half closed

### `act.lowBattery.closed.music` (closed · music playing)

Expected: The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each.

- **notice order** at 419 ms: notice.lowBattery was 52% there when the shape was half open: the shape must lead
- **notice order** at 6428 ms: notice.lowBattery was still 50% there when the shape was half closed

### `act.lowBattery.closed.recording` (closed · recording)

Expected: The recording stays in the notch row while the notice hangs below it.

- **opacity step** at 292 ms: wings.recording changed opacity by 0.62 in one frame
- **opacity step** at 6308 ms: wings.recording changed opacity by 0.60 in one frame
- **opacity step** at 6317 ms: wings.recording changed opacity by 0.54 in one frame
- **second copy** at 275 ms: two copies of wings.recording were on screen at once
- **notice order** at 417 ms: notice.lowBattery was 52% there when the shape was half open: the shape must lead
- **notice order** at 6433 ms: notice.lowBattery was still 50% there when the shape was half closed

### `act.lowBattery.open.player` (open: player · music playing)

Expected: Arriving while the island is open changes nothing on screen: no resize, no page change.

- **quiet** at 313 ms: bars changed (frame or opacity) though nothing should have changed

### `act.lowBattery.pointer-rests` (closed)

Expected: A notice stays put under the pointer instead of opening the island, then leaves after the pointer does.

- **notice order** at 424 ms: notice.lowBattery was 54% there when the shape was half open: the shape must lead
- **notice order** at 4782 ms: notice.lowBattery was still 50% there when the shape was half closed

### `act.meetingReminder.closed.idle` (closed)

Expected: The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each.

- **notice order** at 433 ms: notice.meetingReminder was 54% there when the shape was half open: the shape must lead
- **notice order** at 2366 ms: notice.meetingReminder was still 50% there when the shape was half closed

### `act.meetingReminder.closed.music` (closed · music playing)

Expected: The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each.

- **missing** at 3981 ms: notice.meetingReminder never showed

### `act.meetingReminder.open.player` (open: player · music playing)

Expected: Arriving while the island is open changes nothing on screen: no resize, no page change.

- **quiet** at 285 ms: bars changed (frame or opacity) though nothing should have changed

### `act.notice-then-close.meetingReminder` (open: player · music playing)

Expected: A reminder that arrived while open shows as the island closes: one resize from open to the notice.

- **opacity step** at 1119 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 1119 ms: bars changed opacity by 0.40 in one frame
- **opacity step** at 1111 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 1111 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 1111 ms: page.player changed opacity by 0.43 in one frame
- **opacity step** at 1111 ms: player.controls changed opacity by 0.43 in one frame
- **opacity step** at 1111 ms: player.scrubber changed opacity by 0.43 in one frame
- **opacity step** at 1111 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 1111 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1111 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 1111 ms: tab.player changed opacity by 0.43 in one frame
- **opacity step** at 1111 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 1111 ms: tabs changed opacity by 0.43 in one frame
- **opacity step** at 1111 ms: title changed opacity by 0.43 in one frame
- **notice order** at 1269 ms: notice.meetingReminder was 66% there when the shape was half open: the shape must lead
- **notice order** at 3161 ms: notice.meetingReminder was still 50% there when the shape was half closed

### `act.notification.closed.idle` (closed)

Expected: The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each.

- **notice order** at 451 ms: notice.notification was 54% there when the shape was half open: the shape must lead
- **notice order** at 6718 ms: notice.notification was still 50% there when the shape was half closed

### `act.notification.closed.music` (closed · music playing)

Expected: The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each.

- **notice order** at 421 ms: notice.notification was 54% there when the shape was half open: the shape must lead
- **notice order** at 6721 ms: notice.notification was still 50% there when the shape was half closed

### `act.notification.open.player` (open: player · music playing)

Expected: Arriving while the island is open changes nothing on screen: no resize, no page change.

- **quiet** at 702 ms: bars changed (frame or opacity) though nothing should have changed

### `act.recorder.closed.idle` (closed)

Expected: The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each.

- **notice order** at 494 ms: notice.recorder was 52% there when the shape was half open: the shape must lead
- **notice order** at 6719 ms: notice.recorder was still 50% there when the shape was half closed

### `act.recorder.closed.music` (closed · music playing)

Expected: The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each.

- **opacity step** at 297 ms: art changed opacity by 0.82 in one frame
- **opacity step** at 297 ms: bars changed opacity by 0.87 in one frame
- **notice order** at 422 ms: notice.recorder was 54% there when the shape was half open: the shape must lead
- **notice order** at 6463 ms: notice.recorder was still 50% there when the shape was half closed

### `act.recorder.open.player` (open: player · music playing)

Expected: Arriving while the island is open changes nothing on screen: no resize, no page change.

- **quiet** at 261 ms: bars changed (frame or opacity) though nothing should have changed

### `act.taskDue.closed.idle` (closed)

Expected: The wings grow out of the notch in one resize and fold back in one.

- **opacity step** at 3448 ms: wings.taskDue changed opacity by 0.62 in one frame

### `act.taskDue.closed.music` (closed · music playing)

Expected: The wings grow out of the notch in one resize and fold back in one.

- **opacity step** at 294 ms: art changed opacity by 0.79 in one frame
- **opacity step** at 294 ms: bars changed opacity by 0.83 in one frame
- **opacity step** at 3443 ms: wings.taskDue changed opacity by 0.60 in one frame

### `act.taskDue.open.player` (open: player · music playing)

Expected: Arriving while the island is open changes nothing on screen: no resize, no page change.

- **quiet** at 340 ms: bars changed (frame or opacity) though nothing should have changed

### `arrive.agent.idle` (closed)

Expected: Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies.

- **opacity step** at 1747 ms: wings.agent changed opacity by 0.59 in one frame

### `arrive.agent.music` (closed · music playing)

Expected: Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies.

- **opacity step** at 314 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 314 ms: bars changed opacity by 0.40 in one frame
- **opacity step** at 1747 ms: wings.agent changed opacity by 0.62 in one frame

### `arrive.koi.idle` (closed)

Expected: Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies.

- **opacity step** at 1738 ms: wings.koi changed opacity by 0.60 in one frame

### `arrive.koi.music` (closed · music playing)

Expected: Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies.

- **opacity step** at 1751 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 1751 ms: bars changed opacity by 0.40 in one frame
- **opacity step** at 1734 ms: wings.koi changed opacity by 0.60 in one frame

### `arrive.meeting.idle` (closed)

Expected: Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies.

- **opacity step** at 1744 ms: wings.meeting changed opacity by 0.61 in one frame

### `arrive.meeting.music` (closed · music playing)

Expected: Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies.

- **opacity step** at 300 ms: art changed opacity by 0.79 in one frame
- **opacity step** at 300 ms: bars changed opacity by 0.83 in one frame
- **opacity step** at 1742 ms: wings.meeting changed opacity by 0.61 in one frame

### `arrive.music.pause-hide` (closed · music playing)

Expected: Paused: the wings stay 3 s, then fold back in one resize.

- **opacity step** at 3458 ms: art changed opacity by 0.39 in one frame
- **opacity step** at 3458 ms: bars changed opacity by 0.39 in one frame

### `arrive.music.start.open.calendar` (open: calendar)

Expected: Music starting while open on the calendar adds the player's tab; the page does not change.

- **opacity step** at 269 ms: tab.player changed opacity by 1.00 in one frame

### `arrive.music.stop` (closed · music playing)

Expected: The track ends: the wings fold back in one resize.

- **opacity step** at 313 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 313 ms: bars changed opacity by 0.40 in one frame

### `arrive.music.stop.open.player` (open: player · music playing)

Expected: The track ending while open on the player: the page falls back to the first one in a single move.

- **opacity step** at 306 ms: art changed opacity by 0.39 in one frame
- **opacity step** at 306 ms: bars changed opacity by 0.39 in one frame
- **opacity step** at 272 ms: tab.player changed opacity by 1.00 in one frame
- **teleport** at 272 ms: title moved 98 pt in one frame

### `arrive.recording.idle` (closed)

Expected: Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies.

- **opacity step** at 1736 ms: wings.recording changed opacity by 0.63 in one frame

### `arrive.recording.music` (closed · music playing)

Expected: Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies.

- **opacity step** at 307 ms: art changed opacity by 0.44 in one frame
- **opacity step** at 307 ms: bars changed opacity by 0.42 in one frame
- **opacity step** at 1740 ms: wings.recording changed opacity by 0.61 in one frame

### `hover.agent` (closed · agent)

Expected: Leans, opens on calendar in one growth, then closes in one; what is beside the notch travels or fades, never pops.

- **opacity step** at 542 ms: wings.agent changed opacity by 0.46 in one frame
- **opacity step** at 1901 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 1901 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 1901 ms: page.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1901 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 1901 ms: tab.agents changed opacity by 0.43 in one frame
- **opacity step** at 1901 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1901 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 1901 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 1901 ms: tabs changed opacity by 0.43 in one frame
- **opacity step** at 1901 ms: wings.agent changed opacity by 0.56 in one frame

### `hover.all-pages.idle` (closed · all pages)

Expected: With nothing going on and the pond on, the island opens on the pond.

- **opacity step** at 1909 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 1909 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 1918 ms: pond changed opacity by 0.40 in one frame
- **opacity step** at 1909 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 1909 ms: tab.agents changed opacity by 0.43 in one frame
- **opacity step** at 1909 ms: tab.apps changed opacity by 0.43 in one frame
- **opacity step** at 1909 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1909 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 1909 ms: tab.pond changed opacity by 0.43 in one frame
- **opacity step** at 1909 ms: tab.recorder changed opacity by 0.43 in one frame
- **opacity step** at 1909 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 1909 ms: tab.tasks changed opacity by 0.43 in one frame
- **opacity step** at 1909 ms: tabs changed opacity by 0.43 in one frame
- **second copy** at 651 ms: two copies of ctl.keepAwake were on screen at once
- **second copy** at 651 ms: two copies of page were on screen at once
- **second copy** at 584 ms: two copies of pond were on screen at once
- **second copy** at 651 ms: two copies of rowbuttons were on screen at once
- **second copy** at 651 ms: two copies of tab.agents were on screen at once
- **second copy** at 651 ms: two copies of tab.apps were on screen at once
- **second copy** at 651 ms: two copies of tab.calendar were on screen at once
- **second copy** at 651 ms: two copies of tab.clipboard were on screen at once
- **second copy** at 651 ms: two copies of tab.pond were on screen at once
- **second copy** at 651 ms: two copies of tab.recorder were on screen at once
- **second copy** at 651 ms: two copies of tab.system were on screen at once
- **second copy** at 651 ms: two copies of tab.tasks were on screen at once
- **second copy** at 651 ms: two copies of tabs were on screen at once
- **teleport** at 548 ms: the island's edge moved 203 pt in one frame

### `hover.all-pages.music` (closed · music playing · all pages)

Expected: With every page on (nine tabs), the island still opens on the player and closes in one move each.

- **opacity step** at 1912 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: page.player changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: player.controls changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: player.scrubber changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: tab.agents changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: tab.apps changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: tab.player changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: tab.pond changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: tab.recorder changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: tab.tasks changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: tabs changed opacity by 0.43 in one frame
- **opacity step** at 1912 ms: title changed opacity by 0.43 in one frame
- **second copy** at 587 ms: two copies of art were on screen at once
- **second copy** at 587 ms: two copies of bars were on screen at once
- **second copy** at 645 ms: two copies of ctl.keepAwake were on screen at once
- **second copy** at 645 ms: two copies of page were on screen at once
- **second copy** at 645 ms: two copies of page.player were on screen at once
- **second copy** at 645 ms: two copies of player.controls were on screen at once
- **second copy** at 645 ms: two copies of player.scrubber were on screen at once
- **second copy** at 645 ms: two copies of rowbuttons were on screen at once
- **second copy** at 645 ms: two copies of tab.agents were on screen at once
- **second copy** at 645 ms: two copies of tab.apps were on screen at once
- **second copy** at 645 ms: two copies of tab.calendar were on screen at once
- **second copy** at 645 ms: two copies of tab.clipboard were on screen at once
- **second copy** at 645 ms: two copies of tab.player were on screen at once
- **second copy** at 645 ms: two copies of tab.pond were on screen at once
- **second copy** at 645 ms: two copies of tab.recorder were on screen at once
- **second copy** at 645 ms: two copies of tab.system were on screen at once
- **second copy** at 645 ms: two copies of tab.tasks were on screen at once
- **second copy** at 645 ms: two copies of tabs were on screen at once
- **second copy** at 645 ms: two copies of title were on screen at once
- **teleport** at 545 ms: the island's edge moved 173 pt in one frame

### `hover.charging` (closed · charging)

Expected: The charging moment gives way to the open island in one growth; closing returns to the notch.

- **opacity step** at 398 ms: wings.charging changed opacity by 0.61 in one frame
- **opacity step** at 1715 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 1715 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 1715 ms: page.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1715 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 1715 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1715 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 1715 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 1715 ms: tabs changed opacity by 0.43 in one frame
- **opacity step** at 1748 ms: wings.charging changed opacity by 0.58 in one frame

### `hover.from-leaning.idle` (leaning)

Expected: From leaning, resting on the island opens it in one growth; leaving closes it.

- **opacity step** at 1712 ms: ctl.keepAwake changed opacity by 0.44 in one frame
- **opacity step** at 1712 ms: page changed opacity by 0.44 in one frame
- **opacity step** at 1712 ms: page.calendar changed opacity by 0.44 in one frame
- **opacity step** at 1712 ms: rowbuttons changed opacity by 0.44 in one frame
- **opacity step** at 1712 ms: tab.calendar changed opacity by 0.44 in one frame
- **opacity step** at 1712 ms: tab.clipboard changed opacity by 0.44 in one frame
- **opacity step** at 1712 ms: tab.system changed opacity by 0.44 in one frame
- **opacity step** at 1712 ms: tabs changed opacity by 0.44 in one frame

### `hover.from-leaning.music` (leaning · music playing)

Expected: From leaning, resting on the island opens it in one growth; leaving closes it.

- **opacity step** at 1706 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 1706 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 1706 ms: page.player changed opacity by 0.43 in one frame
- **opacity step** at 1706 ms: player.controls changed opacity by 0.43 in one frame
- **opacity step** at 1706 ms: player.scrubber changed opacity by 0.43 in one frame
- **opacity step** at 1706 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 1706 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1706 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 1706 ms: tab.player changed opacity by 0.43 in one frame
- **opacity step** at 1706 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 1706 ms: tabs changed opacity by 0.43 in one frame
- **opacity step** at 1706 ms: title changed opacity by 0.43 in one frame

### `hover.idle` (closed)

Expected: Leans, opens on calendar in one growth, then closes in one; what is beside the notch travels or fades, never pops.

- **opacity step** at 1919 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 1919 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 1919 ms: page.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1919 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 1919 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1919 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 1919 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 1919 ms: tabs changed opacity by 0.43 in one frame

### `hover.koi` (closed · koi)

Expected: Leans, opens on calendar in one growth, then closes in one; what is beside the notch travels or fades, never pops.

- **opacity step** at 547 ms: wings.koi changed opacity by 0.59 in one frame
- **opacity step** at 1914 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 1914 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 1914 ms: page.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1914 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 1914 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1914 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 1914 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 1914 ms: tabs changed opacity by 0.43 in one frame

### `hover.meeting` (closed · meeting)

Expected: Leans, opens on calendar in one growth, then closes in one; what is beside the notch travels or fades, never pops.

- **opacity step** at 544 ms: wings.meeting changed opacity by 0.61 in one frame
- **opacity step** at 1911 ms: ctl.keepAwake changed opacity by 0.44 in one frame
- **opacity step** at 1911 ms: page changed opacity by 0.44 in one frame
- **opacity step** at 1911 ms: page.calendar changed opacity by 0.44 in one frame
- **opacity step** at 1911 ms: rowbuttons changed opacity by 0.44 in one frame
- **opacity step** at 1911 ms: tab.calendar changed opacity by 0.44 in one frame
- **opacity step** at 1911 ms: tab.clipboard changed opacity by 0.44 in one frame
- **opacity step** at 1911 ms: tab.system changed opacity by 0.44 in one frame
- **opacity step** at 1911 ms: tabs changed opacity by 0.44 in one frame
- **opacity step** at 1903 ms: wings.meeting changed opacity by 0.58 in one frame

### `hover.music+agent` (closed · music playing · agent)

Expected: Leans, opens on player in one growth, then closes in one; what is beside the notch travels or fades, never pops.

- **opacity step** at 1911 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 1911 ms: bars changed opacity by 0.40 in one frame
- **opacity step** at 545 ms: wings.agent changed opacity by 0.61 in one frame
- **opacity step** at 1903 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 1903 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 1903 ms: page.player changed opacity by 0.43 in one frame
- **opacity step** at 1903 ms: player.controls changed opacity by 0.43 in one frame
- **opacity step** at 1903 ms: player.scrubber changed opacity by 0.43 in one frame
- **opacity step** at 1903 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 1903 ms: tab.agents changed opacity by 0.43 in one frame
- **opacity step** at 1903 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1903 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 1903 ms: tab.player changed opacity by 0.43 in one frame
- **opacity step** at 1903 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 1903 ms: tabs changed opacity by 0.43 in one frame
- **opacity step** at 1903 ms: title changed opacity by 0.43 in one frame
- **opacity step** at 1903 ms: wings.agent changed opacity by 0.56 in one frame

### `hover.music+meeting` (closed · music playing · meeting)

Expected: Leans, opens on calendar in one growth, then closes in one; what is beside the notch travels or fades, never pops.

- **opacity step** at 540 ms: wings.meeting changed opacity by 0.60 in one frame
- **opacity step** at 1907 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 1907 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 1907 ms: page.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1907 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 1907 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1907 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 1907 ms: tab.player changed opacity by 0.43 in one frame
- **opacity step** at 1907 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 1907 ms: tabs changed opacity by 0.43 in one frame
- **opacity step** at 1907 ms: wings.meeting changed opacity by 0.56 in one frame

### `hover.music+recording` (closed · music playing · recording)

Expected: Leans, opens on recorder in one growth, then closes in one; what is beside the notch travels or fades, never pops.

- **opacity step** at 546 ms: wings.recording changed opacity by 0.61 in one frame
- **opacity step** at 1913 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 1913 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 1913 ms: page.recorder changed opacity by 0.43 in one frame
- **opacity step** at 1913 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 1913 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1913 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 1913 ms: tab.player changed opacity by 0.43 in one frame
- **opacity step** at 1913 ms: tab.recorder changed opacity by 0.43 in one frame
- **opacity step** at 1913 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 1913 ms: tabs changed opacity by 0.43 in one frame
- **opacity step** at 1913 ms: wings.recording changed opacity by 0.57 in one frame

### `hover.music-paused` (closed · music paused)

Expected: Paused music still opens on the player; the artwork travels both ways.

- **opacity step** at 1713 ms: art changed opacity by 0.39 in one frame
- **opacity step** at 1713 ms: bars changed opacity by 0.39 in one frame
- **opacity step** at 1704 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 1704 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 1704 ms: page.player changed opacity by 0.43 in one frame
- **opacity step** at 1704 ms: player.controls changed opacity by 0.43 in one frame
- **opacity step** at 1704 ms: player.scrubber changed opacity by 0.43 in one frame
- **opacity step** at 1704 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 1704 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1704 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 1704 ms: tab.player changed opacity by 0.43 in one frame
- **opacity step** at 1704 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 1704 ms: tabs changed opacity by 0.43 in one frame
- **opacity step** at 1704 ms: title changed opacity by 0.43 in one frame
- **teleport** at 1713 ms: art moved 41 pt in one frame
- **teleport** at 1713 ms: bars moved 42 pt in one frame

### `hover.music` (closed · music playing)

Expected: Leans, opens on player in one growth, then closes in one; what is beside the notch travels or fades, never pops.

- **opacity step** at 1902 ms: ctl.keepAwake changed opacity by 0.44 in one frame
- **opacity step** at 1902 ms: page changed opacity by 0.44 in one frame
- **opacity step** at 1902 ms: page.player changed opacity by 0.44 in one frame
- **opacity step** at 1902 ms: player.controls changed opacity by 0.44 in one frame
- **opacity step** at 1902 ms: player.scrubber changed opacity by 0.44 in one frame
- **opacity step** at 1902 ms: rowbuttons changed opacity by 0.44 in one frame
- **opacity step** at 1902 ms: tab.calendar changed opacity by 0.44 in one frame
- **opacity step** at 1902 ms: tab.clipboard changed opacity by 0.44 in one frame
- **opacity step** at 1902 ms: tab.player changed opacity by 0.44 in one frame
- **opacity step** at 1902 ms: tab.system changed opacity by 0.44 in one frame
- **opacity step** at 1902 ms: tabs changed opacity by 0.44 in one frame
- **opacity step** at 1902 ms: title changed opacity by 0.44 in one frame

### `hover.recording` (closed · recording)

Expected: Leans, opens on recorder in one growth, then closes in one; what is beside the notch travels or fades, never pops.

- **opacity step** at 554 ms: wings.recording changed opacity by 0.63 in one frame
- **opacity step** at 1904 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 1904 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 1904 ms: page.recorder changed opacity by 0.43 in one frame
- **opacity step** at 1904 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 1904 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 1904 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 1904 ms: tab.recorder changed opacity by 0.43 in one frame
- **opacity step** at 1904 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 1904 ms: tabs changed opacity by 0.43 in one frame
- **opacity step** at 1904 ms: wings.recording changed opacity by 0.56 in one frame

### `int.close-mid-open` (closed · music playing)

Expected: Leaving while the island is opening: it turns round from where it is.

- **opacity step** at 715 ms: ctl.keepAwake changed opacity by 0.40 in one frame
- **opacity step** at 715 ms: page changed opacity by 0.40 in one frame
- **opacity step** at 715 ms: page.player changed opacity by 0.40 in one frame
- **opacity step** at 715 ms: player.controls changed opacity by 0.40 in one frame
- **opacity step** at 715 ms: player.scrubber changed opacity by 0.40 in one frame
- **opacity step** at 715 ms: rowbuttons changed opacity by 0.40 in one frame
- **opacity step** at 715 ms: tab.calendar changed opacity by 0.40 in one frame
- **opacity step** at 715 ms: tab.clipboard changed opacity by 0.40 in one frame
- **opacity step** at 715 ms: tab.player changed opacity by 0.40 in one frame
- **opacity step** at 715 ms: tab.system changed opacity by 0.40 in one frame
- **opacity step** at 715 ms: tabs changed opacity by 0.40 in one frame
- **opacity step** at 715 ms: title changed opacity by 0.40 in one frame

### `int.expand-during-notice-exit` (closed · music playing)

Expected: Hovering as an activity's wings fold back: one growth into the open island.

- **opacity step** at 298 ms: art changed opacity by 0.77 in one frame
- **opacity step** at 298 ms: bars changed opacity by 0.81 in one frame
- **opacity step** at 3348 ms: wings.taskDue changed opacity by 0.60 in one frame

### `int.hover-during-toast-exit` (closed · music playing)

Expected: Hovering as a toast leaves: the island opens in one growth while the band finishes leaving.

- **opacity step** at 305 ms: bars changed opacity by 0.40 in one frame
- **opacity step** at 1996 ms: toast.volume changed opacity by 0.56 in one frame
- **toast band** at 363 ms: toast.volume was 1 pt above the base band
- **toast path** at 1971 ms: toast.volume did not leave the way it came (down, through the bottom edge)

### `int.hover-while-toast-slides` (closed · music playing)

Expected: Hovering as Copied slides in opens the island on the clipboard, with the toast still at the base.

- **opacity step** at 306 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 306 ms: bars changed opacity by 0.40 in one frame
- **opacity step** at 472 ms: toast.copied changed opacity by 0.61 in one frame
- **toast band** at 448 ms: toast.copied was 2 pt above the base band
- **toast missing** at 4497 ms: the copied toast never showed fully inside the island

### `int.lean-during-toast` (closed)

Expected: The pointer coming near while a toast shows: the island leans, the toast stays in its band.

- **opacity step** at 2917 ms: toast.copied changed opacity by 0.61 in one frame
- **toast path** at 2909 ms: toast.copied did not leave the way it came (down, through the bottom edge)

### `int.music-starts-during-toast` (closed)

Expected: Music starting while a toast shows: the wings grow out, the band stays where it is.

- **opacity step** at 2905 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 2905 ms: bars changed opacity by 0.40 in one frame
- **opacity step** at 2888 ms: toast.copied changed opacity by 0.60 in one frame
- **toast path** at 2880 ms: toast.copied did not leave the way it came (down, through the bottom edge)

### `int.notice-during-toast` (closed)

Expected: A charger connected while Copied shows: the wings grow out above the band; each leaves in its own time.

- **opacity step** at 2921 ms: toast.copied changed opacity by 0.61 in one frame
- **toast path** at 2912 ms: toast.copied did not leave the way it came (down, through the bottom edge)

### `int.out-and-back-in` (open: player · music playing)

Expected: Leaving and coming back within 150 ms: the island never starts to close.

- **quiet** at 667 ms: bars changed (frame or opacity) though nothing should have changed

### `int.page-switch-during-toast` (open: player · music playing)

Expected: Picking a page while a toast shows: the page changes in one move and the band stays at the new base.

- **opacity step** at 572 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 572 ms: bars changed opacity by 0.40 in one frame
- **toast missing** at 3397 ms: the keepAwake toast never showed fully inside the island

### `int.pointer-leaves-while-toast-slides` (open: player · music playing)

Expected: The pointer leaves while the toast slides in: the island closes and the toast stays at its base.

- **opacity step** at 1920 ms: art changed opacity by 0.41 in one frame
- **opacity step** at 1920 ms: bars changed opacity by 0.41 in one frame
- **opacity step** at 553 ms: ctl.keepAwake changed opacity by 0.44 in one frame
- **opacity step** at 553 ms: page changed opacity by 0.44 in one frame
- **opacity step** at 553 ms: page.player changed opacity by 0.44 in one frame
- **opacity step** at 553 ms: player.controls changed opacity by 0.44 in one frame
- **opacity step** at 553 ms: player.scrubber changed opacity by 0.44 in one frame
- **opacity step** at 553 ms: rowbuttons changed opacity by 0.44 in one frame
- **opacity step** at 553 ms: tab.calendar changed opacity by 0.44 in one frame
- **opacity step** at 553 ms: tab.clipboard changed opacity by 0.44 in one frame
- **opacity step** at 553 ms: tab.player changed opacity by 0.44 in one frame
- **opacity step** at 553 ms: tab.system changed opacity by 0.44 in one frame
- **opacity step** at 553 ms: tabs changed opacity by 0.44 in one frame
- **opacity step** at 553 ms: title changed opacity by 0.44 in one frame
- **opacity step** at 1903 ms: toast.keepAwake changed opacity by 0.61 in one frame
- **toast band** at 528 ms: toast.keepAwake was 130 pt above the base band
- **toast overlap** at 528 ms: toast.keepAwake covered ctl.keepAwake
- **toast path** at 1895 ms: toast.keepAwake did not leave the way it came (down, through the bottom edge)

### `int.reopen-mid-close` (open: player · music playing)

Expected: Coming back while the island is closing: it turns round from where it is, with no jump.

- **opacity step** at 450 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 450 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 450 ms: page.player changed opacity by 0.43 in one frame
- **opacity step** at 450 ms: player.controls changed opacity by 0.43 in one frame
- **opacity step** at 450 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 450 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 450 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 450 ms: tab.player changed opacity by 0.43 in one frame
- **opacity step** at 450 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 450 ms: tabs changed opacity by 0.43 in one frame
- **opacity step** at 450 ms: title changed opacity by 0.43 in one frame

### `int.toast-during-collapse.copied` (open: player · music playing)

Expected: A toast arriving while the island is closing rides its base down to the closed island.

- **opacity step** at 538 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 538 ms: bars changed opacity by 0.40 in one frame
- **opacity step** at 455 ms: ctl.keepAwake changed opacity by 0.41 in one frame
- **opacity step** at 455 ms: page changed opacity by 0.41 in one frame
- **opacity step** at 455 ms: page.player changed opacity by 0.41 in one frame
- **opacity step** at 455 ms: player.controls changed opacity by 0.41 in one frame
- **opacity step** at 455 ms: player.scrubber changed opacity by 0.41 in one frame
- **opacity step** at 455 ms: rowbuttons changed opacity by 0.41 in one frame
- **opacity step** at 455 ms: tab.calendar changed opacity by 0.41 in one frame
- **opacity step** at 455 ms: tab.clipboard changed opacity by 0.41 in one frame
- **opacity step** at 455 ms: tab.player changed opacity by 0.41 in one frame
- **opacity step** at 455 ms: tab.system changed opacity by 0.41 in one frame
- **opacity step** at 455 ms: tabs changed opacity by 0.41 in one frame
- **opacity step** at 455 ms: title changed opacity by 0.41 in one frame
- **opacity step** at 3155 ms: toast.copied changed opacity by 0.60 in one frame
- **toast band** at 513 ms: toast.copied was 91 pt above the base band
- **toast path** at 3147 ms: toast.copied did not leave the way it came (down, through the bottom edge)

### `int.toast-during-collapse.volume` (open: player · music playing)

Expected: A toast arriving while the island is closing rides its base down to the closed island.

- **opacity step** at 2122 ms: bars changed opacity by 0.40 in one frame
- **opacity step** at 463 ms: ctl.keepAwake changed opacity by 0.43 in one frame
- **opacity step** at 463 ms: page changed opacity by 0.43 in one frame
- **opacity step** at 463 ms: page.player changed opacity by 0.43 in one frame
- **opacity step** at 463 ms: player.controls changed opacity by 0.43 in one frame
- **opacity step** at 463 ms: player.scrubber changed opacity by 0.43 in one frame
- **opacity step** at 463 ms: rowbuttons changed opacity by 0.43 in one frame
- **opacity step** at 463 ms: tab.calendar changed opacity by 0.43 in one frame
- **opacity step** at 463 ms: tab.clipboard changed opacity by 0.43 in one frame
- **opacity step** at 463 ms: tab.player changed opacity by 0.43 in one frame
- **opacity step** at 463 ms: tab.system changed opacity by 0.43 in one frame
- **opacity step** at 463 ms: tabs changed opacity by 0.43 in one frame
- **opacity step** at 463 ms: title changed opacity by 0.43 in one frame
- **toast band** at 538 ms: toast.volume was 103 pt above the base band

### `int.toast-during-expand.copied.idle` (closed)

Expected: A toast arriving while the island is still growing joins at its base without a second bounce.

- **toast missing** at 4451 ms: the copied toast never showed fully inside the island

### `int.toast-during-expand.copied.music` (closed · music playing)

Expected: A toast arriving while the island is still growing joins at its base without a second bounce.

- **toast missing** at 4473 ms: the copied toast never showed fully inside the island

### `int.toast-during-expand.volume.idle` (closed)

Expected: A toast arriving while the island is still growing joins at its base without a second bounce.

- **opacity step** at 2068 ms: toast.volume changed opacity by 0.40 in one frame
- **toast overlap** at 609 ms: toast.volume covered page
- **toast path** at 460 ms: toast.volume did not slide up from the bottom edge

### `int.toast-during-expand.volume.music` (closed · music playing)

Expected: A toast arriving while the island is still growing joins at its base without a second bounce.

- **toast overlap** at 482 ms: toast.volume covered page
- **toast band** at 507 ms: toast.volume was 3 pt above the base band
- **toast path** at 482 ms: toast.volume did not slide up from the bottom edge

### `int.toast-during-notice` (closed · lowBattery)

Expected: A level changed while a notice shows: the band is added under the notice, which does not move.

- **opacity step** at 1810 ms: toast.volume changed opacity by 0.60 in one frame
- **toast band** at 276 ms: toast.volume was 56 pt above the base band
- **toast path** at 1801 ms: toast.volume did not leave the way it came (down, through the bottom edge)
- **notice order** at 2443 ms: notice.lowBattery was 47% there when the shape was half open: the shape must lead

### `int.toast-during-page-switch` (open: player · music playing)

Expected: A toast arriving mid page switch joins the base; the page the user picked stays.

- **opacity step** at 345 ms: art changed opacity by 0.42 in one frame
- **opacity step** at 345 ms: bars changed opacity by 0.42 in one frame
- **opacity step** at 345 ms: page.player changed opacity by 0.38 in one frame
- **opacity step** at 345 ms: player.controls changed opacity by 0.38 in one frame
- **opacity step** at 345 ms: player.scrubber changed opacity by 0.38 in one frame
- **opacity step** at 345 ms: title changed opacity by 0.38 in one frame
- **opacity step** at 1970 ms: toast.volume changed opacity by 0.40 in one frame
- **toast band** at 362 ms: toast.volume was 28 pt above the base band
- **toast overlap** at 362 ms: toast.volume covered page
- **toast path** at 362 ms: toast.volume did not slide up from the bottom edge

### `int.two-toasts.different.closed` (closed)

Expected: Two different toasts 200 ms apart on the closed island: the band stays down, no second bounce.

- **opacity step** at 488 ms: toast.copied changed opacity by 0.58 in one frame
- **opacity step** at 2070 ms: toast.volume changed opacity by 0.60 in one frame
- **toast path** at 479 ms: toast.copied did not leave the way it came (down, through the bottom edge)
- **toast band** at 479 ms: toast.volume was 24 pt above the base band
- **toast path** at 2062 ms: toast.volume did not leave the way it came (down, through the bottom edge)
- **toast missing** at 4387 ms: the copied toast never showed fully inside the island

### `int.two-toasts.different.open` (open: player · music playing)

Expected: Two different toasts 200 ms apart: the band stays, the second replaces the first inside it.

- **toast missing** at 4605 ms: the keepAwake toast never showed fully inside the island
- **toast missing** at 4605 ms: the copied toast never showed fully inside the island

### `int.two-toasts.same-kind` (closed · music playing)

Expected: Two of the same toast 200 ms apart: one band, updated in place; the island resizes once.

- **opacity step** at 2090 ms: bars changed opacity by 0.43 in one frame
- **toast band** at 366 ms: toast.volume was 1 pt above the base band

### `keys.brightness-held.closed.idle` (closed)

Expected: A held brightness key behaves like volume: one band, one resize each way.

- **opacity step** at 2287 ms: toast.brightness changed opacity by 0.60 in one frame
- **toast band** at 279 ms: toast.brightness was 4 pt above the base band
- **toast path** at 2279 ms: toast.brightness did not leave the way it came (down, through the bottom edge)
- **still** at 279 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 279 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 279 ms: the island changed width by +1.3 pt

### `keys.mute.closed.music` (closed · music playing)

Expected: Mute after a level: the same toast dims in place.

- **opacity step** at 2299 ms: bars changed opacity by 0.40 in one frame
- **toast band** at 366 ms: toast.volume was 1 pt above the base band
- **still** at 282 ms: bars changed (frame or opacity) while only a toast was showing

### `keys.volume-held.closed.idle` (closed)

Expected: A held volume key: one band, the level following the key; the island resizes once in and once out.

- **opacity step** at 2222 ms: toast.volume changed opacity by 0.60 in one frame
- **toast band** at 280 ms: toast.volume was 4 pt above the base band
- **toast path** at 2213 ms: toast.volume did not leave the way it came (down, through the bottom edge)
- **still** at 280 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 280 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 280 ms: the island changed width by +1.3 pt

### `keys.volume-held.closed.music` (closed · music playing)

Expected: With music beside the notch: the band below it; the artwork and bars do not move or swap.

- **opacity step** at 301 ms: bars changed opacity by 0.41 in one frame
- **toast band** at 359 ms: toast.volume was 1 pt above the base band
- **still** at 276 ms: bars changed (frame or opacity) while only a toast was showing

### `keys.volume-held.open.calendar` (open: calendar · music playing)

Expected: Open on another page: the same band at the base.

- **opacity step** at 300 ms: toast.volume changed opacity by 0.42 in one frame
- **toast overlap** at 275 ms: toast.volume covered page
- **toast path** at 275 ms: toast.volume did not slide up from the bottom edge
- **still** at 383 ms: bars changed (frame or opacity) while only a toast was showing

### `keys.volume-held.open.player` (open: player · music playing)

Expected: Open on the player: the level is in the base band; the scrubber stays where it is.

- **toast band** at 275 ms: toast.volume was 36 pt above the base band
- **toast overlap** at 275 ms: toast.volume covered page
- **toast path** at 275 ms: toast.volume did not slide up from the bottom edge
- **still** at 442 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 275 ms: player.scrubber changed (frame or opacity) while only a toast was showing
- **still** at 2192 ms: player.scrubber appeared

### `keys.volume-then-brightness.closed.music` (closed · music playing)

Expected: Volume then brightness: the band stays, the second level replaces the first inside it.

- **opacity step** at 300 ms: bars changed opacity by 0.40 in one frame
- **opacity step** at 658 ms: toast.volume changed opacity by 1.00 in one frame
- **opacity step** at 658 ms: toast.brightness changed opacity by 1.00 in one frame
- **second copy** at 700 ms: two copies of toast.brightness were on screen at once
- **blink** at 767 ms: toast.brightness went away and came back 8 ms later
- **toast band** at 658 ms: toast.brightness was 8 pt above the base band
- **toast band** at 700 ms: toast.brightness was 6 pt above the base band
- **toast band** at 358 ms: toast.volume was 1 pt above the base band
- **toast path** at 650 ms: toast.volume vanished at full opacity
- **toast missing** at 3583 ms: the volume toast never showed fully inside the island
- **still** at 275 ms: bars changed (frame or opacity) while only a toast was showing

### `page.agents-apps` (open: agents · music playing · all pages)

Expected: Height and page change together in one move; the selection pill travels; the island stays centred.

- **opacity step** at 347 ms: page.agents changed opacity by 0.37 in one frame

### `page.apps-recorder` (open: apps · music playing · all pages)

Expected: Height and page change together in one move; the selection pill travels; the island stays centred.

- **opacity step** at 355 ms: page.apps changed opacity by 0.37 in one frame

### `page.clipboard-agents` (open: clipboard · music playing · all pages)

Expected: Height and page change together in one move; the selection pill travels; the island stays centred.

- **opacity step** at 352 ms: clip.row0 changed opacity by 0.36 in one frame
- **opacity step** at 352 ms: clip.row1 changed opacity by 0.36 in one frame
- **opacity step** at 352 ms: clip.row2 changed opacity by 0.36 in one frame
- **opacity step** at 352 ms: page.clipboard changed opacity by 0.36 in one frame

### `page.clipboard-shelf` (open: clipboard · music playing · all pages)

Expected: The Clipboard / Shelf switch changes the page's height in one move each way.

- **opacity step** at 304 ms: clip.row0 changed opacity by 0.36 in one frame
- **opacity step** at 304 ms: clip.row1 changed opacity by 0.36 in one frame
- **opacity step** at 304 ms: clip.row2 changed opacity by 0.36 in one frame

### `page.no-music.clipboard-calendar` (open: clipboard)

Expected: Height and page change together in one move.

- **opacity step** at 344 ms: clip.row0 changed opacity by 0.36 in one frame
- **opacity step** at 344 ms: clip.row1 changed opacity by 0.36 in one frame
- **opacity step** at 344 ms: clip.row2 changed opacity by 0.36 in one frame
- **opacity step** at 344 ms: page.clipboard changed opacity by 0.36 in one frame

### `page.player-calendar-player` (open: player · music playing)

Expected: Away from the player and back: the artwork and bars leave and return without a second copy.

- **opacity step** at 1095 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 1095 ms: bars changed opacity by 0.40 in one frame

### `page.player-calendar` (open: player · music playing · all pages)

Expected: Height and page change together in one move; the selection pill travels; the island stays centred.

- **opacity step** at 349 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 349 ms: bars changed opacity by 0.40 in one frame

### `page.pond-player` (open: pond · music playing · all pages)

Expected: Height and page change together in one move; the selection pill travels; the island stays centred.

- **opacity step** at 346 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 346 ms: bars changed opacity by 0.40 in one frame
- **opacity step** at 346 ms: pond changed opacity by 0.41 in one frame

### `page.quick-three` (open: player · music playing)

Expected: Three picks 150 ms apart: the island retargets each time and ends on the last, with no jump.

- **opacity step** at 347 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 347 ms: bars changed opacity by 0.40 in one frame

### `page.recorder-pond` (open: recorder · music playing · all pages)

Expected: Height and page change together in one move; the selection pill travels; the island stays centred.

- **opacity step** at 364 ms: pond changed opacity by 0.40 in one frame

### `rel.copy-59s` (closed · music playing)

Expected: A copy 59 s ago still opens the clipboard.

- **page** at 1629 ms: ended on the player page, expected clipboard

### `rel.copy-over-meeting` (closed · music playing · meeting)

Expected: A fresh copy outranks a call about to start.

- **opacity step** at 384 ms: wings.meeting changed opacity by 0.60 in one frame
- **page** at 1634 ms: ended on the calendar page, expected clipboard

### `rel.copy-then-hover` (closed · music playing)

Expected: A copy a few seconds ago: the island opens on the clipboard, though music is playing.

- **opacity step** at 301 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 301 ms: bars changed opacity by 0.40 in one frame
- **opacity step** at 2918 ms: toast.copied changed opacity by 0.61 in one frame
- **page** at 4960 ms: ended on the player page, expected clipboard
- **toast path** at 2910 ms: toast.copied did not leave the way it came (down, through the bottom edge)

### `rel.meeting-9min` (closed · music playing)

Expected: A call 9 min away opens the calendar, over music.

- **opacity step** at 154 ms: art changed opacity by 0.78 in one frame
- **opacity step** at 154 ms: bars changed opacity by 0.81 in one frame
- **opacity step** at 845 ms: wings.meeting changed opacity by 0.63 in one frame

### `rel.pick-holds` (open: player · music playing)

Expected: While the island is open, a copy, a call coming up and music pausing never change the page the user picked.

- **opacity step** at 354 ms: art changed opacity by 0.40 in one frame
- **opacity step** at 354 ms: bars changed opacity by 0.40 in one frame
- **opacity step** at 354 ms: page.player changed opacity by 0.36 in one frame
- **opacity step** at 354 ms: player.controls changed opacity by 0.36 in one frame
- **opacity step** at 354 ms: player.scrubber changed opacity by 0.36 in one frame
- **opacity step** at 354 ms: title changed opacity by 0.36 in one frame
- **toast missing** at 5804 ms: the copied toast never showed fully inside the island

### `rm.act.charging.closed` (closed · Reduce Motion)

Expected: The charging moment appears without motion.

- **opacity step** at 3419 ms: wings.charging was cut off by the island's edge (0.77 of it in one frame)

### `rm.act.lowBattery.closed` (closed · Reduce Motion)

Expected: The notice fades in and out; nothing travels.

- **opacity step** at 6572 ms: notice.lowBattery was cut off by the island's edge (0.82 of it in one frame)

### `rm.hover.idle` (closed · Reduce Motion)

Expected: Opens and closes with fades only: nothing travels.

- **opacity step** at 1567 ms: ctl.keepAwake was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 1567 ms: page was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 1567 ms: page.calendar was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 1567 ms: rowbuttons was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 1567 ms: tab.calendar was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 1567 ms: tab.clipboard was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 1567 ms: tab.system was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 1567 ms: tabs was cut off by the island's edge (1.00 of it in one frame)

### `rm.hover.music` (closed · music playing · Reduce Motion)

Expected: With music: the artwork changes place without travelling.

- **opacity step** at 1573 ms: ctl.keepAwake was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 1573 ms: page was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 1573 ms: page.player was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 1573 ms: player.controls was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 1573 ms: player.scrubber was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 1573 ms: rowbuttons was cut off by the island's edge (0.67 of it in one frame)
- **opacity step** at 1573 ms: tab.calendar was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 1615 ms: tab.clipboard changed opacity by 0.41 in one frame
- **opacity step** at 1573 ms: tab.player was cut off by the island's edge (1.00 of it in one frame)
- **opacity step** at 407 ms: tab.system changed opacity by 0.40 in one frame
- **opacity step** at 1573 ms: tabs was cut off by the island's edge (0.59 of it in one frame)
- **opacity step** at 1573 ms: title was cut off by the island's edge (1.00 of it in one frame)

### `rm.page.player-calendar` (open: player · music playing · Reduce Motion)

Expected: The page changes with a fade; the height changes at once.

- **opacity step** at 300 ms: art changed opacity by 1.00 in one frame
- **opacity step** at 300 ms: bars changed opacity by 1.00 in one frame
- **opacity step** at 300 ms: page.player changed opacity by 1.00 in one frame
- **opacity step** at 300 ms: player.controls changed opacity by 1.00 in one frame
- **opacity step** at 300 ms: player.scrubber changed opacity by 1.00 in one frame
- **opacity step** at 300 ms: title changed opacity by 1.00 in one frame
- **opacity step** at 300 ms: page.calendar changed opacity by 1.00 in one frame

### `rm.tele.start` (open: calendar · Reduce Motion)

Expected: The teleprompter takes the island with a fade.

- **opacity step** at 313 ms: ctl.keepAwake changed opacity by 0.44 in one frame
- **opacity step** at 313 ms: page changed opacity by 0.44 in one frame
- **opacity step** at 313 ms: page.calendar changed opacity by 0.44 in one frame
- **opacity step** at 313 ms: rowbuttons changed opacity by 0.44 in one frame
- **opacity step** at 313 ms: tab.calendar changed opacity by 0.44 in one frame
- **opacity step** at 313 ms: tab.clipboard changed opacity by 0.44 in one frame
- **opacity step** at 313 ms: tab.system changed opacity by 0.44 in one frame
- **opacity step** at 313 ms: tabs changed opacity by 0.44 in one frame
- **opacity step** at 313 ms: tele.handle changed opacity by 0.44 in one frame
- **opacity step** at 272 ms: tele.script changed opacity by 1.00 in one frame

### `rm.toast.keepAwake.open.player` (open: player · music playing · Reduce Motion)

Expected: The toast fades in at the base; no slide.

- **toast missing** at 3187 ms: the keepAwake toast never showed fully inside the island

### `rm.toast.volume.closed.music` (closed · music playing · Reduce Motion)

Expected: With music: the same, music untouched.

- **opacity step** at 264 ms: bars changed opacity by 1.00 in one frame
- **opacity step** at 264 ms: toast.volume changed opacity by 1.00 in one frame
- **toast band** at 264 ms: toast.volume was 8 pt above the base band

### `tele.start.from-closed` (closed)

Expected: From closed: one growth into the teleprompter.

- **opacity step** at 311 ms: tele.handle changed opacity by 0.40 in one frame

### `tele.start.from-open` (open: calendar)

Expected: The open island widens and the script takes the page's place in one move.

- **opacity step** at 325 ms: ctl.keepAwake changed opacity by 0.44 in one frame
- **opacity step** at 325 ms: page changed opacity by 0.44 in one frame
- **opacity step** at 325 ms: page.calendar changed opacity by 0.44 in one frame
- **opacity step** at 325 ms: rowbuttons changed opacity by 0.44 in one frame
- **opacity step** at 325 ms: tab.calendar changed opacity by 0.44 in one frame
- **opacity step** at 325 ms: tab.clipboard changed opacity by 0.44 in one frame
- **opacity step** at 325 ms: tab.system changed opacity by 0.44 in one frame
- **opacity step** at 325 ms: tabs changed opacity by 0.44 in one frame
- **opacity step** at 325 ms: tele.handle changed opacity by 0.40 in one frame

### `tele.stop.pointer-away` (teleprompter)

Expected: Stopping with the pointer away: the island closes in one move.

- **opacity step** at 311 ms: tele.handle changed opacity by 0.40 in one frame
- **opacity step** at 294 ms: tele.script changed opacity by 0.60 in one frame

### `tele.stop.pointer-inside` (teleprompter)

Expected: Stopping with the pointer inside: back to the pages in one move.

- **opacity step** at 315 ms: tele.handle changed opacity by 0.39 in one frame
- **opacity step** at 306 ms: tele.script changed opacity by 0.60 in one frame

### `toast.brightness.closed.agent` (closed · agent)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 289 ms: wings.agent changed opacity by 0.68 in one frame
- **opacity step** at 1872 ms: toast.brightness changed opacity by 0.61 in one frame
- **opacity step** at 1881 ms: wings.agent changed opacity by 0.55 in one frame
- **toast band** at 281 ms: toast.brightness was 4 pt above the base band
- **toast path** at 1864 ms: toast.brightness did not leave the way it came (down, through the bottom edge)
- **still** at 289 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 289 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 281 ms: wings.agent changed (frame or opacity) while only a toast was showing
- **still** at 1847 ms: wings.agent appeared
- **still** at 281 ms: the island changed width by +0.8 pt

### `toast.brightness.closed.idle` (closed)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 1836 ms: toast.brightness changed opacity by 0.59 in one frame
- **toast band** at 277 ms: toast.brightness was 4 pt above the base band
- **toast path** at 1827 ms: toast.brightness did not leave the way it came (down, through the bottom edge)
- **still** at 277 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 277 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 277 ms: the island changed width by +1.3 pt

### `toast.brightness.closed.koi` (closed · koi)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 285 ms: wings.koi changed opacity by 0.61 in one frame
- **opacity step** at 1835 ms: toast.brightness changed opacity by 0.60 in one frame
- **toast band** at 277 ms: toast.brightness was 4 pt above the base band
- **toast path** at 1827 ms: toast.brightness did not leave the way it came (down, through the bottom edge)
- **still** at 285 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 285 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 277 ms: the island changed width by +0.6 pt

### `toast.brightness.closed.leaning+music` (leaning · music playing)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 303 ms: bars changed opacity by 0.42 in one frame
- **toast band** at 303 ms: toast.brightness was 1 pt above the base band
- **still** at 320 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 278 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 303 ms: the island changed width by -0.5 pt

### `toast.brightness.closed.leaning` (leaning)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 1873 ms: toast.brightness changed opacity by 0.60 in one frame
- **toast band** at 281 ms: toast.brightness was 7 pt above the base band
- **toast path** at 1865 ms: toast.brightness did not leave the way it came (down, through the bottom edge)
- **still** at 281 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 281 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 281 ms: the island changed width by +1.3 pt

### `toast.brightness.closed.meeting` (closed · meeting)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 288 ms: wings.meeting changed opacity by 0.60 in one frame
- **opacity step** at 1813 ms: toast.brightness changed opacity by 0.60 in one frame
- **opacity step** at 1822 ms: wings.meeting changed opacity by 0.56 in one frame
- **toast band** at 280 ms: toast.brightness was 4 pt above the base band
- **toast path** at 1805 ms: toast.brightness did not leave the way it came (down, through the bottom edge)
- **still** at 280 ms: wings.meeting changed (frame or opacity) while only a toast was showing
- **still** at 1788 ms: wings.meeting appeared

### `toast.brightness.closed.music` (closed · music playing)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 303 ms: bars changed opacity by 0.41 in one frame
- **toast band** at 353 ms: toast.brightness was 1 pt above the base band
- **still** at 278 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.brightness.closed.recording` (closed · recording)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 291 ms: wings.recording changed opacity by 0.60 in one frame
- **opacity step** at 1875 ms: toast.brightness changed opacity by 0.60 in one frame
- **opacity step** at 1883 ms: wings.recording changed opacity by 0.56 in one frame
- **toast band** at 283 ms: toast.brightness was 4 pt above the base band
- **toast path** at 1866 ms: toast.brightness did not leave the way it came (down, through the bottom edge)
- **still** at 291 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 291 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 283 ms: wings.recording changed (frame or opacity) while only a toast was showing
- **still** at 1850 ms: wings.recording appeared
- **still** at 283 ms: the island changed width by +0.6 pt

### `toast.brightness.open.agents` (open: agents · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 301 ms: toast.brightness changed opacity by 0.40 in one frame
- **toast overlap** at 276 ms: toast.brightness covered page
- **toast path** at 276 ms: toast.brightness did not slide up from the bottom edge
- **still** at 468 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.brightness.open.apps` (open: apps · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 304 ms: toast.brightness changed opacity by 0.41 in one frame
- **toast overlap** at 279 ms: toast.brightness covered page
- **toast path** at 279 ms: toast.brightness did not slide up from the bottom edge
- **still** at 571 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.brightness.open.calendar` (open: calendar · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 301 ms: toast.brightness changed opacity by 0.40 in one frame
- **toast overlap** at 276 ms: toast.brightness covered page
- **toast path** at 276 ms: toast.brightness did not slide up from the bottom edge
- **still** at 359 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.brightness.open.calendar.no-music` (open: calendar)

Expected: Same as with music: the band at the base, the page untouched.

- **opacity step** at 306 ms: toast.brightness changed opacity by 0.40 in one frame
- **toast overlap** at 281 ms: toast.brightness covered page
- **toast path** at 281 ms: toast.brightness did not slide up from the bottom edge

### `toast.brightness.open.clipboard` (open: clipboard · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 1889 ms: toast.brightness changed opacity by 0.41 in one frame
- **toast overlap** at 281 ms: toast.brightness covered clip.row2
- **toast path** at 281 ms: toast.brightness did not slide up from the bottom edge
- **still** at 889 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.brightness.open.clipboard.no-music` (open: clipboard)

Expected: Same as with music: the band at the base, the page untouched.

- **opacity step** at 1888 ms: toast.brightness changed opacity by 0.39 in one frame
- **toast overlap** at 280 ms: toast.brightness covered clip.row2
- **toast path** at 280 ms: toast.brightness did not slide up from the bottom edge

### `toast.brightness.open.player` (open: player · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 304 ms: player.scrubber changed opacity by 0.36 in one frame
- **toast band** at 279 ms: toast.brightness was 36 pt above the base band
- **toast overlap** at 279 ms: toast.brightness covered page
- **toast path** at 279 ms: toast.brightness did not slide up from the bottom edge
- **still** at 337 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 279 ms: player.scrubber changed (frame or opacity) while only a toast was showing
- **still** at 1846 ms: player.scrubber appeared

### `toast.brightness.open.pond` (open: pond · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 307 ms: toast.brightness changed opacity by 0.42 in one frame
- **toast overlap** at 282 ms: toast.brightness covered page
- **toast path** at 282 ms: toast.brightness did not slide up from the bottom edge
- **still** at 241 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.brightness.open.recorder` (open: recorder · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 1887 ms: toast.brightness changed opacity by 0.41 in one frame
- **toast overlap** at 279 ms: toast.brightness covered page
- **toast path** at 279 ms: toast.brightness did not slide up from the bottom edge
- **still** at 304 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.brightness.open.system` (open: system · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 302 ms: toast.brightness changed opacity by 0.40 in one frame
- **toast overlap** at 277 ms: toast.brightness covered page
- **toast path** at 277 ms: toast.brightness did not slide up from the bottom edge
- **still** at 402 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.brightness.open.system.no-music` (open: system)

Expected: Same as with music: the band at the base, the page untouched.

- **opacity step** at 303 ms: toast.brightness changed opacity by 0.41 in one frame
- **toast overlap** at 278 ms: toast.brightness covered page
- **toast path** at 278 ms: toast.brightness did not slide up from the bottom edge

### `toast.brightness.open.tasks` (open: tasks · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 305 ms: toast.brightness changed opacity by 0.41 in one frame
- **toast overlap** at 280 ms: toast.brightness covered page
- **toast path** at 280 ms: toast.brightness did not slide up from the bottom edge
- **still** at 363 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.brightness.teleprompter` (teleprompter)

Expected: The teleprompter keeps its height and script; the band is added at the base and the handle follows the edge.

- **opacity step** at 304 ms: toast.brightness changed opacity by 0.40 in one frame
- **toast path** at 279 ms: toast.brightness did not slide up from the bottom edge

### `toast.copied.closed.agent` (closed · agent)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 288 ms: wings.agent changed opacity by 0.62 in one frame
- **opacity step** at 2921 ms: toast.copied changed opacity by 0.60 in one frame
- **opacity step** at 2929 ms: wings.agent changed opacity by 0.37 in one frame
- **toast path** at 2913 ms: toast.copied did not leave the way it came (down, through the bottom edge)
- **still** at 288 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 288 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 279 ms: wings.agent changed (frame or opacity) while only a toast was showing
- **still** at 2896 ms: wings.agent appeared
- **still** at 279 ms: the island changed width by -0.5 pt

### `toast.copied.closed.idle` (closed)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 2917 ms: toast.copied changed opacity by 0.60 in one frame
- **toast path** at 2908 ms: toast.copied did not leave the way it came (down, through the bottom edge)

### `toast.copied.closed.koi` (closed · koi)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 286 ms: wings.koi changed opacity by 0.60 in one frame
- **opacity step** at 2920 ms: toast.copied changed opacity by 0.60 in one frame
- **toast path** at 2911 ms: toast.copied did not leave the way it came (down, through the bottom edge)
- **still** at 286 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 286 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 278 ms: the island changed width by -0.7 pt

### `toast.copied.closed.leaning+music` (leaning · music playing)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 2936 ms: art changed opacity by 0.39 in one frame
- **opacity step** at 2936 ms: bars changed opacity by 0.39 in one frame
- **opacity step** at 2919 ms: toast.copied changed opacity by 0.61 in one frame
- **toast path** at 2911 ms: toast.copied did not leave the way it came (down, through the bottom edge)
- **still** at 278 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 278 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 311 ms: the island changed width by -0.7 pt

### `toast.copied.closed.leaning` (leaning)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 2918 ms: toast.copied changed opacity by 0.61 in one frame
- **toast path** at 2910 ms: toast.copied did not leave the way it came (down, through the bottom edge)
- **still** at 318 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 318 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 302 ms: the island changed width by -0.5 pt

### `toast.copied.closed.meeting` (closed · meeting)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 288 ms: wings.meeting changed opacity by 0.61 in one frame
- **opacity step** at 2921 ms: toast.copied changed opacity by 0.60 in one frame
- **toast path** at 2913 ms: toast.copied did not leave the way it came (down, through the bottom edge)
- **still** at 279 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 279 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 279 ms: wings.meeting changed (frame or opacity) while only a toast was showing
- **still** at 2896 ms: wings.meeting appeared
- **still** at 279 ms: the island changed width by -1.3 pt

### `toast.copied.closed.music` (closed · music playing)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 304 ms: art changed opacity by 0.41 in one frame
- **opacity step** at 304 ms: bars changed opacity by 0.41 in one frame
- **opacity step** at 2921 ms: toast.copied changed opacity by 0.60 in one frame
- **toast path** at 2912 ms: toast.copied did not leave the way it came (down, through the bottom edge)
- **still** at 279 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 279 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.copied.closed.recording` (closed · recording)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 294 ms: wings.recording changed opacity by 0.61 in one frame
- **opacity step** at 2802 ms: toast.copied changed opacity by 0.60 in one frame
- **toast path** at 2794 ms: toast.copied did not leave the way it came (down, through the bottom edge)
- **still** at 287 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 287 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 277 ms: wings.recording changed (frame or opacity) while only a toast was showing
- **still** at 2777 ms: wings.recording appeared
- **still** at 277 ms: the island changed width by -0.8 pt

### `toast.copied.open.agents` (open: agents · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 4231 ms: the copied toast never showed fully inside the island
- **still** at 323 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.copied.open.apps` (open: apps · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 4419 ms: the copied toast never showed fully inside the island
- **still** at 227 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.copied.open.calendar` (open: calendar · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 4392 ms: the copied toast never showed fully inside the island
- **still** at 242 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.copied.open.calendar.no-music` (open: calendar)

Expected: Same as with music: the band at the base, the page untouched.

- **toast missing** at 4269 ms: the copied toast never showed fully inside the island

### `toast.copied.open.clipboard` (open: clipboard · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 253 ms: clip.row0 changed opacity by 1.00 in one frame
- **opacity step** at 253 ms: clip.row1 changed opacity by 1.00 in one frame
- **opacity step** at 253 ms: clip.row2 changed opacity by 1.00 in one frame
- **opacity step** at 253 ms: clip.row1 changed opacity by 1.00 in one frame
- **opacity step** at 253 ms: clip.row2 changed opacity by 1.00 in one frame
- **opacity step** at 253 ms: clip.row3 changed opacity by 1.00 in one frame
- **opacity step** at 278 ms: clip.row0 changed opacity by 0.67 in one frame
- **toast missing** at 4403 ms: the copied toast never showed fully inside the island

### `toast.copied.open.clipboard.no-music` (open: clipboard)

Expected: Same as with music: the band at the base, the page untouched.

- **opacity step** at 256 ms: clip.row0 changed opacity by 1.00 in one frame
- **opacity step** at 256 ms: clip.row1 changed opacity by 1.00 in one frame
- **opacity step** at 256 ms: clip.row2 changed opacity by 1.00 in one frame
- **opacity step** at 256 ms: clip.row1 changed opacity by 1.00 in one frame
- **opacity step** at 256 ms: clip.row2 changed opacity by 1.00 in one frame
- **opacity step** at 256 ms: clip.row3 changed opacity by 1.00 in one frame
- **opacity step** at 266 ms: clip.row0 changed opacity by 1.00 in one frame
- **toast missing** at 4381 ms: the copied toast never showed fully inside the island

### `toast.copied.open.player` (open: player · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 4290 ms: the copied toast never showed fully inside the island
- **still** at 240 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.copied.open.pond` (open: pond · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 4396 ms: the copied toast never showed fully inside the island
- **still** at 263 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.copied.open.recorder` (open: recorder · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 4411 ms: the copied toast never showed fully inside the island
- **still** at 369 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.copied.open.system` (open: system · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 4261 ms: the copied toast never showed fully inside the island
- **still** at 403 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.copied.open.system.no-music` (open: system)

Expected: Same as with music: the band at the base, the page untouched.

- **toast missing** at 4392 ms: the copied toast never showed fully inside the island

### `toast.copied.open.tasks` (open: tasks · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 4420 ms: the copied toast never showed fully inside the island
- **still** at 286 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.copied.teleprompter` (teleprompter)

Expected: The teleprompter keeps its height and script; the band is added at the base and the handle follows the edge.

- **toast missing** at 4339 ms: the copied toast never showed fully inside the island

### `toast.copy-back.open.clipboard.music` (open: clipboard · music playing)

Expected: Clicking a row copies it again: the same Copied toast in the base band, not a label swapped into the row.

- **opacity step** at 297 ms: clip.row0 changed opacity by 1.00 in one frame
- **opacity step** at 297 ms: clip.row1 changed opacity by 1.00 in one frame
- **opacity step** at 297 ms: clip.row0 changed opacity by 1.00 in one frame
- **opacity step** at 297 ms: clip.row1 changed opacity by 1.00 in one frame
- **opacity step** at 347 ms: toast.copied changed opacity by 0.40 in one frame
- **toast band** at 322 ms: toast.copied was 72 pt above the base band
- **toast overlap** at 322 ms: toast.copied covered clip.row0
- **toast path** at 322 ms: toast.copied did not slide up from the bottom edge

### `toast.copy-back.open.clipboard.no-music` (open: clipboard)

Expected: Clicking a row copies it again: the same Copied toast in the base band, not a label swapped into the row.

- **opacity step** at 296 ms: clip.row0 changed opacity by 1.00 in one frame
- **opacity step** at 296 ms: clip.row1 changed opacity by 1.00 in one frame
- **opacity step** at 296 ms: clip.row0 changed opacity by 1.00 in one frame
- **opacity step** at 296 ms: clip.row1 changed opacity by 1.00 in one frame
- **opacity step** at 1609 ms: toast.copied changed opacity by 0.40 in one frame
- **toast band** at 317 ms: toast.copied was 72 pt above the base band
- **toast overlap** at 317 ms: toast.copied covered clip.row0
- **toast path** at 317 ms: toast.copied did not slide up from the bottom edge

### `toast.keepAwake.closed.agent` (closed · agent)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 288 ms: wings.agent changed opacity by 0.60 in one frame
- **opacity step** at 1871 ms: toast.keepAwake changed opacity by 0.61 in one frame
- **opacity step** at 1880 ms: wings.agent changed opacity by 0.51 in one frame
- **toast band** at 280 ms: toast.keepAwake was 4 pt above the base band
- **toast path** at 1863 ms: toast.keepAwake did not leave the way it came (down, through the bottom edge)
- **still** at 288 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 288 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 280 ms: wings.agent changed (frame or opacity) while only a toast was showing
- **still** at 1846 ms: wings.agent appeared
- **still** at 280 ms: the island changed width by +0.8 pt

### `toast.keepAwake.closed.idle` (closed)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 1836 ms: toast.keepAwake changed opacity by 0.64 in one frame
- **toast band** at 278 ms: toast.keepAwake was 4 pt above the base band
- **toast path** at 1819 ms: toast.keepAwake did not leave the way it came (down, through the bottom edge)
- **still** at 278 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 278 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 278 ms: the island changed width by +1.3 pt

### `toast.keepAwake.closed.koi` (closed · koi)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 292 ms: wings.koi changed opacity by 0.62 in one frame
- **opacity step** at 1875 ms: toast.keepAwake changed opacity by 0.60 in one frame
- **toast band** at 283 ms: toast.keepAwake was 4 pt above the base band
- **toast path** at 1867 ms: toast.keepAwake did not leave the way it came (down, through the bottom edge)
- **still** at 292 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 292 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 283 ms: the island changed width by +0.6 pt

### `toast.keepAwake.closed.leaning+music` (leaning · music playing)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 294 ms: art changed opacity by 0.79 in one frame
- **opacity step** at 294 ms: bars changed opacity by 0.82 in one frame
- **opacity step** at 1869 ms: toast.keepAwake changed opacity by 0.61 in one frame
- **toast band** at 277 ms: toast.keepAwake was 7 pt above the base band
- **toast path** at 1861 ms: toast.keepAwake did not leave the way it came (down, through the bottom edge)
- **still** at 277 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 277 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 277 ms: the island changed width by +0.8 pt

### `toast.keepAwake.closed.leaning` (leaning)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 1873 ms: toast.keepAwake changed opacity by 0.63 in one frame
- **toast band** at 281 ms: toast.keepAwake was 7 pt above the base band
- **toast path** at 1865 ms: toast.keepAwake did not leave the way it came (down, through the bottom edge)
- **still** at 281 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 281 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 281 ms: the island changed width by +1.3 pt

### `toast.keepAwake.closed.meeting` (closed · meeting)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 289 ms: wings.meeting changed opacity by 0.61 in one frame
- **opacity step** at 1805 ms: toast.keepAwake changed opacity by 0.58 in one frame
- **opacity step** at 1815 ms: wings.meeting changed opacity by 0.46 in one frame
- **toast band** at 280 ms: toast.keepAwake was 4 pt above the base band
- **toast path** at 1797 ms: toast.keepAwake did not leave the way it came (down, through the bottom edge)
- **still** at 280 ms: wings.meeting changed (frame or opacity) while only a toast was showing
- **still** at 1780 ms: wings.meeting appeared

### `toast.keepAwake.closed.music` (closed · music playing)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 293 ms: art changed opacity by 0.79 in one frame
- **opacity step** at 293 ms: bars changed opacity by 0.83 in one frame
- **opacity step** at 1868 ms: toast.keepAwake changed opacity by 0.60 in one frame
- **toast band** at 276 ms: toast.keepAwake was 4 pt above the base band
- **toast path** at 1860 ms: toast.keepAwake did not leave the way it came (down, through the bottom edge)
- **still** at 276 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 276 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 276 ms: the island changed width by +0.8 pt

### `toast.keepAwake.closed.recording` (closed · recording)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 290 ms: wings.recording changed opacity by 0.60 in one frame
- **opacity step** at 1874 ms: toast.keepAwake changed opacity by 0.60 in one frame
- **opacity step** at 1882 ms: wings.recording changed opacity by 0.50 in one frame
- **toast band** at 282 ms: toast.keepAwake was 4 pt above the base band
- **toast path** at 1865 ms: toast.keepAwake did not leave the way it came (down, through the bottom edge)
- **still** at 290 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 290 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 282 ms: wings.recording changed (frame or opacity) while only a toast was showing
- **still** at 1848 ms: wings.recording appeared
- **still** at 282 ms: the island changed width by +0.6 pt

### `toast.keepAwake.off.open.player` (open: player · music playing)

Expected: On, then off three seconds later: each is its own toast in the band.

- **toast missing** at 6343 ms: the keepAwake toast never showed fully inside the island
- **still** at 268 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.keepAwake.open.agents` (open: agents · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 3321 ms: the keepAwake toast never showed fully inside the island
- **still** at 332 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.keepAwake.open.apps` (open: apps · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 3271 ms: the keepAwake toast never showed fully inside the island
- **still** at 296 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.keepAwake.open.calendar` (open: calendar · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 3283 ms: the keepAwake toast never showed fully inside the island
- **still** at 333 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.keepAwake.open.calendar.no-music` (open: calendar)

Expected: Same as with music: the band at the base, the page untouched.

- **toast missing** at 3353 ms: the keepAwake toast never showed fully inside the island

### `toast.keepAwake.open.clipboard` (open: clipboard · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 3330 ms: the keepAwake toast never showed fully inside the island
- **still** at 239 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.keepAwake.open.clipboard.no-music` (open: clipboard)

Expected: Same as with music: the band at the base, the page untouched.

- **toast missing** at 3353 ms: the keepAwake toast never showed fully inside the island

### `toast.keepAwake.open.player` (open: player · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 3150 ms: the keepAwake toast never showed fully inside the island
- **still** at 317 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.keepAwake.open.player.recording` (open: player · music playing · recording)

Expected: With a recording's badge in the row: the band at the base, the row untouched.

- **toast missing** at 3288 ms: the keepAwake toast never showed fully inside the island
- **still** at 280 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.keepAwake.open.pond` (open: pond · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 3340 ms: the keepAwake toast never showed fully inside the island
- **still** at 240 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.keepAwake.open.recorder` (open: recorder · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 3332 ms: the keepAwake toast never showed fully inside the island
- **still** at 291 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.keepAwake.open.system` (open: system · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 3194 ms: the keepAwake toast never showed fully inside the island
- **still** at 303 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.keepAwake.open.system.no-music` (open: system)

Expected: Same as with music: the band at the base, the page untouched.

- **toast missing** at 3268 ms: the keepAwake toast never showed fully inside the island

### `toast.keepAwake.open.tasks` (open: tasks · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **toast missing** at 3352 ms: the keepAwake toast never showed fully inside the island
- **still** at 319 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.keepAwake.teleprompter` (teleprompter)

Expected: The teleprompter keeps its height and script; the band is added at the base and the handle follows the edge.

- **toast missing** at 3161 ms: the keepAwake toast never showed fully inside the island

### `toast.volume.closed.agent` (closed · agent)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 284 ms: wings.agent changed opacity by 0.63 in one frame
- **opacity step** at 1867 ms: toast.volume changed opacity by 0.60 in one frame
- **opacity step** at 1876 ms: wings.agent changed opacity by 0.56 in one frame
- **toast band** at 276 ms: toast.volume was 4 pt above the base band
- **toast path** at 1859 ms: toast.volume did not leave the way it came (down, through the bottom edge)
- **still** at 284 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 284 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 276 ms: wings.agent changed (frame or opacity) while only a toast was showing
- **still** at 1842 ms: wings.agent appeared
- **still** at 276 ms: the island changed width by +0.8 pt

### `toast.volume.closed.idle` (closed)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 1841 ms: toast.volume changed opacity by 0.60 in one frame
- **toast band** at 283 ms: toast.volume was 4 pt above the base band
- **toast path** at 1832 ms: toast.volume did not leave the way it came (down, through the bottom edge)
- **still** at 283 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 283 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 283 ms: the island changed width by +1.3 pt

### `toast.volume.closed.koi` (closed · koi)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 290 ms: wings.koi changed opacity by 0.60 in one frame
- **opacity step** at 1873 ms: toast.volume changed opacity by 0.60 in one frame
- **toast band** at 282 ms: toast.volume was 4 pt above the base band
- **toast path** at 1865 ms: toast.volume did not leave the way it came (down, through the bottom edge)
- **still** at 290 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 290 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 282 ms: the island changed width by +0.6 pt

### `toast.volume.closed.leaning+music` (leaning · music playing)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 1888 ms: bars changed opacity by 0.36 in one frame
- **toast band** at 312 ms: toast.volume was 1 pt above the base band
- **still** at 320 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 278 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 307 ms: the island changed width by -0.5 pt

### `toast.volume.closed.leaning` (leaning)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 1870 ms: toast.volume changed opacity by 0.60 in one frame
- **toast band** at 279 ms: toast.volume was 7 pt above the base band
- **toast path** at 1862 ms: toast.volume did not leave the way it came (down, through the bottom edge)
- **still** at 279 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 279 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 279 ms: the island changed width by +1.3 pt

### `toast.volume.closed.meeting` (closed · meeting)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 288 ms: wings.meeting changed opacity by 0.61 in one frame
- **opacity step** at 1804 ms: toast.volume changed opacity by 0.60 in one frame
- **opacity step** at 1813 ms: wings.meeting changed opacity by 0.54 in one frame
- **toast band** at 279 ms: toast.volume was 4 pt above the base band
- **toast path** at 1796 ms: toast.volume did not leave the way it came (down, through the bottom edge)
- **still** at 279 ms: wings.meeting changed (frame or opacity) while only a toast was showing
- **still** at 1779 ms: wings.meeting appeared

### `toast.volume.closed.music` (closed · music playing)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 1890 ms: bars changed opacity by 0.39 in one frame
- **toast band** at 366 ms: toast.volume was 1 pt above the base band
- **still** at 282 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.volume.closed.recording` (closed · recording)

Expected: The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move.

- **opacity step** at 290 ms: wings.recording changed opacity by 0.60 in one frame
- **opacity step** at 1873 ms: toast.volume changed opacity by 0.60 in one frame
- **opacity step** at 1881 ms: wings.recording changed opacity by 0.57 in one frame
- **toast band** at 281 ms: toast.volume was 4 pt above the base band
- **toast path** at 1865 ms: toast.volume did not leave the way it came (down, through the bottom edge)
- **still** at 290 ms: art changed (frame or opacity) while only a toast was showing
- **still** at 290 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 281 ms: wings.recording changed (frame or opacity) while only a toast was showing
- **still** at 1848 ms: wings.recording appeared
- **still** at 281 ms: the island changed width by +0.6 pt

### `toast.volume.open.agents` (open: agents · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 306 ms: toast.volume changed opacity by 0.41 in one frame
- **toast overlap** at 281 ms: toast.volume covered page
- **toast path** at 281 ms: toast.volume did not slide up from the bottom edge
- **still** at 256 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.volume.open.apps` (open: apps · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 302 ms: toast.volume changed opacity by 0.44 in one frame
- **toast overlap** at 277 ms: toast.volume covered page
- **toast path** at 277 ms: toast.volume did not slide up from the bottom edge
- **still** at 394 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.volume.open.calendar` (open: calendar · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 303 ms: toast.volume changed opacity by 0.40 in one frame
- **toast overlap** at 278 ms: toast.volume covered page
- **toast path** at 278 ms: toast.volume did not slide up from the bottom edge
- **still** at 287 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.volume.open.calendar.no-music` (open: calendar)

Expected: Same as with music: the band at the base, the page untouched.

- **opacity step** at 304 ms: toast.volume changed opacity by 0.40 in one frame
- **toast overlap** at 279 ms: toast.volume covered page
- **toast path** at 279 ms: toast.volume did not slide up from the bottom edge

### `toast.volume.open.clipboard` (open: clipboard · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 1887 ms: toast.volume changed opacity by 0.41 in one frame
- **toast overlap** at 279 ms: toast.volume covered clip.row2
- **toast path** at 279 ms: toast.volume did not slide up from the bottom edge
- **still** at 587 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.volume.open.clipboard.no-music` (open: clipboard)

Expected: Same as with music: the band at the base, the page untouched.

- **opacity step** at 305 ms: toast.volume changed opacity by 0.41 in one frame
- **toast overlap** at 280 ms: toast.volume covered clip.row2
- **toast path** at 280 ms: toast.volume did not slide up from the bottom edge

### `toast.volume.open.player` (open: player · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 312 ms: player.scrubber changed opacity by 0.36 in one frame
- **opacity step** at 1887 ms: toast.volume changed opacity by 0.38 in one frame
- **toast band** at 287 ms: toast.volume was 36 pt above the base band
- **toast overlap** at 287 ms: toast.volume covered page
- **toast path** at 287 ms: toast.volume did not slide up from the bottom edge
- **still** at 337 ms: bars changed (frame or opacity) while only a toast was showing
- **still** at 279 ms: player.scrubber changed (frame or opacity) while only a toast was showing
- **still** at 1845 ms: player.scrubber appeared

### `toast.volume.open.pond` (open: pond · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 304 ms: toast.volume changed opacity by 0.40 in one frame
- **toast overlap** at 279 ms: toast.volume covered page
- **toast path** at 279 ms: toast.volume did not slide up from the bottom edge
- **still** at 587 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.volume.open.recorder` (open: recorder · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 303 ms: toast.volume changed opacity by 0.42 in one frame
- **toast overlap** at 278 ms: toast.volume covered page
- **toast path** at 278 ms: toast.volume did not slide up from the bottom edge
- **still** at 1020 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.volume.open.system` (open: system · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 302 ms: toast.volume changed opacity by 0.40 in one frame
- **toast overlap** at 277 ms: toast.volume covered page
- **toast path** at 277 ms: toast.volume did not slide up from the bottom edge
- **still** at 436 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.volume.open.system.no-music` (open: system)

Expected: Same as with music: the band at the base, the page untouched.

- **opacity step** at 301 ms: toast.volume changed opacity by 0.40 in one frame
- **toast overlap** at 276 ms: toast.volume covered page
- **toast path** at 276 ms: toast.volume did not slide up from the bottom edge

### `toast.volume.open.tasks` (open: tasks · music playing · all pages)

Expected: The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were.

- **opacity step** at 303 ms: toast.volume changed opacity by 0.40 in one frame
- **toast overlap** at 278 ms: toast.volume covered page
- **toast path** at 278 ms: toast.volume did not slide up from the bottom edge
- **still** at 461 ms: bars changed (frame or opacity) while only a toast was showing

### `toast.volume.teleprompter` (teleprompter)

Expected: The teleprompter keeps its height and script; the band is added at the base and the handle follows the edge.

- **opacity step** at 1877 ms: toast.volume changed opacity by 0.45 in one frame
- **toast path** at 277 ms: toast.volume did not slide up from the bottom edge

