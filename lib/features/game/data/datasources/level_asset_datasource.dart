import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/game_entities.dart';
import '../models/level_model.dart';

class LevelAssetDataSource {
  LevelAssetDataSource({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  List<LevelEntity>? _index;
  final Map<int, LevelEntity> _fullCache = {};
  late Map<int, String> _fileById;

  Future<List<LevelEntity>> loadAll() async {
    if (_index != null) return _index!;

    final manifestRaw =
        await _bundle.loadString('assets/levels/manifest.json');
    final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
    final rawLevels = manifest['levels'] as List<dynamic>;

    _fileById = {};
    final levels = <LevelEntity>[];

    for (final entry in rawLevels) {
      if (entry is String) {
        final raw = await _bundle.loadString('assets/levels/$entry');
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final entity = LevelModel.fromJson(json).toEntity();
        _fileById[entity.id] = entry;
        _fullCache[entity.id] = entity;
        levels.add(entity);
      } else {
        final meta = entry as Map<String, dynamic>;
        final id = meta['id'] as int;
        final file = meta['file'] as String;
        _fileById[id] = file;
        levels.add(
          LevelEntity(
            id: id,
            name: meta['name'] as String? ?? 'Level $id',
            rows: meta['rows'] as int? ?? 16,
            cols: meta['cols'] as int? ?? 16,
            hearts: meta['hearts'] as int? ?? 3,
            difficulty: LevelDifficulty.values.firstWhere(
              (d) => d.name == (meta['difficulty'] as String? ?? 'easy'),
              orElse: () => LevelDifficulty.easy,
            ),
            arrows: const [],
          ),
        );
      }
    }

    levels.sort((a, b) => a.id.compareTo(b.id));
    _index = levels;
    return levels;
  }

  Future<LevelEntity> loadById(int id) async {
    final cached = _fullCache[id];
    if (cached != null) return cached;

    await loadAll();
    final file = _fileById[id];
    if (file == null) {
      throw StateError('Level $id not found in manifest');
    }
    final raw = await _bundle.loadString('assets/levels/$file');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final entity = LevelModel.fromJson(json).toEntity();
    _fullCache[id] = entity;
    return entity;
  }
}
