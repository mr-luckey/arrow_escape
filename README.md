# Arrow Escape

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

30 handcrafted solvable levels in `assets/levels/` (easy / medium / hard).
