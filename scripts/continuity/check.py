#!/usr/bin/env python3
"""Checks continuity traces: one JSON-lines file per cell, written by Topsail's motion tracer
(Topsail/Continuity/MotionTracer.swift). The first line is the cell's description and what it
expects; every other line is one display frame.

    check.py <traces-folder> [--report report.md] [--json report.json] [--worst 10]

Exit status 0 when every cell passes. The rules are the ones in docs/continuity/matrix.md.
"""
import argparse
import json
import os
import sys

FRAME = 16.7            # ms: "one frame" for the opacity and teleport rules
OPACITY_STEP = 0.35     # largest opacity change in one frame
TELEPORT = 40.0         # pt: largest move of any edge in one frame
CENTRE = 0.5            # pt: the island's centre against the notch's
SLOW_FRAME = 25.0       # ms
VISIBLE = 0.05          # opacity above which something counts as on screen
BLINK = 400.0           # ms: gone and back within this is a swap, not a leave and a return
SKEW = 17.0             # ms: a parent's animated size and a child placed against it can be one
                        # frame apart inside SwiftUI; rules that compare the two allow for it
RADII = {"collapsed": (6.0, 14.0), "expanded": (14.0, 24.0)}
REST = 250.0            # ms without the island changing size: at rest
# Elements whose own content keeps changing size (never judged for stillness).
RESTLESS = ("wings.koi",)
# Elements that hang outside the island by design (never clipped by it).
OUTSIDE = ("tele.handle",)
# A page pick, or a page that has just gone away: the page may change after these.
PAGE_STEPS = ("click tab.", "pick ", "music off", "teleprompter")


class Trace:
    def __init__(self, path):
        with open(path) as handle:
            lines = [line for line in handle.read().split("\n") if line]
        self.header = json.loads(lines[0])
        self.id = self.header["cell"]
        self.frames = [json.loads(line) for line in lines[1:]]
        self.t = [frame["t"] for frame in self.frames]
        self.reduce_motion = bool(self.header.get("reduceMotion"))
        self.band = float(self.header.get("band", 24))
        # instances[(name, serial)] = per-frame (x, y, w, h, opacity) or None
        self.instances = {}
        self.controls = set()
        count = len(self.frames)
        for index, frame in enumerate(self.frames):
            for name, entries in frame.get("e", {}).items():
                for entry in entries:
                    key = (name, entry[0])
                    if key not in self.instances:
                        self.instances[key] = [None] * count
                    self.instances[key][index] = tuple(entry[1:6])
                    if len(entry) > 6 and entry[6]:
                        self.controls.add(name)
        self.island = [tuple(frame["i"]) if "i" in frame else None for frame in self.frames]
        self.state = [frame.get("s", {}) for frame in self.frames]
        self.steps = [(frame["t"], label) for frame in self.frames for label in frame.get("ev", [])]

    # ---- helpers

    def causes(self):
        """Times something was asked of the island: a trigger, or the model changing state."""
        times = {t for t, _ in self.steps}
        keys = ("st", "page", "act", "toast", "tele", "lean", "side")
        for index in range(1, len(self.frames)):
            before, after = self.state[index - 1], self.state[index]
            if any(before.get(key) != after.get(key) for key in keys):
                times.add(self.t[index])
        return sorted(times)

    def index_at(self, time):
        """Last frame at or before `time`."""
        low, high = 0, len(self.t) - 1
        if time <= self.t[0]:
            return 0
        while low < high:
            mid = (low + high + 1) // 2
            if self.t[mid] <= time:
                low = mid
            else:
                high = mid - 1
        return low

    def sample(self, series, index, back=FRAME):
        """A per-frame series' value `back` ms before frame `index` (linear between frames)."""
        time = self.t[index] - back
        if time <= self.t[0]:
            return series[0]
        j = self.index_at(time)
        a, b = series[j], series[min(j + 1, len(series) - 1)]
        if a is None or b is None:
            return a
        span = self.t[min(j + 1, len(series) - 1)] - self.t[j]
        k = 0 if span <= 0 else (time - self.t[j]) / span
        return tuple(x + (y - x) * k for x, y in zip(a, b))


def opacity(value):
    return 0.0 if value is None else value[4]


def edges(value):
    x, y, w, h = value[:4]
    return (x, y, x + w, y + h)


def overlap(a, b):
    return min(a[2], b[2]) - max(a[0], b[0]) > 0.5 and min(a[3], b[3]) - max(a[1], b[1]) > 0.5


def inside(value, island):
    """The fraction of an element's frame that is inside the island's shape."""
    if value is None or island is None:
        return 0.0
    x, y, w, h = value[:4]
    if w <= 0 or h <= 0:
        return 0.0
    width = min(x + w, island[0] / 2 + 1) - max(x, -island[0] / 2 - 1)
    height = min(y + h, island[1] + 1) - max(y, -1)
    return max(0.0, min(1.0, width / w)) * max(0.0, min(1.0, height / h))


def is_toast(name):
    return name.startswith("toast.")


def check(trace):
    """Returns (failures, warnings): lists of (rule, time, text)."""
    failures, warnings = [], []
    header, frames, t = trace.header, trace.frames, trace.t
    expect = header.get("expect", {})
    count = len(frames)
    if count < 10:
        return [("harness", 0, "the trace is empty")], []

    def fail(rule, time, text):
        failures.append((rule, round(time), text))

    names = sorted({name for name, _ in trace.instances})
    by_name = {name: [key for key in trace.instances if key[0] == name] for name in names}
    causes = trace.causes()
    first_cause = causes[0] if causes else t[-1]

    # The cell must start from rest, or what follows can't be judged.
    for index in range(1, count):
        if t[index] >= first_cause - 20:
            break
        if trace.island[index] and trace.island[index - 1] and \
                any(abs(a - b) > 0.3 for a, b in zip(trace.island[index][:2], trace.island[index - 1][:2])):
            fail("harness", t[index], "the island was still moving before the first trigger")
            break

    # 1. Opacity: nothing appears or disappears by more than 0.35 in one frame. What counts is
    # what can be seen: the element's opacity times the part of it inside the island's shape, so
    # being cut off by the island snapping shut is a pop too, and sliding in under its edge is not.
    for key, series in trace.instances.items():
        name = key[0]
        if name in OUTSIDE:
            seen = [(opacity(value),) for value in series]
        else:
            seen = [(opacity(value) * inside(value, trace.island[index]),) for index, value in enumerate(series)]
        worst = (0, 0, False)
        for index in range(1, count):
            if series[index] is None and series[index - 1] is None:
                continue
            step = abs(seen[index][0] - trace.sample(seen, index)[0])
            if step > worst[0]:
                cut = abs(opacity(series[index]) - opacity(trace.sample(series, index))) <= OPACITY_STEP
                worst = (step, t[index], cut)
        if worst[0] > OPACITY_STEP + 0.005:
            if worst[2]:
                # An edge sweeping past a thin element is a wipe, not a cut; the island's edge
                # jumping over it is a cut.
                index = trace.index_at(worst[1])
                now, before = trace.island[index], trace.sample(trace.island, index)
                jumped = now and before and max(abs(now[0] - before[0]) / 2, abs(now[1] - before[1])) > 24
                if jumped:
                    fail("opacity step", worst[1], f"{name} was cut off by the island's edge ({worst[0]:.2f} of it in one frame)")
            else:
                fail("opacity step", worst[1], f"{name} changed opacity by {worst[0]:.2f} in one frame")

    # 2. Pop or swap: the same thing before and after must be one view that stays on screen.
    for name in names:
        keys = by_name[name]
        if name in RESTLESS:
            continue
        doubled = None
        for index in range(count):
            shown = [key for key in keys if opacity(trace.instances[key][index]) > VISIBLE]
            if len(shown) > 1:
                doubled = t[index]
                break
        if doubled is not None:
            fail("second copy", doubled, f"two copies of {name} were on screen at once")
        visible = [max(opacity(trace.instances[key][index]) for key in keys) >= 0.5 for index in range(count)]
        gone_since = None
        for index in range(1, count):
            if visible[index - 1] and not visible[index]:
                gone_since = t[index]
            elif visible[index] and not visible[index - 1] and gone_since is not None:
                # Sent away by one event and brought back by another (the pointer left, then
                # returned) is a leave and a return; within one event it is a swap.
                asked_back = any(gone_since - 30 < cause <= t[index] for cause in causes)
                if t[index] - gone_since < BLINK and not asked_back:
                    fail("blink", gone_since, f"{name} went away and came back {t[index] - gone_since:.0f} ms later")
                gone_since = None

    # 3. Teleport: nothing visible moves more than 40 pt in one frame.
    if not trace.reduce_motion:
        for key, series in trace.instances.items():
            worst = (0, 0)
            for index in range(1, count):
                now, before = series[index], trace.sample(series, index)
                if now is None or before is None or min(now[4], before[4]) <= 0.1:
                    continue
                move = max(abs(a - b) for a, b in zip(edges(now), edges(before)))
                if move > worst[0]:
                    worst = (move, t[index])
            if worst[0] > TELEPORT:
                fail("teleport", worst[1], f"{key[0]} moved {worst[0]:.0f} pt in one frame")
        worst = (0, 0)
        for index in range(1, count):
            now, before = trace.island[index], trace.sample(trace.island, index)
            if now is None or before is None:
                continue
            move = max(abs(now[0] - before[0]) / 2, abs(now[1] - before[1]))
            if move > worst[0]:
                worst = (move, t[index])
        if worst[0] > TELEPORT:
            fail("teleport", worst[1], f"the island's edge moved {worst[0]:.0f} pt in one frame")

    # 4. The island stays centred on the notch, hanging from the top of the screen.
    for index in range(count):
        island = trace.island[index]
        if island is None:
            fail("centre", t[index], "the island was not on screen")
            break
        if abs(island[2]) > CENTRE or abs(island[3]) > CENTRE:
            fail("centre", t[index], f"the island was {island[2]:.2f} pt off the notch's centre, {island[3]:.2f} pt from the top")
            break

    # 5. Corner radii at rest: 6/14 closed, 14/24 open, nothing else.
    rest_from = 0
    for index in range(1, count + 1):
        moved = index < count and trace.island[index] and trace.island[index - 1] and (
            any(abs(a - b) > 0.05 for a, b in zip(trace.island[index][:2], trace.island[index - 1][:2]))
            or trace.state[index].get("st") != trace.state[index - 1].get("st"))
        if index == count or moved:
            if t[index - 1] - t[rest_from] >= REST and trace.island[index - 1]:
                state = trace.state[index - 1].get("st")
                radii = trace.island[index - 1][4:6]
                wanted = RADII.get(state)
                if wanted and (abs(radii[0] - wanted[0]) > 0.05 or abs(radii[1] - wanted[1]) > 0.05):
                    fail("radii", t[index - 1], f"at rest {state} with radii {radii[0]:g}/{radii[1]:g}, not {wanted[0]:g}/{wanted[1]:g}")
            rest_from = index

    # 6. The page: what was expected at the end, and never changed unasked.
    final = trace.state[-1]
    if "page" in expect and final.get("page") != expect["page"]:
        fail("page", t[-1], f"ended on the {final.get('page')} page, expected {expect['page']}")
    if "state" in expect and final.get("st") != expect["state"]:
        fail("page", t[-1], f"ended {final.get('st')}, expected {expect['state']}")
    for index in range(1, count):
        before, after = trace.state[index - 1], trace.state[index]
        if before.get("page") == after.get("page"):
            continue
        opened = after.get("st") == "expanded" and any(
            trace.state[j].get("st") != "expanded" for j in range(max(0, index - 30), index))
        asked = any(0 <= t[index] - when <= 250 and label.startswith(PAGE_STEPS) for when, label in trace.steps)
        if not (opened or asked or after.get("st") != "expanded"):
            fail("page", t[index], f"the page changed from {before.get('page')} to {after.get('page')} unasked")

    # 7–8. Toasts: in the base band, vertical only, in and out the same way, never over a control.
    toast_names = [name for name in names if is_toast(name)]
    # The band's top is the content's bottom edge (traced as "content"); before that was traced,
    # the island's bottom edge less the band.
    band_top = []
    for index in range(count):
        content = next((trace.instances[key][index] for key in by_name.get("content", [])
                        if trace.instances[key][index] is not None), None)
        if content is not None:
            band_top.append(content[1] + content[3])
        elif "content" in by_name:
            band_top.append(None)
        else:
            band_top.append(0.0)  # traces from before the content was traced: judged by position on screen
    has_content = "content" in by_name
    for name in toast_names:
        for key in by_name[name]:
            series = trace.instances[key]
            shown = [index for index in range(count) if opacity(series[index]) > VISIBLE and trace.island[index]]
            if not shown:
                continue
            full = [index for index in shown if opacity(series[index]) >= 0.95]
            if not full:
                continue
            # How far below the band's top (the content's bottom edge) the toast is: 0 once it has
            # arrived, more while it is sliding in or out.
            def below(index):
                tops = [band_top[j] for j in (index, trace.index_at(t[index] - SKEW), trace.index_at(t[index] + SKEW))
                        if band_top[j] is not None]
                return None if not tops else series[index][1] - min(tops)

            rest_y = None
            for index in full:
                later = [j for j in full if 0 <= t[j] - t[index] <= 120]
                if below(index) is not None and len(later) > 3 and \
                        all(below(j) is not None and abs(below(j) - below(index)) < 0.3 for j in later):
                    rest_y = below(index)
                    break
            centre = series[full[0]][0] + series[full[0]][2] / 2
            reported = set()

            def once(rule, time, text):
                if rule not in reported:
                    reported.add(rule)
                    fail(rule, time, text)

            for index in shown:
                value, island = series[index], trace.island[index]
                bottoms = [island[1]] + [other[1] for other in (trace.sample(trace.island, index, SKEW),
                                                                trace.island[trace.index_at(t[index] + SKEW)]) if other]
                if value[1] < min(bottoms) - trace.band - 1.0:
                    once("toast band", t[index], f"{name} was {min(bottoms) - trace.band - value[1]:.0f} pt above the base band")
                if abs(value[0] + value[2] / 2 - centre) > 0.75:
                    once("toast band", t[index], f"{name} moved sideways by {abs(value[0] + value[2] / 2 - centre):.1f} pt")
                clipped = (max(value[0], -island[0] / 2), max(value[1], 0),
                           min(value[0] + value[2], island[0] / 2), min(value[1] + value[3], island[1]))
                if clipped[2] - clipped[0] <= 0.5 or clipped[3] - clipped[1] <= 0.5:
                    continue
                # The content is clipped at its own bottom edge: nothing of it shows below that.
                # (Taken a frame either side as well: see SKEW.)
                near = [index, trace.index_at(t[index] - SKEW), trace.index_at(t[index] + SKEW)]
                floors = [band_top[j] if has_content and band_top[j] is not None else trace.island[j][1]
                          for j in near if trace.island[j]]
                for other in names:
                    if is_toast(other) or other in OUTSIDE or not (other in trace.controls or other == "page"):
                        continue
                    for other_key in by_name[other]:
                        rects = [trace.instances[other_key][j] for j in near]
                        if any(rect is None or rect[4] <= VISIBLE for rect in rects):
                            continue
                        if all(overlap(clipped, (rect[0], rect[1], rect[0] + rect[2], min(rect[1] + rect[3], floor)))
                               for rect in rects for floor in floors):
                            once("toast overlap", t[index], f"{name} covered {other}")
            if rest_y is not None:
                entering = [index for index in shown if index < full[0] and below(index) is not None]
                leaving = [index for index in shown if index > full[-1] and below(index) is not None]
                if trace.reduce_motion:
                    if any(abs(series[index][1] - series[full[0]][1]) > 0.5 for index in shown) and \
                            len({trace.state[index].get("st") for index in shown}) == 1 and \
                            len({trace.state[index].get("page") for index in shown}) == 1:
                        once("reduce motion", t[shown[0]], f"{name} slid although Reduce Motion is on")
                else:
                    if entering and max(below(index) for index in entering) <= rest_y + 1.0:
                        once("toast path", t[entering[0]], f"{name} did not slide up from the bottom edge")
                    if not entering and shown[0] > 0:
                        once("toast path", t[shown[0]], f"{name} appeared at full opacity")
                    if leaving:
                        if max(below(index) for index in leaving) <= rest_y + 1.0:
                            once("toast path", t[leaving[0]], f"{name} did not leave the way it came (down, through the bottom edge)")
                    elif shown[-1] < count - 1:
                        once("toast path", t[shown[-1]], f"{name} vanished at full opacity")

    # Notices grow out of the notch: the shape leads and the words follow; going back, the
    # words are gone before the shape closes over them.
    if not trace.reduce_motion:
        for name in names:
            if not name.startswith("notice."):
                continue
            for key in by_name[name]:
                series = trace.instances[key]
                present = [index for index in range(count) if series[index] is not None and trace.island[index]]
                full = [index for index in present if opacity(series[index]) >= 0.95]
                if not full or present[0] == 0:
                    continue
                height = lambda index: trace.island[index][1]
                before, shown = height(present[0] - 1), max(height(index) for index in full)
                if abs(shown - before) >= 8:
                    for index in present:
                        if index >= full[0]:
                            break
                        if (height(index) - before) / (shown - before) >= 0.5:
                            if opacity(series[index]) > 0.4:
                                fail("notice order", t[index],
                                     f"{name} was {opacity(series[index]):.0%} there when the shape was half open: the shape must lead")
                            break
                after_index = trace.index_at(t[present[-1]] + 400) if present[-1] < count - 1 else None
                if after_index is not None:
                    after = height(after_index)
                    if abs(shown - after) >= 8:
                        for index in present:
                            if index <= full[-1]:
                                continue
                            if (shown - height(index)) / (shown - after) >= 0.5:
                                if opacity(series[index]) > 0.4:
                                    fail("notice order", t[index],
                                         f"{name} was still {opacity(series[index]):.0%} there when the shape was half closed")
                                break

    # What hangs outside the island (the teleprompter's handle) is below its bottom edge.
    for name in OUTSIDE:
        for key in by_name.get(name, []):
            series = trace.instances[key]
            for index in range(count):
                value, island = series[index], trace.island[index]
                bottoms = [other[1] for other in (island, trace.sample(trace.island, index, SKEW),
                                                  trace.island[trace.index_at(t[index] + SKEW)]) if other]
                if value is not None and value[4] > 0.5 and bottoms and value[1] < min(bottoms) - 1.0:
                    fail("outside", t[index], f"{name} was {min(bottoms) - value[1]:.0f} pt inside the island, not below it")
                    break

    # Expected to show: toasts, notices and wings named by the cell.
    for kind in expect.get("toasts", []):
        name = "toast." + kind
        best = 0
        for key in by_name.get(name, []):
            series = trace.instances[key]
            within = [index for index in range(count) if opacity(series[index]) >= 0.9 and trace.island[index]
                      and series[index][1] + series[index][3] <= trace.island[index][1] + 0.5 and series[index][1] >= 0]
            if within:
                best = max(best, t[within[-1]] - t[within[0]])
        if best < 300:
            fail("toast missing", t[-1], f"the {kind} toast never showed fully inside the island")
    for name in expect.get("shows", []):
        if not any(opacity(value) >= 0.9 for key in by_name.get(name, []) for value in trace.instances[key]):
            fail("missing", t[-1], f"{name} never showed")
    for name in expect.get("glimpses", []):
        if not any(opacity(value) >= 0.3 for key in by_name.get(name, []) for value in trace.instances[key]):
            fail("missing", t[-1], f"{name} was never seen")
    for name in expect.get("never", []):
        if any(opacity(value) > VISIBLE for key in by_name.get(name, []) for value in trace.instances[key]):
            fail("unexpected", t[-1], f"{name} showed")

    # A toast's promise (and a notice's, while the island is open): nothing else moves or fades.
    def unchanged(label, allow_height):
        start = trace.index_at(max(first_cause - 30, 0))
        for key, series in trace.instances.items():
            name = key[0]
            if is_toast(name) or name in RESTLESS or name in OUTSIDE:
                continue
            base = series[start]
            for index in range(start, count):
                value = series[index]
                if (base is None) != (value is None):
                    fail(label, t[index], f"{name} {'appeared' if base is None else 'went away'}")
                    break
                if value is None:
                    continue
                if any(abs(a - b) > 0.5 for a, b in zip(edges(value), edges(base))) or abs(value[4] - base[4]) > 0.03:
                    why = "while only a toast was showing" if allow_height else "though nothing should have changed"
                    fail(label, t[index], f"{name} changed (frame or opacity) {why}")
                    break
        base = trace.island[start]
        for index in range(start, count):
            island = trace.island[index]
            if island is None or base is None:
                continue
            if abs(island[0] - base[0]) > 0.5:
                fail(label, t[index], f"the island changed width by {island[0] - base[0]:+.1f} pt")
                break
            grew = island[1] - base[1]
            if (not allow_height and abs(grew) > 0.5) or (allow_height and (grew < -0.5 or grew > trace.band + 1.5)):
                fail(label, t[index], f"the island changed height by {grew:+.1f} pt")
                break

    if expect.get("quiet"):
        unchanged("quiet", allow_height=False)
    if expect.get("still"):
        unchanged("still", allow_height=True)

    # 9. One event, one resize: no double bounce.
    edges_of_windows = causes + [t[-1] + 1]
    for start, end in zip(edges_of_windows, edges_of_windows[1:]):
        first, last = trace.index_at(start), trace.index_at(end - 0.01)
        if last - first < 4:
            continue
        tracks = [("width", [(i, trace.island[i][0]) for i in range(first, last + 1) if trace.island[i]])]
        if has_content:
            # What the island shows and a toast's band are resized by different events, each once.
            tracks.append(("height", [(i, band_top[i]) for i in range(first, last + 1) if band_top[i] is not None]))
            tracks.append(("band", [(i, trace.island[i][1] - band_top[i]) for i in range(first, last + 1)
                                    if trace.island[i] and band_top[i] is not None]))
        else:
            tracks.append(("height", [(i, trace.island[i][1]) for i in range(first, last + 1) if trace.island[i]]))
        for label, track in tracks:
            if len(track) < 4:
                continue
            axis_at = dict(track)
            values = [(t[i], value) for i, value in track]
            runs = moves(values)
            # Already moving when the event came: the spring carries on a little before it turns
            # for the new target. That is momentum, not a second resize.
            if len(runs) > 1 and first >= 3 and first in axis_at and trace.island[first - 3]:
                before = {"width": trace.island[first - 3][0],
                          "height": band_top[first - 3] if has_content and band_top[first - 3] is not None else trace.island[first - 3][1],
                          "band": trace.island[first - 3][1] - (band_top[first - 3] or 0) if has_content else 0}[label]
                carried = axis_at[first] - before
                if abs(carried) > 0.3 and (carried > 0) == (runs[0] > 0) and (runs[1] > 0) != (runs[0] > 0):
                    runs = runs[1:]
            if len(runs) > 1:
                text = ", then ".join(f"{run:+.0f} pt" for run in runs[:3])
                fail("double resize", start, f"one event resized the island's {label} more than once ({text})")
                break

    # 10. Reduce Motion: things change place at once or fade; nothing travels.
    if trace.reduce_motion:
        for key, series in list(trace.instances.items()) + [(("island", 0), None)]:
            name = key[0]
            if name in RESTLESS or name == "bars":
                continue
            run = 0
            for index in range(1, count):
                if series is None:
                    now, before = trace.island[index], trace.island[index - 1]
                    changed = now and before and any(abs(a - b) > 0.3 for a, b in zip(now[:2], before[:2]))
                else:
                    now, before = series[index], series[index - 1]
                    changed = now is not None and before is not None and min(now[4], before[4]) > VISIBLE and \
                        any(abs(a - b) > 0.3 for a, b in zip(edges(now), edges(before)))
                run = run + 1 if changed else 0
                if run >= 3:
                    fail("reduce motion", t[index], f"{name} moved over several frames although Reduce Motion is on")
                    break

    # 11. Frame time during a transition (enforced on the optimised build).
    slow = []
    for index in range(1, count):
        gap = t[index] - t[index - 1]
        if gap <= SLOW_FRAME:
            continue
        if any(0 <= t[index] - cause <= 700 for cause in causes) or busy(trace, index):
            slow.append((gap, t[index]))
    if slow:
        worst = max(slow)
        text = f"{len(slow)} frame(s) over {SLOW_FRAME:g} ms during a transition (worst {worst[0]:.0f} ms)"
        if header.get("build") == "release":
            fail("slow frame", worst[1], text)
        else:
            warnings.append(("slow frame", round(worst[1]), text))
    return failures, warnings


def busy(trace, index):
    a, b = trace.island[index], trace.island[index - 1]
    return bool(a and b and any(abs(x - y) > 0.3 for x, y in zip(a[:2], b[:2])))


def moves(values, pause=70.0):
    """The separate movements in a series of (time, value): direction changes and restarts after a
    pause count; a spring's own overshoot and settle do not."""
    runs = []
    start = last = values[0][1]
    direction = 0
    still_since = values[0][0]
    for time, value in values[1:]:
        delta = value - last
        if abs(delta) < 0.08:
            continue
        sign = 1 if delta > 0 else -1
        paused = direction != 0 and time - still_since > pause and abs(delta) > 0.5
        if direction == 0:
            direction, start = sign, last
        elif sign != direction or paused:
            runs.append(last - start)
            direction, start = sign, last
        last, still_since = value, time
    if direction != 0:
        runs.append(last - start)
    if not runs:
        return []
    largest = max(abs(run) for run in runs)
    return [run for run in runs if abs(run) >= max(2.0, 0.08 * largest)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("folder")
    parser.add_argument("--report")
    parser.add_argument("--json")
    parser.add_argument("--worst", type=int, default=10)
    arguments = parser.parse_args()

    files = sorted(name for name in os.listdir(arguments.folder) if name.endswith(".jsonl"))
    results = []
    for name in files:
        trace = Trace(os.path.join(arguments.folder, name))
        failures, warnings = check(trace)
        results.append({"cell": trace.id, "group": trace.header.get("group", ""), "start": trace.header.get("start", ""),
                        "steps": trace.header.get("steps", []), "summary": trace.header.get("summary", ""),
                        "build": trace.header.get("build", ""),
                        "failures": [{"rule": rule, "t": time, "text": text} for rule, time, text in failures],
                        "warnings": [{"rule": rule, "t": time, "text": text} for rule, time, text in warnings]})

    failed = [result for result in results if result["failures"]]
    by_rule = {}
    for result in failed:
        for rule in {failure["rule"] for failure in result["failures"]}:
            by_rule[rule] = by_rule.get(rule, 0) + 1
    worst = sorted(failed, key=lambda result: (-len({f["rule"] for f in result["failures"]}), -len(result["failures"]), result["cell"]))

    lines = [f"# Continuity run: {len(results) - len(failed)} of {len(results)} cells pass", ""]
    builds = sorted({result["build"] for result in results})
    lines.append(f"Build: {', '.join(builds)}. Failing cells: {len(failed)}. Failures in all: {sum(len(r['failures']) for r in failed)}.")
    slow = [result for result in results if result["warnings"]]
    if slow:
        lines.append(f"Cells with a slow frame (not counted on a debug build): {len(slow)}.")
    lines.append("")
    if by_rule:
        lines += ["| Rule broken | Cells |", "| --- | ---: |"]
        lines += [f"| {rule} | {cells} |" for rule, cells in sorted(by_rule.items(), key=lambda item: -item[1])]
        lines.append("")
        lines.append(f"## The {min(arguments.worst, len(worst))} worst cells")
        lines.append("")
        for result in worst[:arguments.worst]:
            lines.append(f"- `{result['cell']}`: " + "; ".join(sorted({f['rule'] for f in result['failures']})))
        lines.append("")
        lines.append("## Every failing cell")
        lines.append("")
        for result in failed:
            lines.append(f"### `{result['cell']}` ({result['start']})")
            lines.append("")
            lines.append(f"Expected: {result['summary']}")
            lines.append("")
            for failure in result["failures"]:
                lines.append(f"- **{failure['rule']}** at {failure['t']} ms: {failure['text']}")
            lines.append("")
    report = "\n".join(lines) + "\n"
    if arguments.report:
        with open(arguments.report, "w") as handle:
            handle.write(report)
    if arguments.json:
        with open(arguments.json, "w") as handle:
            json.dump({"cells": len(results), "failed": len(failed), "by_rule": by_rule,
                       "worst": [result["cell"] for result in worst[:arguments.worst]], "results": results}, handle, indent=1)

    print(f"{len(results) - len(failed)} of {len(results)} cells pass; {len(failed)} fail.")
    for rule, cells in sorted(by_rule.items(), key=lambda item: -item[1]):
        print(f"  {rule}: {cells} cell(s)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
