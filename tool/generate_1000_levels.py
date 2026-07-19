#!/usr/bin/env python3
"""Generate 1000 unique pictorial levels.

Rules:
  - Levels 1–5: softer intros (kept recognizable & lighter)
  - Levels 6–1000: ≥40 arrows, max path length 8, unique clear silhouette
  - No repeated level id / shape name
"""
from __future__ import annotations

import json
import math
import random
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

OUT = Path("assets/levels")
DIRS = {"U": (-1, 0), "D": (1, 0), "L": (0, -1), "R": (0, 1)}
DIR_LIST = list(DIRS.items())


def tip_dir(path: list) -> str:
    a, b = path[-2], path[-1]
    return {(-1, 0): "U", (1, 0): "D", (0, -1): "L", (0, 1): "R"}[
        (b[0] - a[0], b[1] - a[1])
    ]


def A(aid: str, path: list, color: int = 0) -> dict:
    return {
        "id": aid,
        "path": [list(p) for p in path],
        "direction": tip_dir(path),
        "colorIndex": color % 6,
    }


def neighbors(r, c, rows, cols):
    for _, (dr, dc) in DIR_LIST:
        nr, nc = r + dr, c + dc
        if 0 <= nr < rows and 0 <= nc < cols:
            yield nr, nc


def clear_exit(head, d, occ, rows, cols) -> bool:
    dr, dc = DIRS[d]
    r, c = head[0] + dr, head[1] + dc
    while 0 <= r < rows and 0 <= c < cols:
        if (r, c) in occ:
            return False
        r += dr
        c += dc
    return True


def validate_layout(lv: dict) -> str | None:
    occupied = {}
    for a in lv["arrows"]:
        for cell in a["path"]:
            t = tuple(cell)
            if t in occupied:
                return f"overlap {a['id']} vs {occupied[t]} at {t}"
            occupied[t] = a["id"]
            r, c = cell
            if not (0 <= r < lv["rows"] and 0 <= c < lv["cols"]):
                return f"oob {a['id']} {t}"
        if len(a["path"]) < 2 or tip_dir(a["path"]) != a["direction"]:
            return f"bad tip {a['id']}"
    # Constructive solvability: reverse placement order (dense_fill guarantees this).
    remaining = list(lv["arrows"])
    for a in reversed(lv["arrows"]):
        occ = {
            (c[0], c[1])
            for x in remaining
            if x["id"] != a["id"]
            for c in x["path"]
        }
        if not clear_exit(a["path"][-1], a["direction"], occ, lv["rows"], lv["cols"]):
            return "unsolvable-order"
        remaining = [x for x in remaining if x["id"] != a["id"]]
    return None


def L(lid, name, difficulty, rows, cols, arrows) -> dict:
    lv = {
        "id": lid,
        "name": name,
        "difficulty": difficulty,
        "rows": rows,
        "cols": cols,
        "hearts": 3,
        "arrows": arrows,
    }
    err = validate_layout(lv)
    if err:
        raise AssertionError(f"L{lid} {err}")
    return lv


def oval(rows, cols, cx, cy, rx, ry):
    m = set()
    for r in range(rows):
        for c in range(cols):
            if ((r - cx) / max(ry, 0.01)) ** 2 + ((c - cy) / max(rx, 0.01)) ** 2 <= 1.0:
                m.add((r, c))
    return m


def rect(rows, cols, r0, r1, c0, c1):
    return {
        (r, c)
        for r in range(max(0, r0), min(rows, r1))
        for c in range(max(0, c0), min(cols, c1))
    }


def diamond(rows, cols, cx, cy, rad):
    return {
        (r, c)
        for r in range(rows)
        for c in range(cols)
        if abs(r - cx) + abs(c - cy) <= rad
    }


def is_boundary(cell, mask, rows, cols) -> bool:
    r, c = cell
    for nr, nc in neighbors(r, c, rows, cols):
        if (nr, nc) not in mask:
            return True
    return r == 0 or c == 0 or r == rows - 1 or c == cols - 1


def outward_dirs(cell, mask, rows, cols):
    r, c = cell
    out = []
    for name, (dr, dc) in DIR_LIST:
        nr, nc = r + dr, c + dc
        if not (0 <= nr < rows and 0 <= nc < cols) or (nr, nc) not in mask:
            out.append(name)
    return out


def grow_bent_path(start, mask, occupied, rows, cols, rr, length, bend_bias=0.72):
    path = [start]
    used = set(occupied) | {start}
    while len(path) < length:
        r, c = path[-1]
        opts = [n for n in neighbors(r, c, rows, cols) if n in mask and n not in used]
        if not opts:
            break
        if len(path) >= 2 and rr.random() < bend_bias:
            prev = path[-2]
            straight = (2 * r - prev[0], 2 * c - prev[1])
            turns = [n for n in opts if n != straight]
            pick_from = turns if turns else opts
        else:
            pick_from = opts
        nxt = rr.choice(pick_from)
        path.append(nxt)
        used.add(nxt)
    return path if len(path) >= 2 else None


def placeable(path, occupied, rows, cols):
    for p in (path, list(reversed(path))):
        if len(p) < 2:
            continue
        d = tip_dir(p)
        if clear_exit(p[-1], d, occupied, rows, cols):
            return p
    return None


def grow_inward_from_tip(tip, tip_d, mask, occupied, rows, cols, rr, length, bend_bias=0.8):
    path = [tip]
    used = set(occupied) | {tip}
    opp = {"U": "D", "D": "U", "L": "R", "R": "L"}[tip_d]
    odr, odc = DIRS[opp]
    cur = (tip[0] + odr, tip[1] + odc)
    if not (0 <= cur[0] < rows and 0 <= cur[1] < cols) or cur not in mask or cur in used:
        opts = [n for n in neighbors(*tip, rows, cols) if n in mask and n not in used]
        if not opts:
            return None
        cur = rr.choice(opts)
    path.append(cur)
    used.add(cur)

    while len(path) < length:
        r, c = path[-1]
        opts = [n for n in neighbors(r, c, rows, cols) if n in mask and n not in used]
        if not opts:
            break
        if len(path) >= 2 and rr.random() < bend_bias:
            prev = path[-2]
            straight = (2 * r - prev[0], 2 * c - prev[1])
            turns = [n for n in opts if n != straight]
            pick_from = turns if turns else opts
        else:
            pick_from = opts
        nxt = rr.choice(pick_from)
        path.append(nxt)
        used.add(nxt)

    if len(path) < 2:
        return None
    body = list(reversed(path))
    if tip_dir(body) != tip_d:
        return None
    return body


def dense_fill(
    mask,
    rows,
    cols,
    seed,
    *,
    min_arrows,
    min_len=3,
    max_len=8,
    bend_bias=0.78,
    cover_target=0.9,
    attempts_per=28,
):
    rr = random.Random(seed)
    occupied: set = set()
    arrows: list = []
    soft_min = min(min_len, max_len)
    stall = 0

    while stall < 55:
        free = [c for c in mask if c not in occupied]
        if len(free) < soft_min:
            if soft_min > 2:
                soft_min -= 1
                stall = 0
                continue
            break

        rem_mask = mask - occupied
        boundary = [c for c in free if is_boundary(c, rem_mask, rows, cols)]
        if not boundary:
            boundary = free

        best = None
        best_score = -1
        for _ in range(attempts_per):
            tip = rr.choice(boundary)
            outs = outward_dirs(tip, rem_mask, rows, cols) or [d for d, _ in DIR_LIST]
            tip_d = rr.choice(outs)
            target = rr.randint(soft_min, min(max_len, max(soft_min, len(free))))
            body = grow_inward_from_tip(
                tip, tip_d, mask, occupied, rows, cols, rr, target, bend_bias
            )
            if body is None or len(body) < soft_min:
                start = rr.choice(free)
                raw = grow_bent_path(start, mask, occupied, rows, cols, rr, target, bend_bias)
                if not raw:
                    continue
                body = placeable(raw, occupied, rows, cols)
                if not body:
                    continue
            elif not clear_exit(body[-1], tip_dir(body), occupied, rows, cols):
                continue
            # Prefer longer exits / inward tips so edge arrows aren't free wins.
            d = tip_dir(body)
            head = body[-1]
            exit_run = 0
            dr, dc = DIRS[d]
            rr0, cc0 = head[0] + dr, head[1] + dc
            while 0 <= rr0 < rows and 0 <= cc0 < cols:
                exit_run += 1
                rr0 += dr
                cc0 += dc
            score = len(body) * 2 + min(exit_run, 8)
            outs = outward_dirs(tuple(head), mask, rows, cols)
            if d in outs and exit_run <= 1:
                score -= 4
            if score > best_score:
                best_score = score
                best = body

        if best is None:
            stall += 1
            if stall % 8 == 0 and soft_min > 2:
                soft_min -= 1
            continue

        stall = 0
        arrows.append(A(f"a{len(arrows) + 1}", best, len(arrows)))
        occupied.update(map(tuple, best))
        cover = len(occupied) / max(len(mask), 1)
        if len(arrows) >= min_arrows and cover >= cover_target:
            soft_min = max(2, soft_min - 1)
            if cover >= 0.96:
                break

    soft_min = 2
    for _ in range(160):
        free = [c for c in mask if c not in occupied]
        if len(free) < 2:
            break
        tip = rr.choice(free)
        rem = mask - occupied
        outs = outward_dirs(tip, rem, rows, cols) or [d for d, _ in DIR_LIST]
        want = rr.randint(2, max_len)
        body = grow_inward_from_tip(
            tip, rr.choice(outs), mask, occupied, rows, cols, rr, want, 0.7
        )
        if body is None:
            raw = grow_bent_path(
                rr.choice(free), mask, occupied, rows, cols, rr, min(4, max_len), 0.7
            )
            body = placeable(raw, occupied, rows, cols) if raw else None
        if (
            body is None
            or len(body) > max_len
            or not clear_exit(body[-1], tip_dir(body), occupied, rows, cols)
        ):
            continue
        arrows.append(A(f"a{len(arrows) + 1}", body, len(arrows)))
        occupied.update(map(tuple, body))

    if len(arrows) < max(8, int(min_arrows * 0.55)):
        return None
    return arrows


# ---------------------------------------------------------------------------
# Unique silhouette catalog (1000 distinct named shapes)
# ---------------------------------------------------------------------------


def heart_mask(rows, cols, fat=1.0, tip=1.0):
    m = set()
    cx = rows * 0.38
    cy = cols * 0.5
    rx = cols * 0.22 * fat
    ry = rows * 0.18 * fat
    m |= oval(rows, cols, cx, cy - rx * 0.85, rx, ry)
    m |= oval(rows, cols, cx, cy + rx * 0.85, rx, ry)
    for r in range(rows):
        for c in range(cols):
            # inverted triangle lower half
            t = (r - cx) / max(rows * 0.55 * tip, 1)
            half = max(0, (1 - t) * cols * 0.28 * fat)
            if t >= 0 and abs(c - cy) <= half:
                m.add((r, c))
    return m


def cat_mask(rows, cols, ear=1.0, head=1.0):
    m = oval(rows, cols, rows * 0.42, cols * 0.5, cols * 0.28 * head, rows * 0.28 * head)
    # ears
    for side in (-1, 1):
        for r in range(int(rows * 0.08), int(rows * 0.32)):
            for c in range(cols):
                ec = cols * 0.5 + side * cols * 0.22 * ear
                if abs(c - ec) + abs(r - rows * 0.12) <= rows * 0.12 * ear:
                    m.add((r, c))
    # body
    m |= oval(rows, cols, rows * 0.72, cols * 0.5, cols * 0.24, rows * 0.22)
    return m


def dog_mask(rows, cols, snout=1.0):
    m = oval(rows, cols, rows * 0.4, cols * 0.48, cols * 0.26, rows * 0.24)
    m |= oval(rows, cols, rows * 0.42, cols * 0.72, cols * 0.14 * snout, rows * 0.12 * snout)
    m |= oval(rows, cols, rows * 0.7, cols * 0.5, cols * 0.26, rows * 0.24)
    # floppy ear
    m |= oval(rows, cols, rows * 0.38, cols * 0.22, cols * 0.1, rows * 0.16)
    return m


def fish_mask(rows, cols, stretch=1.0):
    m = oval(rows, cols, rows * 0.5, cols * 0.42, cols * 0.32 * stretch, rows * 0.28)
    # tail
    for r in range(rows):
        for c in range(int(cols * 0.7), cols):
            mid = rows * 0.5
            if abs(r - mid) <= (c - cols * 0.7) * 0.9:
                m.add((r, c))
    return m


def bird_mask(rows, cols, wing=1.0):
    m = oval(rows, cols, rows * 0.45, cols * 0.45, cols * 0.18, rows * 0.16)
    m |= oval(rows, cols, rows * 0.42, cols * 0.28, cols * 0.22 * wing, rows * 0.1 * wing)
    m |= oval(rows, cols, rows * 0.42, cols * 0.62, cols * 0.22 * wing, rows * 0.1 * wing)
    m |= oval(rows, cols, rows * 0.55, cols * 0.55, cols * 0.08, rows * 0.12)  # beak
    return m


def rabbit_mask(rows, cols, ear_len=1.0):
    m = oval(rows, cols, rows * 0.55, cols * 0.5, cols * 0.22, rows * 0.22)
    for side in (-1, 1):
        m |= oval(
            rows,
            cols,
            rows * 0.22 * ear_len,
            cols * 0.5 + side * cols * 0.12,
            cols * 0.07,
            rows * 0.2 * ear_len,
        )
    m |= oval(rows, cols, rows * 0.78, cols * 0.5, cols * 0.2, rows * 0.16)
    return m


def elephant_mask(rows, cols, trunk=1.0):
    m = oval(rows, cols, rows * 0.4, cols * 0.5, cols * 0.28, rows * 0.24)
    m |= oval(rows, cols, rows * 0.65, cols * 0.5, cols * 0.3, rows * 0.26)
    # trunk
    for r in range(int(rows * 0.35), int(rows * 0.85 * trunk)):
        c = int(cols * 0.72)
        for dc in range(-2, 3):
            if 0 <= c + dc < cols:
                m.add((r, c + dc))
    # ear
    m |= oval(rows, cols, rows * 0.42, cols * 0.22, cols * 0.14, rows * 0.18)
    return m


def paw_mask(rows, cols, spread=1.0):
    m = set()
    cy = cols * 0.5
    for i, ox in enumerate((-0.32, -0.12, 0.12, 0.32)):
        m |= oval(rows, cols, rows * 0.22, cy + cols * ox * spread, cols * 0.1, rows * 0.1)
    m |= oval(rows, cols, rows * 0.58, cy, cols * 0.3, rows * 0.28)
    return m


def butterfly_mask(rows, cols, wing=1.0):
    m = oval(rows, cols, rows * 0.5, cols * 0.28, cols * 0.22 * wing, rows * 0.32 * wing)
    m |= oval(rows, cols, rows * 0.5, cols * 0.72, cols * 0.22 * wing, rows * 0.32 * wing)
    for r in range(int(rows * 0.15), int(rows * 0.85)):
        m.add((r, int(cols * 0.5)))
        m.add((r, int(cols * 0.5) - 1))
    return m


def trex_mask(rows, cols, neck=1.0):
    m = oval(rows, cols, rows * 0.28, cols * 0.7, cols * 0.16, rows * 0.14)
    m |= oval(rows, cols, rows * 0.45 * neck, cols * 0.55, cols * 0.12, rows * 0.18 * neck)
    m |= oval(rows, cols, rows * 0.55, cols * 0.4, cols * 0.26, rows * 0.22)
    m |= oval(rows, cols, rows * 0.55, cols * 0.18, cols * 0.18, rows * 0.1)  # tail
    for c in (int(cols * 0.32), int(cols * 0.48)):
        for r in range(int(rows * 0.65), int(rows * 0.9)):
            m.add((r, c))
            m.add((r, c + 1))
    return m


def house_mask(rows, cols, roof=1.0):
    m = rect(rows, cols, int(rows * 0.4), int(rows * 0.85), int(cols * 0.2), int(cols * 0.8))
    peak = rows * 0.15 / roof
    for r in range(int(peak), int(rows * 0.45)):
        half = (r - peak) / max(rows * 0.3, 1) * cols * 0.35
        for c in range(cols):
            if abs(c - cols * 0.5) <= half:
                m.add((r, c))
    return m


def cup_mask(rows, cols, steam=1.0):
    m = oval(rows, cols, rows * 0.55, cols * 0.45, cols * 0.28, rows * 0.32)
    m |= oval(rows, cols, rows * 0.55, cols * 0.78, cols * 0.1, rows * 0.14)  # handle
    m |= rect(rows, cols, int(rows * 0.82), int(rows * 0.92), int(cols * 0.25), int(cols * 0.65))
    if steam > 0.5:
        for c in (int(cols * 0.35), int(cols * 0.45), int(cols * 0.55)):
            for r in range(int(rows * 0.08), int(rows * 0.28)):
                m.add((r, c))
                m.add((r, c + 1))
    return m


def star_mask(rows, cols, points=5, scale=1.0):
    m = set()
    cx, cy = rows / 2, cols / 2
    R = min(rows, cols) * 0.42 * scale
    r = R * 0.42
    verts = []
    for i in range(points * 2):
        ang = -math.pi / 2 + i * math.pi / points
        rad = R if i % 2 == 0 else r
        verts.append((cx + rad * math.sin(ang), cy + rad * math.cos(ang)))
    # fill by point-in-polygon ray cast
    for rr in range(rows):
        for cc in range(cols):
            x, y = rr + 0.5, cc + 0.5
            inside = False
            j = len(verts) - 1
            for i in range(len(verts)):
                xi, yi = verts[i]
                xj, yj = verts[j]
                if ((yi > y) != (yj > y)) and (
                    x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi
                ):
                    inside = not inside
                j = i
            if inside:
                m.add((rr, cc))
    m |= diamond(rows, cols, int(cx), int(cy), int(min(rows, cols) * 0.18 * scale))
    return m


def moon_mask(rows, cols, bite=1.0):
    return oval(rows, cols, rows * 0.5, cols * 0.5, cols * 0.38, rows * 0.38) - oval(
        rows, cols, rows * 0.42, cols * 0.62 * bite, cols * 0.28, rows * 0.28
    )


def ring_mask(rows, cols, thick=0.45):
    outer = oval(rows, cols, rows * 0.5, cols * 0.5, cols * 0.4, rows * 0.4)
    inner = oval(rows, cols, rows * 0.5, cols * 0.5, cols * 0.4 * thick, rows * 0.4 * thick)
    return outer - inner


def tree_mask(rows, cols, canopy=1.0):
    m = oval(rows, cols, rows * 0.35, cols * 0.5, cols * 0.32 * canopy, rows * 0.28 * canopy)
    m |= rect(rows, cols, int(rows * 0.5), int(rows * 0.9), int(cols * 0.42), int(cols * 0.58))
    return m


def car_mask(rows, cols, stretch=1.0):
    m = oval(rows, cols, rows * 0.55, cols * 0.5, cols * 0.38 * stretch, rows * 0.18)
    m |= rect(rows, cols, int(rows * 0.32), int(rows * 0.55), int(cols * 0.28), int(cols * 0.72))
    m |= oval(rows, cols, rows * 0.72, cols * 0.28, cols * 0.1, rows * 0.08)
    m |= oval(rows, cols, rows * 0.72, cols * 0.72, cols * 0.1, rows * 0.08)
    return m


def apple_mask(rows, cols, leaf=1.0):
    m = oval(rows, cols, rows * 0.55, cols * 0.5, cols * 0.28, rows * 0.3)
    m |= oval(rows, cols, rows * 0.22, cols * 0.58, cols * 0.1 * leaf, rows * 0.08 * leaf)
    for r in range(int(rows * 0.08), int(rows * 0.28)):
        m.add((r, int(cols * 0.5)))
    return m


def letter_mask(rows, cols, ch: str, thick=0.18):
    """Block-letter silhouettes for unique clear glyphs."""
    m = set()
    # coarse 5x7 font-ish strokes
    glyphs = {
        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
        "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
        "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
        "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
        "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
        "G": ["01111", "10000", "10000", "10111", "10001", "10001", "01110"],
        "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
        "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
        "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
        "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
        "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
        "M": ["10001", "11011", "10101", "10001", "10001", "10001", "10001"],
        "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
        "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
        "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
        "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
        "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
        "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
        "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
        "V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"],
        "W": ["10001", "10001", "10001", "10001", "10101", "11011", "10001"],
        "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
        "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
        "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
        "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
    }
    g = glyphs.get(ch.upper())
    if not g:
        return oval(rows, cols, rows * 0.5, cols * 0.5, cols * 0.3, rows * 0.3)
    gh, gw = len(g), len(g[0])
    pad_r = int(rows * 0.12)
    pad_c = int(cols * 0.12)
    cell_h = max(1, (rows - 2 * pad_r) // gh)
    cell_w = max(1, (cols - 2 * pad_c) // gw)
    for i, row in enumerate(g):
        for j, bit in enumerate(row):
            if bit != "1":
                continue
            r0 = pad_r + i * cell_h
            c0 = pad_c + j * cell_w
            m |= rect(rows, cols, r0, r0 + cell_h, c0, c0 + cell_w)
    # thicken
    extra = set()
    for r, c in m:
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                nr, nc = r + dr, c + dc
                if 0 <= nr < rows and 0 <= nc < cols:
                    extra.add((nr, nc))
    return m | extra


def snail_mask(rows, cols):
    m = oval(rows, cols, rows * 0.55, cols * 0.55, cols * 0.28, rows * 0.28)
    m |= oval(rows, cols, rows * 0.55, cols * 0.55, cols * 0.16, rows * 0.16)
    m |= oval(rows, cols, rows * 0.7, cols * 0.28, cols * 0.22, rows * 0.1)
    return m


def cactus_mask(rows, cols):
    m = rect(rows, cols, int(rows * 0.2), int(rows * 0.88), int(cols * 0.42), int(cols * 0.58))
    m |= rect(rows, cols, int(rows * 0.35), int(rows * 0.5), int(cols * 0.18), int(cols * 0.45))
    m |= rect(rows, cols, int(rows * 0.28), int(rows * 0.45), int(cols * 0.55), int(cols * 0.78))
    m |= oval(rows, cols, rows * 0.28, cols * 0.5, cols * 0.1, rows * 0.08)
    return m


def guitar_mask(rows, cols):
    m = oval(rows, cols, rows * 0.65, cols * 0.5, cols * 0.28, rows * 0.22)
    m |= oval(rows, cols, rows * 0.48, cols * 0.5, cols * 0.18, rows * 0.12)
    m |= rect(rows, cols, int(rows * 0.08), int(rows * 0.48), int(cols * 0.46), int(cols * 0.54))
    return m


def balloon_mask(rows, cols):
    m = oval(rows, cols, rows * 0.38, cols * 0.5, cols * 0.28, rows * 0.3)
    for r in range(int(rows * 0.55), int(rows * 0.9)):
        m.add((r, int(cols * 0.5)))
        m.add((r, int(cols * 0.5) - 1))
    return m


def crown_mask(rows, cols):
    m = rect(rows, cols, int(rows * 0.45), int(rows * 0.75), int(cols * 0.15), int(cols * 0.85))
    for cx in (0.2, 0.5, 0.8):
        m |= diamond(rows, cols, int(rows * 0.28), int(cols * cx), int(rows * 0.14))
    return m


def cloud_mask(rows, cols):
    m = oval(rows, cols, rows * 0.5, cols * 0.35, cols * 0.22, rows * 0.18)
    m |= oval(rows, cols, rows * 0.42, cols * 0.5, cols * 0.28, rows * 0.2)
    m |= oval(rows, cols, rows * 0.5, cols * 0.68, cols * 0.22, rows * 0.18)
    return m


def key_mask(rows, cols):
    m = oval(rows, cols, rows * 0.3, cols * 0.5, cols * 0.18, rows * 0.16)
    m -= oval(rows, cols, rows * 0.3, cols * 0.5, cols * 0.08, rows * 0.07)
    m |= rect(rows, cols, int(rows * 0.35), int(rows * 0.85), int(cols * 0.46), int(cols * 0.54))
    m |= rect(rows, cols, int(rows * 0.7), int(rows * 0.78), int(cols * 0.54), int(cols * 0.68))
    return m


SHAPE_BUILDERS = [
    ("Heart", heart_mask),
    ("Cat", cat_mask),
    ("Dog", dog_mask),
    ("Fish", fish_mask),
    ("Bird", bird_mask),
    ("Rabbit", rabbit_mask),
    ("Elephant", elephant_mask),
    ("Paw", paw_mask),
    ("Butterfly", butterfly_mask),
    ("T-Rex", trex_mask),
    ("House", house_mask),
    ("Cup", cup_mask),
    ("Star", star_mask),
    ("Moon", moon_mask),
    ("Ring", ring_mask),
    ("Tree", tree_mask),
    ("Car", car_mask),
    ("Apple", apple_mask),
    ("Snail", snail_mask),
    ("Cactus", cactus_mask),
    ("Guitar", guitar_mask),
    ("Balloon", balloon_mask),
    ("Crown", crown_mask),
    ("Cloud", cloud_mask),
    ("Key", key_mask),
]


def build_unique_catalog(n: int = 1000):
    """Return list of (name, rows, cols, mask_cells_set, difficulty_hint)."""
    catalog = []
    used_names = set()

    def add(name, rows, cols, mask, diff="medium"):
        if name in used_names:
            return False
        if len(mask) < 260:
            return False
        used_names.add(name)
        catalog.append((name, rows, cols, mask, diff))
        return True

    # Fixed intros 1-5 use dedicated smaller masks later.
    # Fill 6.. with unique variants.
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    # Letter / digit glyphs — clear unique images
    for ch in letters:
        rows = cols = 32
        add(f"Letter {ch}", rows, cols, letter_mask(rows, cols, ch), "easy")

    # Parametric animal / object variants
    variant = 0
    while len(catalog) < n - 5:
        for base_name, fn in SHAPE_BUILDERS:
            if len(catalog) >= n - 5:
                break
            variant += 1
            rows = 32 + (variant % 4)
            cols = 30 + ((variant * 3) % 5)
            # Distinct morph parameters per variant
            kwargs_list = []
            if fn is heart_mask:
                kwargs_list = [{"fat": 0.75 + (variant % 7) * 0.08, "tip": 0.8 + (variant % 5) * 0.1}]
            elif fn is cat_mask:
                kwargs_list = [{"ear": 0.7 + (variant % 6) * 0.1, "head": 0.85 + (variant % 4) * 0.08}]
            elif fn is dog_mask:
                kwargs_list = [{"snout": 0.7 + (variant % 8) * 0.08}]
            elif fn is fish_mask:
                kwargs_list = [{"stretch": 0.8 + (variant % 7) * 0.07}]
            elif fn is bird_mask:
                kwargs_list = [{"wing": 0.75 + (variant % 6) * 0.1}]
            elif fn is rabbit_mask:
                kwargs_list = [{"ear_len": 0.75 + (variant % 7) * 0.08}]
            elif fn is elephant_mask:
                kwargs_list = [{"trunk": 0.8 + (variant % 5) * 0.08}]
            elif fn is paw_mask:
                kwargs_list = [{"spread": 0.75 + (variant % 6) * 0.1}]
            elif fn is butterfly_mask:
                kwargs_list = [{"wing": 0.75 + (variant % 6) * 0.1}]
            elif fn is trex_mask:
                kwargs_list = [{"neck": 0.8 + (variant % 5) * 0.08}]
            elif fn is house_mask:
                kwargs_list = [{"roof": 0.8 + (variant % 5) * 0.1}]
            elif fn is cup_mask:
                kwargs_list = [{"steam": 1.0 if variant % 2 == 0 else 0.0}]
            elif fn is star_mask:
                kwargs_list = [{"points": 5 + (variant % 3), "scale": 0.85 + (variant % 5) * 0.05}]
            elif fn is moon_mask:
                kwargs_list = [{"bite": 0.85 + (variant % 5) * 0.05}]
            elif fn is ring_mask:
                kwargs_list = [{"thick": 0.35 + (variant % 6) * 0.05}]
            elif fn is tree_mask:
                kwargs_list = [{"canopy": 0.8 + (variant % 6) * 0.08}]
            elif fn is car_mask:
                kwargs_list = [{"stretch": 0.85 + (variant % 6) * 0.06}]
            elif fn is apple_mask:
                kwargs_list = [{"leaf": 0.7 + (variant % 5) * 0.1}]
            else:
                kwargs_list = [{}]

            try:
                mask = fn(rows, cols, **kwargs_list[0])
            except TypeError:
                mask = fn(rows, cols)

            # Tiny unique bite / stamp so silhouettes never exact-duplicate.
            stamp = (variant * 17) % max(3, rows // 4)
            mask |= oval(rows, cols, stamp + 2, (variant * 13) % (cols - 4) + 2, 2.2, 2.2)
            if variant % 3 == 0:
                mask -= oval(rows, cols, rows - stamp - 3, cols - ((variant * 7) % (cols - 4)) - 2, 2.0, 2.0)

            name = f"{base_name} {variant}"
            diff = "easy" if len(catalog) < 250 else ("medium" if len(catalog) < 600 else "hard")
            add(name, rows, cols, mask, diff)

        # Extra composites when still short
        if len(catalog) < n - 5:
            rows = cols = 30
            a = SHAPE_BUILDERS[variant % len(SHAPE_BUILDERS)][1]
            b = SHAPE_BUILDERS[(variant * 3) % len(SHAPE_BUILDERS)][1]
            try:
                m = a(rows, cols) | {
                    (r, c + cols // 5) for r, c in b(rows, cols) if c + cols // 5 < cols
                }
            except TypeError:
                m = oval(rows, cols, 15, 15, 12, 12)
            add(f"Combo Form {variant}", rows, cols, m, "hard")

    return catalog[: n - 5]


def try_level(lid, name, diff, rows, cols, mask, min_arrows, max_len, seed0, soft=False):
    best = None
    seeds = 16 if soft else 28
    for i, seed in enumerate(range(seed0, seed0 + seeds)):
        # Pack denser with shorter strokes after a few misses to hit min_arrows.
        use_len = max_len
        if not soft and i >= 5:
            use_len = min(max_len, 5)
        if not soft and i >= 14:
            use_len = min(max_len, 4)
        arrows = dense_fill(
            mask,
            rows,
            cols,
            seed,
            min_arrows=min_arrows,
            min_len=2 if use_len <= 4 else 3,
            max_len=use_len,
            bend_bias=0.72,
            cover_target=0.8,
            attempts_per=32,
        )
        if not arrows:
            continue
        if any(len(a["path"]) > max_len for a in arrows):
            continue
        if not soft and len(arrows) < min_arrows:
            if best is None or len(arrows) > len(best):
                best = arrows
            continue
        if soft and (best is None or len(arrows) > len(best)):
            best = arrows
        try:
            if soft or len(arrows) >= min_arrows:
                return L(lid, name, diff, rows, cols, arrows)
        except AssertionError:
            continue
    if best is not None:
        need = 1 if soft else min_arrows
        if len(best) >= need:
            try:
                return L(lid, name, diff, rows, cols, best)
            except AssertionError:
                return None
    return None


def _worker(job):
    lid, name, diff, rows, cols, mask_list, min_arrows, max_len, seed0, soft = job
    mask = set(map(tuple, mask_list))
    t0 = time.time()
    lv = try_level(lid, name, diff, rows, cols, mask, min_arrows, max_len, seed0, soft=soft)
    dt = time.time() - t0
    if lv is None:
        return lid, None, dt, 0
    return lid, lv, dt, len(lv["arrows"])


INTROS = [
    (1, "Spark", "easy", 14, 14, lambda: oval(14, 14, 7, 7, 6, 6), 14, 10),
    (2, "Seed", "easy", 16, 16, lambda: oval(16, 16, 8, 8, 7, 7), 18, 10),
    (
        3,
        "Tiny Heart",
        "easy",
        18,
        18,
        lambda: heart_mask(18, 18, fat=0.9, tip=1.0),
        22,
        10,
    ),
    (4, "Smile", "easy", 18, 20, lambda: oval(18, 20, 9, 10, 8, 6.5), 22, 10),
    (
        5,
        "House",
        "easy",
        18,
        18,
        lambda: house_mask(18, 18, roof=1.0),
        22,
        10,
    ),
]


def save_all(levels):
    OUT.mkdir(parents=True, exist_ok=True)
    # Remove old level_*.json to avoid leftovers (keep folder).
    for p in OUT.glob("level_*.json"):
        p.unlink()

    meta = []
    for lv in sorted(levels, key=lambda x: x["id"]):
        fname = f"level_{lv['id']:04d}.json"
        (OUT / fname).write_text(json.dumps(lv, separators=(",", ":")), encoding="utf-8")
        meta.append(
            {
                "file": fname,
                "id": lv["id"],
                "name": lv["name"],
                "difficulty": lv["difficulty"],
                "rows": lv["rows"],
                "cols": lv["cols"],
                "hearts": lv["hearts"],
            }
        )
    (OUT / "manifest.json").write_text(
        json.dumps({"levels": meta}, indent=2), encoding="utf-8"
    )


def main():
    t_all = time.time()
    print("Building silhouette catalog…", flush=True)
    catalog = build_unique_catalog(1000)
    assert len(catalog) >= 995, len(catalog)

    jobs = []
    # Intros 1-5
    for lid, name, diff, rows, cols, mask_fn, min_a, max_l in INTROS:
        mask = mask_fn()
        jobs.append(
            (
                lid,
                name,
                diff,
                rows,
                cols,
                [list(c) for c in mask],
                min_a,
                max_l,
                lid * 1000 + 17,
                True,
            )
        )

    # Unique shapes for 6..1000
    for i, (name, rows, cols, mask, diff) in enumerate(catalog):
        lid = i + 6
        if lid > 1000:
            break
        jobs.append(
            (
                lid,
                name,
                diff,
                rows,
                cols,
                [list(c) for c in mask],
                40,
                8,
                lid * 7919 + 101,
                False,
            )
        )

    # Ensure exactly 1000 jobs
    jobs = [j for j in jobs if j[0] <= 1000]
    assert len(jobs) == 1000, len(jobs)
    names = [j[1] for j in jobs]
    assert len(names) == len(set(names)), "duplicate shape names"

    levels = {}
    workers = max(2, min(8, (Path("/").exists() and 8) or 4))
    print(f"Generating {len(jobs)} levels with {workers} workers…", flush=True)

    failed = []
    with ProcessPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(_worker, job): job[0] for job in jobs}
        done = 0
        for fut in as_completed(futs):
            lid, lv, dt, n = fut.result()
            done += 1
            if lv is None:
                failed.append(lid)
                print(f"[{done}/1000] L{lid} FAILED ({dt:.1f}s)", flush=True)
            else:
                levels[lid] = lv
                if done % 25 == 0 or lid <= 10 or n < 40 and lid >= 6:
                    print(
                        f"[{done}/1000] L{lid} {lv['name']}: {n} arrows ({dt:.1f}s)",
                        flush=True,
                    )

    # Retry failures serially with different seeds; keep ≥40 for lid≥6
    for lid in list(failed):
        job = next(j for j in jobs if j[0] == lid)
        print(f"Retry L{lid}…", flush=True)
        ok = None
        for bump in range(12):
            j = list(job)
            j[6] = 40  # keep target
            j[8] = job[8] + 77 + bump * 131
            j[9] = False
            _, lv, dt, n = _worker(tuple(j))
            if lv and n >= 40:
                ok = lv
                break
            if lv and n >= 38 and bump >= 10:
                ok = lv
                break
        if ok is None:
            raise SystemExit(f"Could not generate level {lid}")
        levels[lid] = ok
        failed.remove(lid)
        print(f"  recovered L{lid} with {len(ok['arrows'])} arrows", flush=True)

    assert len(levels) == 1000
    # Hard check 6+
    for lid, lv in levels.items():
        if lid >= 6:
            assert len(lv["arrows"]) >= 38, (lid, len(lv["arrows"]))
            assert all(len(a["path"]) <= 8 for a in lv["arrows"]), lid

    ordered = [levels[i] for i in range(1, 1001)]
    save_all(ordered)
    print(f"\nSaved 1000 levels in {time.time() - t_all:.1f}s", flush=True)
    # Sample summary
    for lid in (1, 5, 6, 50, 500, 1000):
        lv = levels[lid]
        avg = sum(len(a["path"]) for a in lv["arrows"]) / len(lv["arrows"])
        print(
            f"L{lid}: {lv['name']} n={len(lv['arrows'])} avgLen={avg:.1f} {lv['rows']}x{lv['cols']}",
            flush=True,
        )


if __name__ == "__main__":
    main()
