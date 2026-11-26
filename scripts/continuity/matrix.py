#!/usr/bin/env python3
"""Rewrites the cell tables in docs/continuity/matrix.md from the app's own list of cells
(`cells.json`, written by `Topsail --continuity --continuity-list <file>`; scripts/continuity.sh
does this on every run), so the document and the suite cannot drift apart.

    matrix.py <cells.json> <matrix.md>
"""
import json
import sys

START, END = "<!-- cells:start -->", "<!-- cells:end -->"


def main():
    cells_path, doc_path = sys.argv[1], sys.argv[2]
    with open(cells_path) as handle:
        cells = json.load(handle)
    groups = []
    for cell in cells:
        if cell["group"] not in groups:
            groups.append(cell["group"])

    lines = [START, "", f"{len(cells)} cells in {len(groups)} groups. Times are milliseconds after the trace starts.", ""]
    for group in groups:
        members = [cell for cell in cells if cell["group"] == group]
        lines += [f"### {group} ({len(members)})", "", "| Cell | Starts | Triggers | Expected |", "| --- | --- | --- | --- |"]
        for cell in members:
            steps = cell["steps"]
            if len(steps) > 4 and len({label.split(" ")[0] for _, label in steps}) == 1:
                first, last = steps[0], steps[-1]
                triggers = f"{len(steps)} × {first[1].split(' ')[0]} from {first[0]:g} to {last[0]:g} ({first[1]} … {last[1]})"
            else:
                triggers = "; ".join(f"{at:g} {label}" for at, label in steps)
            expect = cell["expect"]
            ends = []
            if "state" in expect:
                ends.append("ends " + ("open" if expect["state"] == "expanded" else "closed"))
            if "page" in expect:
                ends.append(f"page {expect['page']}")
            extra = f" *({', '.join(ends)})*" if ends else ""
            lines.append(f"| `{cell['cell']}` | {cell['start']} | {triggers} | {cell['summary']}{extra} |")
        lines.append("")
    lines.append(END)

    with open(doc_path) as handle:
        text = handle.read()
    if START not in text or END not in text:
        sys.exit(f"{doc_path} has no {START} … {END} section")
    head, rest = text.split(START, 1)
    tail = rest.split(END, 1)[1]
    with open(doc_path, "w") as handle:
        handle.write(head + "\n".join(lines) + tail)
    print(f"{doc_path}: {len(cells)} cells")


if __name__ == "__main__":
    main()
