#!/usr/bin/env python3
"""Generate the single showcase level used by the in-app marketing demo.

Unlike the 1000 shipped levels this one is tuned for filming:

* the arrows cover 100% of the board — every single cell belongs to an arrow,
  so the white board card starts completely packed with colour
* every arrow is 5..10 cells long
* no picture or pattern, just a dense random weave

It runs in two phases.

1. Tile the whole grid with snakes of length 5..10 (an exact cover). Growth is
   Warnsdorff-style — always step into the most cramped cell — and a candidate
   is rejected if it would strand a pocket too small to hold an arrow. A few
   snakes get ripped out and retried whenever the fill stalls.
2. Pick which end of each snake is the arrow head. Removing arrows only ever
   frees cells, so a removal order is searched greedily: repeatedly take any
   snake that has an end whose exit lane is clear of what is left. The order
   that falls out is proof the level is solvable, and because greedy play can
   never spoil a solvable board, the demo hand's "tap anything that can escape"
   rule clears it too.

Usage:
    python3 tool/generate_demo_level.py [--rows 16] [--cols 16]
"""
from __future__ import annotations

import argparse
import json
import random
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "levels" / "demo_level.json"

DIRS = {"U": (-1, 0), "D": (1, 0), "L": (0, -1), "R": (0, 1)}
STEPS = [(-1, 0), (1, 0), (0, -1), (0, 1)]
CODE_BY_DELTA = {(-1, 0): "U", (1, 0): "D", (0, -1): "L", (0, 1): "R"}

MIN_LEN = 5
MAX_LEN = 10
PALETTE_SIZE = 6


def tip_dir(path) -> str:
    (ar, ac), (br, bc) = path[-2], path[-1]
    return CODE_BY_DELTA[(br - ar, bc - ac)]


def ray_is_clear(head, code: str, blocked: set, rows: int, cols: int) -> bool:
    """True when nothing stands between the head and the rim of the board."""
    dr, dc = DIRS[code]
    r, c = head[0] + dr, head[1] + dc
    while 0 <= r < rows and 0 <= c < cols:
        if (r, c) in blocked:
            return False
        r += dr
        c += dc
    return True


def neighbours(cell, rows: int, cols: int):
    r, c = cell
    for dr, dc in STEPS:
        nr, nc = r + dr, c + dc
        if 0 <= nr < rows and 0 <= nc < cols:
            yield (nr, nc)


# --- Phase 1: tile the whole grid ---


def _extend(rng, taken: set, rows: int, cols: int, path: list, used: set, length: int):
    """Walk forward from path[-1] until the snake is `length` long or boxed in."""
    while len(path) < length:
        current = path[-1]
        options = [
            n
            for n in neighbours(current, rows, cols)
            if n not in taken and n not in used
        ]
        if not options:
            return

        def onward(cell):
            return sum(
                1
                for n in neighbours(cell, rows, cols)
                if n not in taken and n not in used
            )

        degrees = [onward(o) for o in options]
        fewest = min(degrees)

        straight = None
        if len(path) >= 2:
            (pr, pc), (cr, cc) = path[-2], current
            straight = (cr + (cr - pr), cc + (cc - pc))

        # Warnsdorff: heavily favour the most cramped option so open space
        # stays connected, with a nudge towards carrying straight on.
        weights = [
            (10 if d == fewest else 1) * (3 if o == straight else 1)
            for o, d in zip(options, degrees)
        ]
        path.append(rng.choices(options, weights=weights, k=1)[0])
        used.add(path[-1])


def grow(rng, taken: set, rows: int, cols: int, anchor, length: int):
    """Self-avoiding walk *through* the anchor — it may end up anywhere along
    the snake, which is far more forgiving than forcing it to be an endpoint."""
    path = [anchor]
    used = {anchor}
    _extend(rng, taken, rows, cols, path, used, length)
    if len(path) < length:
        # Boxed in one way; keep growing out of the anchor's other side.
        path.reverse()
        _extend(rng, taken, rows, cols, path, used, length)
    return path if len(path) == length else None


def leaves_no_pocket(taken: set, rows: int, cols: int) -> bool:
    """Every remaining empty region must still be big enough for an arrow."""
    seen: set = set()
    for r in range(rows):
        for c in range(cols):
            cell = (r, c)
            if cell in taken or cell in seen:
                continue
            size = 0
            queue = deque([cell])
            seen.add(cell)
            while queue:
                for n in neighbours(queue.popleft(), rows, cols):
                    if n not in taken and n not in seen:
                        seen.add(n)
                        queue.append(n)
                size += 1
            if size < MIN_LEN:
                return False
    return True


def next_snake(rng, taken: set, rows: int, cols: int, tries: int):
    free = [(r, c) for r in range(rows) for c in range(cols) if (r, c) not in taken]
    remaining = len(free)
    lengths = [
        n
        for n in range(MIN_LEN, MAX_LEN + 1)
        if n <= remaining and (remaining - n == 0 or remaining - n >= MIN_LEN)
    ]
    if not lengths:
        return None

    def pressure(cell):
        return sum(1 for n in neighbours(cell, rows, cols) if n not in taken)

    # Most constrained cell first — the classic exact-cover heuristic.
    free.sort(key=lambda cell: (pressure(cell), rng.random()))

    for anchor in free[:4]:
        for _ in range(tries):
            length = rng.choices(lengths, weights=range(1, len(lengths) + 1))[0]
            path = grow(rng, taken, rows, cols, anchor, length)
            if path is None:
                continue
            if not leaves_no_pocket(taken | set(path), rows, cols):
                continue
            return path
    return None


def tile(rows: int, cols: int, seed: int, tries: int, budget: int):
    """Cover every cell with snakes, backtracking whenever the fill stalls."""
    rng = random.Random(seed)
    taken: set = set()
    snakes: list[list[tuple[int, int]]] = []
    total = rows * cols
    stalls = 0

    while len(taken) < total:
        snake = next_snake(rng, taken, rows, cols, tries)
        if snake is not None:
            snakes.append(snake)
            taken.update(snake)
            continue

        stalls += 1
        if stalls > budget or not snakes:
            return None
        for _ in range(min(len(snakes), rng.randint(1, 4))):
            taken.difference_update(snakes.pop())

    return snakes


# --- Phase 2: choose heads and prove a solve order ---


def orient(snakes, rows: int, cols: int, rng):
    """Greedily peel the board, picking whichever end of a snake can leave.

    Returns the snakes in removal order, already flipped so path[-1] is the
    head, or None when the tiling cannot be unpicked.
    """
    remaining = {i: list(path) for i, path in enumerate(snakes)}
    cells = {i: set(path) for i, path in enumerate(snakes)}
    removal = []

    while remaining:
        blocked_all = set()
        for path in remaining.values():
            blocked_all.update(path)

        candidates = []
        for i, path in remaining.items():
            others = blocked_all - cells[i]
            for oriented in (path, path[::-1]):
                if ray_is_clear(oriented[-1], tip_dir(oriented), others, rows, cols):
                    candidates.append((i, oriented))
                    break
        if not candidates:
            return None

        i, oriented = rng.choice(candidates)
        removal.append(oriented)
        del remaining[i]

    return removal


def assign_colors(paths, rows: int, cols: int):
    """Greedy colouring so touching arrows never share a palette entry."""
    owner = {cell: i for i, path in enumerate(paths) for cell in path}
    colors = [0] * len(paths)
    for i, path in enumerate(paths):
        used = set()
        for cell in path:
            for n in neighbours(cell, rows, cols):
                other = owner.get(n)
                if other is not None and other != i:
                    used.add(colors[other])
        colors[i] = next(
            (k for k in range(PALETTE_SIZE) if k not in used), i % PALETTE_SIZE
        )
    return colors


def can_escape(arrow: dict, arrows: list, rows: int, cols: int) -> bool:
    blocked = {
        (c[0], c[1]) for a in arrows if a["id"] != arrow["id"] for c in a["path"]
    }
    return ray_is_clear(arrow["path"][-1], arrow["direction"], blocked, rows, cols)


def greedy_solves(arrows: list, rows: int, cols: int) -> bool:
    """Exactly the rule the demo hand follows in-app."""
    remaining = list(arrows)
    while remaining:
        found = next(
            (a for a in remaining if can_escape(a, remaining, rows, cols)), None
        )
        if found is None:
            return False
        remaining = [a for a in remaining if a["id"] != found["id"]]
    return True


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rows", type=int, default=16)
    parser.add_argument("--cols", type=int, default=16)
    parser.add_argument("--id", type=int, default=999)
    parser.add_argument("--name", default="Prism Rush")
    parser.add_argument("--seeds", type=int, default=200)
    parser.add_argument("--tries", type=int, default=60)
    parser.add_argument("--budget", type=int, default=120)
    parser.add_argument("--out", default=str(OUT))
    args = parser.parse_args()

    ordered = None
    seed = 0
    for seed in range(args.seeds):
        snakes = tile(args.rows, args.cols, seed, args.tries, args.budget)
        if not snakes:
            continue
        ordered = orient(snakes, args.rows, args.cols, random.Random(seed))
        if ordered:
            break
    if not ordered:
        raise SystemExit("could not build a full board — try another size")

    # `ordered` is the removal order; the demo hand rediscovers it greedily, so
    # shuffle the file order and let it roam instead of walking top to bottom.
    colors = assign_colors(ordered, args.rows, args.cols)
    index = list(range(len(ordered)))
    random.Random(seed).shuffle(index)
    arrows = [
        {
            "id": f"a{n + 1}",
            "path": [[r, c] for r, c in ordered[i]],
            "direction": tip_dir(ordered[i]),
            "colorIndex": colors[i],
        }
        for n, i in enumerate(index)
    ]

    total = args.rows * args.cols
    covered = len({tuple(c) for a in arrows for c in a["path"]})
    if covered != total:
        raise SystemExit(f"board not fully covered: {covered}/{total}")
    if not greedy_solves(arrows, args.rows, args.cols):
        raise SystemExit("generated level is not greedy-solvable")

    level = {
        "id": args.id,
        "name": args.name,
        "difficulty": "hard",
        "rows": args.rows,
        "cols": args.cols,
        "hearts": 3,
        "arrows": arrows,
    }
    Path(args.out).write_text(json.dumps(level, separators=(",", ":")) + "\n")

    lengths = [len(a["path"]) for a in arrows]
    print(
        f"{Path(args.out).name}: {args.rows}x{args.cols}, seed {seed}, "
        f"{len(arrows)} arrows, lengths {min(lengths)}-{max(lengths)}, "
        f"{covered}/{total} cells covered (100%)"
    )


if __name__ == "__main__":
    main()
