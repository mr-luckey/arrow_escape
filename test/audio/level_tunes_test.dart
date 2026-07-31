import 'dart:io';

import 'package:arrow_escape/core/audio/level_tunes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelTunes', () {
    test('gives every level a non-empty tune', () {
      for (var id = 1; id <= 1000; id++) {
        expect(LevelTunes.forLevel(id), isNotEmpty, reason: 'level $id');
      }
    });

    test('is deterministic per level', () {
      for (final id in [1, 2, 37, 253, 618, 1000]) {
        expect(LevelTunes.forLevel(id), LevelTunes.forLevel(id));
      }
    });

    test('handles out-of-range level ids without throwing', () {
      expect(LevelTunes.forLevel(0), isNotEmpty);
      expect(LevelTunes.forLevel(-5), isNotEmpty);
      expect(LevelTunes.forLevel(999999), isNotEmpty);
    });

    test('only uses sampled notes that ship with the app', () {
      final used = <int>{};
      for (var id = 1; id <= 1000; id++) {
        used.addAll(LevelTunes.forLevel(id));
      }

      for (final midi in used) {
        final file = File('assets/${LevelTunes.assetFor(midi)}');
        expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
      }
    });

    test('ships no unused note samples', () {
      final used = <int>{};
      for (var id = 1; id <= 1000; id++) {
        used.addAll(LevelTunes.forLevel(id));
      }

      final bundled = Directory('assets/audio/piano')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.wav'))
          .map((f) => int.parse(
                f.uri.pathSegments.last.replaceAll(RegExp(r'[^0-9]'), ''),
              ))
          .toSet();

      expect(bundled.difference(used), isEmpty);
    });

    test('spreads levels across distinct tunes', () {
      final distinct = <String>{};
      for (var id = 1; id <= 1000; id++) {
        distinct.add(LevelTunes.forLevel(id).join(','));
      }
      expect(distinct.length, greaterThan(800));
    });
  });
}
