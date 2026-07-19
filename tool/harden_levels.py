#!/usr/bin/env python3
"""Harden existing levels by flipping easy edge-exit tips.

Many arrows currently tip toward the nearest board edge (instant exit),
which makes order-of-play trivial. This script reverses a moderate share
of those paths when the reverse tip has a longer exit run — then proves
constructive solvability so no level becomes impossible.
"""
from __future__ import annotations

import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEVELS = ROOT / "assets" / "levels"

DIRS = {"U": (-1, 0), "D": (1, 0), "L": (0, -1), "R": (0, 1)}


def tip_dir(path: list) -> str:
    a, b = path[-2], path[-1]
    return {(-1, 0): "U", (1, 0): "D", (0, -1): "L", (0, 1): "R"}[
        (b[0] - a[0], b[1] - a[1])
    ]


def exit_length(head, d: str, rows: int, cols: int) -> int:
    dr, dc = DIRS[d]
    r, c = head[0] + dr, head[1] + dc
    n = 0
    while 0 <= r < rows and 0 <= c < cols:
        n += 1
        r += dr
        c += dc
    return n


def clear_exit(head, d: str, occ: set, rows: int, cols: int) -> bool:
    dr, dc = DIRS[d]
    r, c = head[0] + dr, head[1] + dc
    while 0 <= r < rows and 0 <= c < cols:
        if (r, c) in occ:
            return False
        r += dr
        c += dc
    return True


def can_escape(arrow: dict, arrows: list, rows: int, cols: int) -> bool:
    occ = {
        (c[0], c[1])
        for a in arrows
        if a["id"] != arrow["id"]
        for c in a["path"]
    }
    return clear_exit(arrow["path"][-1], arrow["direction"], occ, rows, cols)


def verify_constructive(arrows: list, rows: int, cols: int) -> bool:
    remaining = list(arrows)
    while remaining:
        found = None
        for a in remaining:
            if can_escape(a, remaining, rows, cols):
                found = a
                break
        if found is None:
            return False
        remaining = [x for x in remaining if x["id"] != found["id"]]
    return True


def toward_nearest_edge(head, d: str, rows: int, cols: int) -> bool:
    r, c = head
    edge = {"U": r, "D": rows - 1 - r, "L": c, "R": cols - 1 - c}
    return edge[d] == min(edge.values())


def flip_arrow(arrow: dict) -> dict:
    path = list(reversed(arrow["path"]))
    return {
        **arrow,
        "path": path,
        "direction": tip_dir(path),
    }


def ease_fraction(level_id: int) -> float:
    """How many easy tips we attempt to flip (moderate curve)."""
    if level_id <= 5:
        return 0.15
    if level_id <= 20:
        return 0.35
    if level_id <= 80:
        return 0.48
    return 0.55


def harden(lv: dict) -> tuple[dict, int]:
    rows, cols = lv["rows"], lv["cols"]
    arrows = [dict(a, path=[list(p) for p in a["path"]]) for a in lv["arrows"]]
    if not verify_constructive(arrows, rows, cols):
        return lv, 0

    rr = random.Random(10_000 + int(lv["id"]))
    easy = []
    for a in arrows:
        head = a["path"][-1]
        d = a["direction"]
        near = toward_nearest_edge(head, d, rows, cols)
        elen = exit_length(head, d, rows, cols)
        # Edge freeloaders: tip faces nearest rim with a short clear run.
        if near and elen <= max(3, min(rows, cols) // 4):
            easy.append(a["id"])

    rr.shuffle(easy)
    target = max(0, int(round(len(easy) * ease_fraction(int(lv["id"])))))
    flipped = 0

    by_id = {a["id"]: a for a in arrows}
    for aid in easy[: max(target, len(easy) // 2)]:
        original = by_id[aid]
        candidate = flip_arrow(original)
        old_len = exit_length(original["path"][-1], original["direction"], rows, cols)
        new_len = exit_length(candidate["path"][-1], candidate["direction"], rows, cols)
        old_near = toward_nearest_edge(
            original["path"][-1], original["direction"], rows, cols
        )
        new_near = toward_nearest_edge(
            candidate["path"][-1], candidate["direction"], rows, cols
        )
        # Keep reverse if exit gets longer OR tip leaves the nearest-edge pocket.
        if not (new_len > old_len or (old_near and not new_near)):
            continue

        trial = [candidate if a["id"] == aid else a for a in arrows]
        if verify_constructive(trial, rows, cols):
            by_id[aid] = candidate
            arrows = trial
            flipped += 1

    # Final guarantee.
    if not verify_constructive(arrows, rows, cols):
        return lv, 0

    out = dict(lv)
    out["arrows"] = list(by_id.values())
    # Mild difficulty bump once enough traps land.
    if flipped >= 4 and out.get("difficulty") == "easy" and int(lv["id"]) > 5:
        out["difficulty"] = "medium"
    elif flipped >= 8 and out.get("difficulty") in ("easy", "medium") and int(lv["id"]) > 40:
        out["difficulty"] = "hard"
    return out, flipped


def main() -> None:
    files = sorted(LEVELS.glob("level_*.json"))
    total_flip = 0
    changed = 0
    for path in files:
        lv = json.loads(path.read_text())
        hardened, n = harden(lv)
        if n:
            path.write_text(json.dumps(hardened, separators=(",", ":")) + "\n")
            total_flip += n
            changed += 1
            print(f"{path.name}: flipped {n}")
    # Refresh manifest difficulty fields from files.
    manifest_path = LEVELS / "manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        by_file = {
            p.name: json.loads(p.read_text())
            for p in files
        }
        for entry in manifest.get("levels", []):
            f = entry.get("file")
            if f in by_file:
                entry["difficulty"] = by_file[f].get("difficulty", entry.get("difficulty"))
                entry["name"] = by_file[f].get("name", entry.get("name"))
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"done: {changed} levels updated, {total_flip} tips flipped")


if __name__ == "__main__":
    main()
