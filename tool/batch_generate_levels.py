#!/usr/bin/env python3
"""Batch-generate unique arrow-shape levels.

Rules:
  - Levels 1–5: softer intros
  - Levels 6–1000: ≥40 arrows (floor only — use as many as the silhouette needs),
    max path length 8, unique clear shape names, no repeats
  - Run in batches of 100: generate → validate → next batch until 1000
"""
from __future__ import annotations

import argparse
import json
import math
import random
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

# Reuse engine + catalog from the big generator module.
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool"))

import generate_1000_levels as g  # noqa: E402

OUT = ROOT / "assets" / "levels"
BATCH = 100
TOTAL = 1000


def dense_fill_full(
    mask,
    rows,
    cols,
    seed,
    *,
    min_arrows,
    max_len=8,
    bend_bias=0.74,
    attempts_per=28,
):
    """Pack silhouette almost completely. Arrow count has no upper cap (floor=min_arrows)."""
    rr = random.Random(seed)
    occupied: set = set()
    arrows: list = []
    soft_min = 3
    stall = 0

    while stall < 70:
        free = [c for c in mask if c not in occupied]
        if len(free) < soft_min:
            if soft_min > 2:
                soft_min -= 1
                stall = 0
                continue
            break

        rem_mask = mask - occupied
        boundary = [c for c in free if g.is_boundary(c, rem_mask, rows, cols)] or free
        best = None
        best_score = -1
        for _ in range(attempts_per):
            tip = rr.choice(boundary)
            outs = g.outward_dirs(tip, rem_mask, rows, cols) or [d for d, _ in g.DIR_LIST]
            tip_d = rr.choice(outs)
            target = rr.randint(soft_min, min(max_len, max(soft_min, len(free))))
            body = g.grow_inward_from_tip(
                tip, tip_d, mask, occupied, rows, cols, rr, target, bend_bias
            )
            if body is None or len(body) < soft_min:
                raw = g.grow_bent_path(
                    rr.choice(free), mask, occupied, rows, cols, rr, target, bend_bias
                )
                if not raw:
                    continue
                body = g.placeable(raw, occupied, rows, cols)
                if not body:
                    continue
            elif not g.clear_exit(body[-1], g.tip_dir(body), occupied, rows, cols):
                continue
            if len(body) > max_len:
                continue
            score = len(body) + (4 if tip_d in outs else 0)
            if score > best_score:
                best_score = score
                best = body

        if best is None:
            stall += 1
            if stall % 8 == 0 and soft_min > 2:
                soft_min -= 1
            continue

        stall = 0
        arrows.append(g.A(f"a{len(arrows) + 1}", best, len(arrows)))
        occupied.update(map(tuple, best))
        cover = len(occupied) / max(len(mask), 1)
        # Keep packing until silhouette is nearly full — more arrows = clearer image.
        if cover >= 0.97 and len(arrows) >= min_arrows:
            break

    # Leftover islands
    for _ in range(220):
        free = [c for c in mask if c not in occupied]
        if len(free) < 2:
            break
        tip = rr.choice(free)
        rem = mask - occupied
        outs = g.outward_dirs(tip, rem, rows, cols) or [d for d, _ in g.DIR_LIST]
        want = rr.randint(2, max_len)
        body = g.grow_inward_from_tip(
            tip, rr.choice(outs), mask, occupied, rows, cols, rr, want, 0.7
        )
        if body is None:
            raw = g.grow_bent_path(
                rr.choice(free), mask, occupied, rows, cols, rr, min(4, max_len), 0.7
            )
            body = g.placeable(raw, occupied, rows, cols) if raw else None
        if (
            body is None
            or len(body) > max_len
            or not g.clear_exit(body[-1], g.tip_dir(body), occupied, rows, cols)
        ):
            continue
        arrows.append(g.A(f"a{len(arrows) + 1}", body, len(arrows)))
        occupied.update(map(tuple, body))

    if len(arrows) < min_arrows:
        return None
    return arrows


def try_best(lid, name, diff, rows, cols, mask, min_arrows, max_len, seed0, soft=False):
    """Pick the seed that yields the densest valid packing (≥ min_arrows)."""
    best_lv = None
    seeds = 12 if soft else 18
    for i, seed in enumerate(range(seed0, seed0 + seeds)):
        arrows = dense_fill_full(
            mask,
            rows,
            cols,
            seed,
            min_arrows=max(8, min_arrows // 2) if soft else min_arrows,
            max_len=max_len,
            bend_bias=0.74,
            attempts_per=26,
        )
        if not arrows:
            continue
        if any(len(a["path"]) > max_len for a in arrows):
            continue
        need = 8 if soft else min_arrows
        if len(arrows) < need:
            continue
        try:
            lv = g.L(lid, name, diff, rows, cols, arrows)
        except AssertionError:
            continue
        if best_lv is None or len(lv["arrows"]) > len(best_lv["arrows"]):
            best_lv = lv
            # Good density — stop early
            cover_cells = sum(len(a["path"]) for a in lv["arrows"])
            if cover_cells / max(len(mask), 1) >= 0.9 and len(lv["arrows"]) >= need:
                if i >= 2 or len(lv["arrows"]) >= need + 15:
                    return best_lv
    return best_lv


def _worker(job):
    lid, name, diff, rows, cols, mask_list, min_arrows, max_len, seed0, soft = job
    mask = set(map(tuple, mask_list))
    t0 = time.time()
    lv = try_best(lid, name, diff, rows, cols, mask, min_arrows, max_len, seed0, soft=soft)
    dt = time.time() - t0
    if lv is None:
        return lid, None, dt, 0
    return lid, lv, dt, len(lv["arrows"])


def load_existing() -> dict[int, dict]:
    levels = {}
    for p in OUT.glob("level_*.json"):
        try:
            lv = json.loads(p.read_text(encoding="utf-8"))
            levels[int(lv["id"])] = lv
        except Exception:
            continue
    return levels


def write_manifest(levels: dict[int, dict]):
    OUT.mkdir(parents=True, exist_ok=True)
    meta = []
    for lid in sorted(levels):
        lv = levels[lid]
        fname = f"level_{lid:04d}.json"
        (OUT / fname).write_text(json.dumps(lv, separators=(",", ":")), encoding="utf-8")
        meta.append(
            {
                "file": fname,
                "id": lv["id"],
                "name": lv["name"],
                "difficulty": lv["difficulty"],
                "rows": lv["rows"],
                "cols": lv["cols"],
                "hearts": lv.get("hearts", 3),
            }
        )
    (OUT / "manifest.json").write_text(
        json.dumps({"levels": meta}, indent=2), encoding="utf-8"
    )


def validate_range(levels: dict[int, dict], start: int, end: int) -> list[str]:
    errors = []
    names = []
    for lid in range(start, end + 1):
        lv = levels.get(lid)
        if lv is None:
            errors.append(f"L{lid}: missing")
            continue
        names.append(lv["name"])
        err = g.validate_layout(lv)
        if err:
            errors.append(f"L{lid}: {err}")
            continue
        n = len(lv["arrows"])
        if lid >= 6 and n < 40:
            errors.append(f"L{lid}: only {n} arrows (<40)")
        if lid >= 6 and any(len(a["path"]) > 8 for a in lv["arrows"]):
            errors.append(f"L{lid}: path longer than 8")
        if lid <= 5 and n < 8:
            errors.append(f"L{lid}: intro too small ({n})")
    if len(names) != len(set(names)):
        # find dupes
        seen = set()
        for n in names:
            if n in seen:
                errors.append(f"duplicate name: {n}")
            seen.add(n)
    return errors


def build_jobs(start: int, end: int):
    catalog = g.build_unique_catalog(TOTAL)
    jobs = []

    for lid, name, diff, rows, cols, mask_fn, min_a, max_l in g.INTROS:
        if start <= lid <= end:
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

    for i, (name, rows, cols, mask, diff) in enumerate(catalog):
        lid = i + 6
        if lid > TOTAL:
            break
        if not (start <= lid <= end):
            continue
        # Larger boards for clearer, denser hard levels
        if len(mask) < 320:
            # upscale stamp: regenerate related with bigger grid via oval inflate
            grow = set()
            for r, c in mask:
                for dr in (-1, 0, 1):
                    for dc in (-1, 0, 1):
                        nr, nc = r + dr, c + dc
                        if 0 <= nr < rows and 0 <= nc < cols:
                            grow.add((nr, nc))
            mask = grow
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
    return jobs


def generate_batch(start: int, end: int, levels: dict[int, dict], workers: int = 8) -> dict[int, dict]:
    jobs = build_jobs(start, end)
    # Skip already-valid levels
    todo = []
    for job in jobs:
        lid = job[0]
        existing = levels.get(lid)
        if existing and not validate_range({lid: existing}, lid, lid):
            continue
        todo.append(job)

    print(f"\n=== BATCH {start}-{end}: generating {len(todo)} / {end - start + 1} ===", flush=True)
    if not todo:
        print("All levels in batch already valid — skip", flush=True)
        return levels

    failed = []
    with ProcessPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(_worker, job): job for job in todo}
        done = 0
        for fut in as_completed(futs):
            job = futs[fut]
            lid, lv, dt, n = fut.result()
            done += 1
            if lv is None:
                failed.append(job)
                print(f"  [{done}/{len(todo)}] L{lid} FAILED ({dt:.1f}s)", flush=True)
            else:
                levels[lid] = lv
                print(
                    f"  [{done}/{len(todo)}] L{lid} {lv['name']}: {n} arrows ({dt:.1f}s)",
                    flush=True,
                )

    for job in failed:
        lid = job[0]
        print(f"  Retry L{lid}…", flush=True)
        ok = None
        for bump in range(20):
            j = list(job)
            j[8] = job[8] + 97 + bump * 173
            # On late retries, force shorter strokes to guarantee ≥40
            _, lv, dt, n = _worker(tuple(j))
            if lv and (lid <= 5 or n >= 40):
                ok = lv
                break
        if ok is None:
            # Force pack with max_len=4–5 seeds via modified soft
            mask = set(map(tuple, job[5]))
            for bump in range(10):
                arrows = dense_fill_full(
                    mask,
                    job[3],
                    job[4],
                    job[8] + 9000 + bump * 41,
                    min_arrows=40 if lid >= 6 else 8,
                    max_len=5,
                    attempts_per=36,
                )
                if not arrows:
                    continue
                try:
                    ok = g.L(lid, job[1], job[2], job[3], job[4], arrows)
                    if lid >= 6 and len(ok["arrows"]) < 40:
                        ok = None
                        continue
                    break
                except AssertionError:
                    ok = None
        if ok is None:
            raise SystemExit(f"Could not generate level {lid} after retries")
        levels[lid] = ok
        print(f"    recovered L{lid} with {len(ok['arrows'])} arrows", flush=True)

    return levels


def cleanup_legacy():
    """Remove old 2-digit level files so only 4-digit batched set remains."""
    for p in OUT.glob("level_*.json"):
        stem = p.stem  # level_01 or level_0001
        if stem.startswith("level_") and len(stem) < len("level_0001"):
            p.unlink(missing_ok=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--start-batch", type=int, default=0, help="0-based batch index")
    ap.add_argument("--only-batch", type=int, default=None, help="Run a single batch index")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--loop", action="store_true", help="Generate all batches until 1000")
    args = ap.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    cleanup_legacy()
    levels = load_existing()

    batch_indices = []
    if args.only_batch is not None:
        batch_indices = [args.only_batch]
    elif args.loop:
        batch_indices = list(range(math.ceil(TOTAL / BATCH)))
    else:
        batch_indices = [args.start_batch]

    t_all = time.time()
    for bi in batch_indices:
        start = bi * BATCH + 1
        end = min(TOTAL, (bi + 1) * BATCH)
        levels = generate_batch(start, end, levels, workers=args.workers)
        write_manifest(levels)
        errors = validate_range(levels, start, end)
        if errors:
            print("VALIDATION FAILED:")
            for e in errors[:30]:
                print(" ", e)
            # Drop invalids and retry once
            for e in errors:
                if e.startswith("L") and ":" in e:
                    try:
                        bad = int(e.split(":")[0][1:])
                        levels.pop(bad, None)
                    except ValueError:
                        pass
            levels = generate_batch(start, end, levels, workers=args.workers)
            write_manifest(levels)
            errors = validate_range(levels, start, end)
            if errors:
                print("VALIDATION STILL FAILING:")
                for e in errors[:40]:
                    print(" ", e)
                raise SystemExit(1)
        # Stats
        ns = [len(levels[i]["arrows"]) for i in range(start, end + 1) if i in levels and i >= 6]
        avg_n = sum(ns) / max(len(ns), 1)
        print(
            f"✓ BATCH {start}-{end} PASS — levels={end - start + 1} "
            f"avgArrows(6+)={avg_n:.1f} totalSaved={len(levels)}",
            flush=True,
        )

    print(f"\nDone. {len(levels)} levels on disk in {time.time() - t_all:.1f}s", flush=True)


if __name__ == "__main__":
    main()
