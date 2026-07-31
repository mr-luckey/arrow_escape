"""Shared reader/writer for the level asset store.

Levels ship as chunk files of CHUNK_SIZE levels each plus a manifest of
metadata only, so the app builds the level list from the manifest and pulls a
single chunk when a level is opened. Generators talk to the store through
load_all/write_all instead of touching files directly.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEVELS_DIR = ROOT / "assets" / "levels"
CHUNK_SIZE = 100
CHUNK_GLOB = "levels_*.json"
LEGACY_GLOB = "level_*.json"
MANIFEST_NAME = "manifest.json"

META_KEYS = ("id", "name", "difficulty", "rows", "cols", "hearts")


def chunk_name(level_id: int, chunk_size: int = CHUNK_SIZE) -> str:
    """Chunk file that owns `level_id` (1-based ids)."""
    start = ((level_id - 1) // chunk_size) * chunk_size + 1
    return f"levels_{start:04d}_{start + chunk_size - 1:04d}.json"


def load_all(levels_dir: Path = LEVELS_DIR) -> dict[int, dict]:
    """Every level keyed by id, from chunks and from legacy per-level files."""
    levels: dict[int, dict] = {}
    for path in sorted(levels_dir.glob(CHUNK_GLOB)):
        payload = json.loads(path.read_text(encoding="utf-8"))
        for level in payload.get("levels", []):
            levels[int(level["id"])] = level
    for path in sorted(levels_dir.glob(LEGACY_GLOB)):
        try:
            level = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        levels.setdefault(int(level["id"]), level)
    return levels


def write_all(
    levels: dict[int, dict] | list[dict],
    levels_dir: Path = LEVELS_DIR,
    chunk_size: int = CHUNK_SIZE,
) -> list[str]:
    """Rewrite the whole store as chunks plus manifest. Returns chunk names."""
    by_id = _normalize(levels)
    levels_dir.mkdir(parents=True, exist_ok=True)

    chunks: dict[str, list[dict]] = {}
    meta: list[dict] = []
    for level_id in sorted(by_id):
        level = by_id[level_id]
        name = chunk_name(level_id, chunk_size)
        chunks.setdefault(name, []).append(level)
        meta.append({"file": name, **{k: level.get(k) for k in META_KEYS}})

    for stale in (*levels_dir.glob(CHUNK_GLOB), *levels_dir.glob(LEGACY_GLOB)):
        stale.unlink()

    for name, entries in chunks.items():
        (levels_dir / name).write_text(
            json.dumps({"levels": entries}, separators=(",", ":")),
            encoding="utf-8",
        )
    (levels_dir / MANIFEST_NAME).write_text(
        json.dumps({"chunkSize": chunk_size, "levels": meta}, indent=2) + "\n",
        encoding="utf-8",
    )
    return sorted(chunks)


def _normalize(levels: dict[int, dict] | list[dict]) -> dict[int, dict]:
    if isinstance(levels, dict):
        return {int(k): v for k, v in levels.items()}
    return {int(lv["id"]): lv for lv in levels}


def main() -> None:
    """Repack whatever is on disk into the chunked layout."""
    levels = load_all()
    if not levels:
        print(f"no levels found in {LEVELS_DIR}")
        return
    names = write_all(levels)
    total = sum((LEVELS_DIR / n).stat().st_size for n in names)
    manifest_size = (LEVELS_DIR / MANIFEST_NAME).stat().st_size
    print(
        f"packed {len(levels)} levels into {len(names)} chunks "
        f"({total / 1024:.0f} KB) + manifest ({manifest_size / 1024:.0f} KB)"
    )


if __name__ == "__main__":
    main()
