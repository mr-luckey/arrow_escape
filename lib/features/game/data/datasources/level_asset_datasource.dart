import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/game_entities.dart';
import '../models/level_model.dart';

class LevelAssetDataSource {
  LevelAssetDataSource({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  List<LevelEntity>? _cache;

  Future<List<LevelEntity>> loadAll() async {
    if (_cache != null) return _cache!;

    final manifestRaw =
        await _bundle.loadString('assets/levels/manifest.json');
    final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
    final files = (manifest['levels'] as List<dynamic>).cast<String>();

    final levels = <LevelEntity>[];
    for (final file in files) {
      final raw = await _bundle.loadString('assets/levels/$file');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      levels.add(LevelModel.fromJson(json).toEntity());
    }
    levels.sort((a, b) => a.id.compareTo(b.id));
    _cache = levels;
    return levels;
  }

  Future<LevelEntity> loadById(int id) async {
    final all = await loadAll();
    return all.firstWhere((l) => l.id == id);
  }
}
