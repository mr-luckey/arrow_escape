# ColorPath Out

Bright, colorful Flutter puzzle game — tap polyline arrows so they slide off the board without collisions.

Inspired by [Arrow Wave](https://play.google.com/store/apps/details?id=escape.arrow.dash) and [Arrow GO](https://play.google.com/store/apps/details?id=com.playcraft.finalarrow).

## Run

```bash
flutter pub get
flutter run
```

## Architecture

Clean Architecture + BLoC (no `setState`):

- `lib/features/game/domain` — entities & move rules
- `lib/features/game/data` — level JSON + SharedPreferences progress
- `lib/features/game/presentation` — GameBloc + board UI
- `lib/core/theme` — centralized sky / ocean / sunset schemes

## Levels

1000 generated solvable levels in `assets/levels/` (easy / medium / hard), stored as:

- `manifest.json` — metadata only (`id`, `name`, `difficulty`, `rows`, `cols`, `hearts`, owning chunk). Level select is built from this alone.
- `levels_0001_0100.json` … `levels_0901_1000.json` — 100 full levels per chunk, read on demand when a level is opened. The whole chunk is cached, so nearby levels open without another read.

`tool/level_store.py` owns that layout — generators call `load_all()` / `write_all()` instead of writing files themselves, and running it directly repacks whatever is on disk:

```bash
python3 tool/level_store.py
```
