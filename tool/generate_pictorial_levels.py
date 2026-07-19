#!/usr/bin/env python3
"""Dense pictorial levels: 30+ long bent arrows packed into recognizable silhouettes."""
from __future__ import annotations

import json
import random
from pathlib import Path

out = Path("assets/levels")
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


def bends(path: list) -> int:
    n = 0
    for i in range(2, len(path)):
        d1 = (path[i - 1][0] - path[i - 2][0], path[i - 1][1] - path[i - 2][1])
        d2 = (path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1])
        if d1 != d2:
            n += 1
    return n


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


def can_escape(arrow, arrows, rows, cols) -> bool:
    occ = {
        (c[0], c[1])
        for a in arrows
        if a["id"] != arrow["id"]
        for c in a["path"]
    }
    return clear_exit(arrow["path"][-1], arrow["direction"], occ, rows, cols)


def verify_constructive(arrows, rows, cols) -> bool:
    """O(n²) check: keep removing an escapeable arrow until empty."""
    remaining = list(arrows)
    while remaining:
        found = None
        for a in reversed(remaining):
            if can_escape(a, remaining, rows, cols):
                found = a
                break
        if found is None:
            return False
        remaining = [x for x in remaining if x["id"] != found["id"]]
    return True


def validate(lv: dict) -> str | None:
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
    if not verify_constructive(lv["arrows"], lv["rows"], lv["cols"]):
        return "unsolvable"
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
    err = validate(lv)
    if err:
        raise AssertionError(f"L{lid} {err}")
    return lv


def oval_mask(rows, cols, cx, cy, rx, ry):
    m = set()
    for r in range(rows):
        for c in range(cols):
            if ((r - cx) / max(ry, 0.01)) ** 2 + ((c - cy) / max(rx, 0.01)) ** 2 <= 1.0:
                m.add((r, c))
    return m


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


def is_boundary(cell, mask, rows, cols) -> bool:
    r, c = cell
    for nr, nc in neighbors(r, c, rows, cols):
        if (nr, nc) not in mask:
            return True
    # board edge
    return r == 0 or c == 0 or r == rows - 1 or c == cols - 1


def outward_dirs(cell, mask, rows, cols):
    """Directions whose first step leaves the silhouette (or board)."""
    r, c = cell
    out = []
    for name, (dr, dc) in DIR_LIST:
        nr, nc = r + dr, c + dc
        if not (0 <= nr < rows and 0 <= nc < cols) or (nr, nc) not in mask:
            out.append(name)
    return out


def grow_inward_from_tip(
    tip, tip_d, mask, occupied, rows, cols, rr, length, bend_bias=0.8
):
    """Grow body opposite to tip direction into free mask cells."""
    path = [tip]  # will reverse later: tip should be last
    used = set(occupied) | {tip}
    # first body step: opposite of tip
    opp = {"U": "D", "D": "U", "L": "R", "R": "L"}[tip_d]
    odr, odc = DIRS[opp]
    cur = (tip[0] + odr, tip[1] + odc)
    if not (0 <= cur[0] < rows and 0 <= cur[1] < cols):
        return None
    if cur not in mask or cur in used:
        # try any inward neighbor
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
    # path currently tip → inland; reverse so inland → tip
    body = list(reversed(path))
    # ensure tip_dir matches tip_d
    if tip_dir(body) != tip_d:
        # force: last two cells must form tip_d — rebuild tip
        return None
    return body


def dense_fill(
    mask,
    rows,
    cols,
    seed,
    *,
    min_arrows,
    min_len=6,
    max_len=16,
    bend_bias=0.8,
    cover_target=0.92,
    attempts_per=80,
):
    rr = random.Random(seed)
    occupied: set = set()
    arrows: list = []
    soft_min = min(min_len, 5)
    stall = 0

    while stall < 80:
        free = [c for c in mask if c not in occupied]
        if len(free) < soft_min:
            if soft_min > 3:
                soft_min -= 1
                stall = 0
                continue
            break

        boundary = [
            c
            for c in free
            if is_boundary(c, mask - occupied, rows, cols)
            or any(
                not (0 <= n[0] < rows and 0 <= n[1] < cols) or n not in mask
                for n in neighbors(*c, rows, cols)
            )
        ]
        if not boundary:
            boundary = free

        best = None
        best_score = -1

        # Prefer boundary tips pointing outward of silhouette
        for _ in range(attempts_per):
            tip = rr.choice(boundary)
            outs = outward_dirs(tip, mask - occupied, rows, cols)
            if not outs:
                # fallback: any tip dir that clear_exits
                outs = [d for d, _ in DIR_LIST]
            tip_d = rr.choice(outs)
            target = rr.randint(soft_min, min(max_len, max(soft_min, len(free))))
            body = grow_inward_from_tip(
                tip, tip_d, mask, occupied, rows, cols, rr, target, bend_bias
            )
            if body is None or len(body) < soft_min:
                # fallback to old grow
                start = rr.choice(free)
                raw = grow_bent_path(
                    start, mask, occupied, rows, cols, rr, target, bend_bias
                )
                if not raw:
                    continue
                body = placeable(raw, occupied, rows, cols)
                if not body:
                    continue
            else:
                if not clear_exit(body[-1], tip_dir(body), occupied, rows, cols):
                    continue
            score = len(body) * 2 + bends(body) * 6
            # bonus if tip leaves silhouette immediately
            if tip_dir(body) in outward_dirs(tuple(body[-1]), mask, rows, cols):
                score += 8
            if score > best_score:
                best_score = score
                best = body

        if best is None:
            stall += 1
            if stall % 10 == 0 and soft_min > 3:
                soft_min -= 1
            continue

        stall = 0
        arrows.append(A(f"a{len(arrows) + 1}", best, len(arrows)))
        occupied.update(map(tuple, best))

        cover = len(occupied) / max(len(mask), 1)
        if len(arrows) >= min_arrows and cover >= cover_target:
            soft_min = max(3, soft_min - 1)
            if cover >= 0.97:
                break

    # Sweep leftover islands with short wires for image density.
    soft_min = 3
    for _ in range(200):
        free = [c for c in mask if c not in occupied]
        if len(free) < 3:
            break
        tip = rr.choice(free)
        outs = outward_dirs(tip, mask - occupied, rows, cols) or [d for d, _ in DIR_LIST]
        body = grow_inward_from_tip(
            tip, rr.choice(outs), mask, occupied, rows, cols, rr, rr.randint(3, 7), 0.7
        )
        if body is None:
            raw = grow_bent_path(rr.choice(free), mask, occupied, rows, cols, rr, 5, 0.7)
            body = placeable(raw, occupied, rows, cols) if raw else None
        if body is None or not clear_exit(body[-1], tip_dir(body), occupied, rows, cols):
            continue
        arrows.append(A(f"a{len(arrows) + 1}", body, len(arrows)))
        occupied.update(map(tuple, body))

    if len(arrows) < max(6, int(min_arrows * 0.35)):
        return None
    return arrows


def try_dense(lid, name, diff, rows, cols, mask, min_arrows, seed0, **kwargs):
    best = None
    for seed in range(seed0, seed0 + 35):
        arrows = dense_fill(mask, rows, cols, seed, min_arrows=min_arrows, **kwargs)
        if not arrows:
            continue
        try:
            lv = L(lid, name, diff, rows, cols, arrows)
        except AssertionError:
            continue
        if best is None or len(arrows) > len(best["arrows"]):
            best = lv
            if len(arrows) >= min_arrows:
                return best
    return best


def save_levels(levels):
    files = []
    for lv in sorted(levels, key=lambda x: x["id"]):
        fname = f"level_{lv['id']:02d}.json"
        files.append(fname)
        (out / fname).write_text(json.dumps(lv, indent=2))
    (out / "manifest.json").write_text(json.dumps({"levels": files}, indent=2))


def paw_mask(rows=28, cols=26):
    """Four toes + large central pad — screenshot style, ~400 cells."""
    m = set()
    for cx, cy in [(4, 5), (4, 10), (4, 15), (5, 20)]:
        m |= oval_mask(rows, cols, cx, cy, 3.0, 3.1)
    m |= oval_mask(rows, cols, 16, 13, 9.5, 8.5)
    return m


def cup_mask(rows=30, cols=22):
    m = oval_mask(rows, cols, 17, 10, 8.0, 9.0)
    for c in (6, 10, 14):
        for r in range(0, 8):
            m.add((r, c))
            if c + 1 < cols:
                m.add((r, c + 1))
            if c > 0:
                m.add((r, c - 1))
    for r in (26, 27, 28):
        for c in range(3, 18):
            m.add((r, c))
    m |= oval_mask(rows, cols, 17, 18, 2.8, 4.5)
    return m


def butterfly_mask(rows=26, cols=28):
    m = oval_mask(rows, cols, 13, 6, 5.5, 9.5)
    m |= oval_mask(rows, cols, 13, 21, 5.5, 9.5)
    for r in range(3, 23):
        m.add((r, 13))
        m.add((r, 14))
        if r % 2 == 0:
            m.add((r, 12))
            m.add((r, 15))
    m |= {(1, 10), (0, 9), (1, 9), (2, 10), (1, 17), (0, 18), (1, 18), (2, 17)}
    return m


def dino_mask(rows=28, cols=30):
    m = oval_mask(rows, cols, 6, 22, 5.5, 4.0)
    m |= oval_mask(rows, cols, 14, 15, 8.0, 7.0)
    m |= oval_mask(rows, cols, 15, 5, 7.0, 4.0)
    for r in range(18, 27):
        for c in (10, 11, 12, 16, 17, 18):
            m.add((r, c))
            m.add((r, c + 1))
    return m


def main():
    levels = []

    for lid, name, rows, cols, mask, n in [
        (1, "Spark", 14, 14, oval_mask(14, 14, 7, 7, 6, 6), 18),
        (2, "Seed", 16, 16, oval_mask(16, 16, 8, 8, 7, 7), 22),
        (3, "Tiny Heart", 18, 18, oval_mask(18, 18, 6, 6, 5, 5) | oval_mask(18, 18, 6, 11, 5, 5) | {(r, c) for r in range(8, 16) for c in range(18) if abs(c - 8.5) <= max(0, (15 - r) * 0.85)}, 28),
        (4, "Smile", 18, 20, oval_mask(18, 20, 9, 10, 8, 6.5), 28),
        (5, "House", 18, 18, {(r, c) for r in range(6, 16) for c in range(4, 14)} | {(r, c) for r in range(2, 7) for c in range(4, 14) if abs(c - 8.5) + r <= 10}, 28),
    ]:
        lv = try_dense(lid, name, "easy", rows, cols, mask, n, lid * 1000, min_len=4, max_len=11, cover_target=0.9, attempts_per=50)
        assert lv, f"failed {lid}"
        levels.append(lv)
        save_levels(levels)
        print(f"L{lid:02d} {name}: {len(lv['arrows'])} arrows", flush=True)

    signature = [
        (6, "Paw Print", "easy", 28, 26, paw_mask(), 36),
        (7, "Coffee Cup", "easy", 30, 22, cup_mask(), 36),
        (8, "Butterfly", "medium", 26, 28, butterfly_mask(), 38),
        (9, "T-Rex", "medium", 28, 30, dino_mask(), 38),
        (10, "Star Burst", "easy", 24, 24, {(r, c) for r in range(24) for c in range(24) if abs(r - 12) + abs(c - 12) <= 11 or ((abs(r - 12) <= 1 or abs(c - 12) <= 1) and abs(r - 12) + abs(c - 12) <= 14)}, 34),
    ]
    for lid, name, diff, rows, cols, mask, n in signature:
        print(f"building {name} mask={len(mask)}...", flush=True)
        lv = try_dense(lid, name, diff, rows, cols, mask, n, lid * 2000, min_len=5, max_len=12, bend_bias=0.85, cover_target=0.92, attempts_per=55)
        if lv is None or (lid != 10 and len(lv["arrows"]) < 28) or (lid == 10 and len(lv["arrows"]) < 24):
            lv = try_dense(lid, name, diff, rows, cols, mask, n - 6, lid * 2000 + 77, min_len=4, max_len=11, bend_bias=0.82, cover_target=0.9, attempts_per=60)
        assert lv and len(lv["arrows"]) >= (24 if lid == 10 else 28), f"failed signature {lid} n={None if not lv else len(lv['arrows'])}"
        avg_len = sum(len(a["path"]) for a in lv["arrows"]) / len(lv["arrows"])
        avg_bend = sum(bends(a["path"]) for a in lv["arrows"]) / len(lv["arrows"])
        levels.append(lv)
        save_levels(levels)
        print(f"L{lid:02d} {name}: {len(lv['arrows'])} arrows avgLen={avg_len:.1f} avgBend={avg_bend:.1f}", flush=True)

    more = [
        (11, "Ring Gate", "medium", 22, 22, oval_mask(22, 22, 11, 11, 10, 10) - oval_mask(22, 22, 11, 11, 5, 5), 36),
        (12, "Fish Swim", "medium", 20, 28, oval_mask(20, 28, 10, 13, 11, 7) | {(r, c) for r in range(6, 14) for c in range(24, 28)}, 36),
        (13, "Bean Oval", "medium", 22, 16, oval_mask(22, 16, 11, 8, 6.5, 10), 34),
        (14, "Moon Arc", "medium", 22, 22, oval_mask(22, 22, 11, 11, 10, 10) - oval_mask(22, 22, 10, 13, 7.5, 7.5), 32),
        (15, "Diamond", "medium", 22, 22, {(r, c) for r in range(22) for c in range(22) if abs(r - 11) + abs(c - 11) <= 11}, 38),
        (16, "Capsule", "medium", 14, 28, {(r, c) for r in range(2, 12) for c in range(2, 26)}, 36),
        (17, "Paw Duo", "medium", 28, 26, paw_mask(), 40),
        (18, "Cup Steam", "medium", 30, 22, cup_mask(), 38),
        (19, "Wing Span", "medium", 26, 28, butterfly_mask(), 38),
        (20, "Orbit Ring", "medium", 24, 24, oval_mask(24, 24, 12, 12, 11, 11) - oval_mask(24, 24, 12, 12, 6, 6), 38),
        (21, "Grand Paw", "hard", 30, 28, paw_mask(30, 28), 45),
        (22, "Cafe Cup", "hard", 32, 24, cup_mask(32, 24), 44),
        (23, "Queen Wing", "hard", 28, 30, butterfly_mask(28, 30), 44),
        (24, "Saur Trail", "hard", 30, 32, dino_mask(30, 32), 46),
        (25, "Bow Knot", "hard", 26, 30, butterfly_mask(26, 30), 42),
        (26, "Mega Ring", "hard", 26, 26, oval_mask(26, 26, 13, 13, 12, 12) - oval_mask(26, 26, 13, 13, 6.5, 6.5), 42),
        (27, "Twin Fish", "hard", 22, 30, oval_mask(22, 30, 11, 11, 9, 7) | oval_mask(22, 30, 11, 21, 6, 5), 42),
        (28, "Crystal", "hard", 24, 24, {(r, c) for r in range(24) for c in range(24) if 3 <= abs(r - 12) + abs(c - 12) <= 12}, 40),
        (29, "Bloom", "hard", 26, 26, oval_mask(26, 26, 13, 13, 11, 11) | {(r, 13) for r in range(26)} | {(13, c) for c in range(26)}, 44),
        (30, "Final Form", "hard", 28, 28, oval_mask(28, 28, 14, 14, 13, 13) - oval_mask(28, 28, 14, 14, 4, 4), 48),
    ]

    for lid, name, diff, rows, cols, mask, n in more:
        print(f"building {name} mask={len(mask)}...", flush=True)
        lv = try_dense(lid, name, diff, rows, cols, mask, n, lid * 3000, min_len=5, max_len=12 if diff == "hard" else 11, bend_bias=0.85, cover_target=0.92, attempts_per=50)
        if lv is None or len(lv["arrows"]) < 20:
            lv = try_dense(lid, name, diff, rows, cols, mask, max(22, n // 2), lid * 3000 + 500, min_len=4, max_len=10, bend_bias=0.8, cover_target=0.88, attempts_per=60)
        assert lv, f"failed {lid} {name}"
        levels.append(lv)
        save_levels(levels)
        print(f"L{lid:02d} {name}: {len(lv['arrows'])} arrows", flush=True)

    levels.sort(key=lambda x: x["id"])
    assert [x["id"] for x in levels] == list(range(1, 31))
    save_levels(levels)

    print("\n=== SUMMARY ===", flush=True)
    for lv in levels:
        n = len(lv["arrows"])
        cells = sum(len(a["path"]) for a in lv["arrows"])
        avg_l = cells / n
        avg_b = sum(bends(a["path"]) for a in lv["arrows"]) / n
        print(f"{lv['id']:02d} {lv['name']:12s} {n:3d} arrows  avgLen={avg_l:4.1f} avgBend={avg_b:3.1f}  {lv['rows']}x{lv['cols']}", flush=True)


if __name__ == "__main__":
    main()
