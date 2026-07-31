import 'dart:convert';
import 'dart:io';

import 'package:arrow_escape/features/game/data/datasources/level_asset_datasource.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);

  final Map<String, String> files;
  final List<String> loaded = [];

  @override
  Future<ByteData> load(String key) async {
    final content = files[key];
    if (content == null) {
      throw StateError('asset not found: $key');
    }
    loaded.add(key);
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

Map<String, dynamic> _level(int id, String name) => {
      'id': id,
      'name': name,
      'difficulty': 'easy',
      'rows': 4,
      'cols': 4,
      'hearts': 3,
      'arrows': [
        {
          'id': 'a1',
          'path': [
            [0, 0],
            [0, 1],
          ],
          'direction': 'R',
          'colorIndex': 0,
        },
      ],
    };

void main() {
  group('LevelAssetDataSource with chunked assets', () {
    late _FakeBundle bundle;
    late LevelAssetDataSource source;

    setUp(() {
      bundle = _FakeBundle({
        'assets/levels/manifest.json': jsonEncode({
          'chunkSize': 2,
          'levels': [
            {
              'file': 'levels_0001_0002.json',
              'id': 1,
              'name': 'One',
              'difficulty': 'easy',
              'rows': 4,
              'cols': 4,
              'hearts': 3,
            },
            {
              'file': 'levels_0001_0002.json',
              'id': 2,
              'name': 'Two',
              'difficulty': 'medium',
              'rows': 4,
              'cols': 4,
              'hearts': 3,
            },
            {
              'file': 'levels_0003_0004.json',
              'id': 3,
              'name': 'Three',
              'difficulty': 'hard',
              'rows': 4,
              'cols': 4,
              'hearts': 3,
            },
          ],
        }),
        'assets/levels/levels_0001_0002.json': jsonEncode({
          'levels': [_level(1, 'One'), _level(2, 'Two')],
        }),
        'assets/levels/levels_0003_0004.json': jsonEncode({
          'levels': [_level(3, 'Three')],
        }),
      });
      source = LevelAssetDataSource(bundle: bundle);
    });

    test('loadAll reads only the manifest', () async {
      final levels = await source.loadAll();

      expect(levels.map((l) => l.id), [1, 2, 3]);
      expect(levels.first.arrows, isEmpty);
      expect(bundle.loaded, ['assets/levels/manifest.json']);
    });

    test('loadById returns the level from its chunk', () async {
      final level = await source.loadById(2);

      expect(level.name, 'Two');
      expect(level.arrows, hasLength(1));
    });

    test('loading one level caches its whole chunk', () async {
      await source.loadById(1);
      bundle.loaded.clear();

      final sibling = await source.loadById(2);

      expect(sibling.arrows, hasLength(1));
      expect(bundle.loaded, isEmpty);
    });

    test('a level in another chunk needs another read', () async {
      await source.loadById(1);
      bundle.loaded.clear();

      await source.loadById(3);

      expect(bundle.loaded, ['assets/levels/levels_0003_0004.json']);
    });

    test('unknown id throws', () async {
      expect(() => source.loadById(99), throwsStateError);
    });

    test('still reads a legacy single-level file', () async {
      final legacy = _FakeBundle({
        'assets/levels/manifest.json': jsonEncode({
          'levels': [
            {
              'file': 'level_0007.json',
              'id': 7,
              'name': 'Seven',
              'difficulty': 'easy',
              'rows': 4,
              'cols': 4,
              'hearts': 3,
            },
          ],
        }),
        'assets/levels/level_0007.json': jsonEncode(_level(7, 'Seven')),
      });

      final level = await LevelAssetDataSource(bundle: legacy).loadById(7);

      expect(level.name, 'Seven');
      expect(level.arrows, hasLength(1));
    });
  });

  group('shipped level assets', () {
    final dir = Directory('assets/levels');
    final manifest =
        jsonDecode(File('${dir.path}/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final entries = (manifest['levels'] as List).cast<Map<String, dynamic>>();

    test('manifest covers a contiguous id range', () {
      final ids = entries.map((e) => e['id'] as int).toList();

      expect(ids, List.generate(ids.length, (i) => i + 1));
    });

    test('every manifest entry resolves inside its chunk', () {
      final chunkIds = <String, Set<int>>{};
      for (final file in entries.map((e) => e['file'] as String).toSet()) {
        final payload = jsonDecode(File('${dir.path}/$file').readAsStringSync())
            as Map<String, dynamic>;
        chunkIds[file] = (payload['levels'] as List)
            .map((l) => (l as Map<String, dynamic>)['id'] as int)
            .toSet();
      }

      for (final entry in entries) {
        expect(
          chunkIds[entry['file'] as String],
          contains(entry['id'] as int),
          reason: 'level ${entry['id']} missing from ${entry['file']}',
        );
      }
    });

    test('chunk names match the declared chunk size', () {
      final chunkSize = manifest['chunkSize'] as int;

      for (final entry in entries) {
        final id = entry['id'] as int;
        final start = ((id - 1) ~/ chunkSize) * chunkSize + 1;
        final expected = 'levels_${_pad(start)}_${_pad(start + chunkSize - 1)}'
            '.json';

        expect(entry['file'], expected);
      }
    });

    test('no stray per-level files are left in the bundle', () {
      final strays = dir
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.startsWith('level_'));

      expect(strays, isEmpty);
    });
  });
}

String _pad(int value) => value.toString().padLeft(4, '0');
