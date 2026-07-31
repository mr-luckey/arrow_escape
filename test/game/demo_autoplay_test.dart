import 'dart:convert';
import 'dart:io';

import 'package:arrow_escape/features/game/data/datasources/level_asset_datasource.dart';
import 'package:arrow_escape/features/game/data/models/level_model.dart';
import 'package:arrow_escape/features/game/domain/entities/game_entities.dart';
import 'package:arrow_escape/features/game/domain/usecases/game_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

/// The demo hand drives the board by repeatedly tapping whichever arrow can
/// currently escape, so the showcase level must survive that greedy order.
void main() {
  const getHint = GetHintUseCase();

  final level = LevelModel.fromJson(
    jsonDecode(File(LevelAssetDataSource.demoAsset).readAsStringSync())
        as Map<String, dynamic>,
  ).toEntity();

  test('demo level fills every cell of the board', () {
    final covered = <Cell>{for (final a in level.arrows) ...a.path};
    expect(covered.length, level.rows * level.cols);
  });

  test('demo level arrows are 5 to 10 cells long', () {
    for (final arrow in level.arrows) {
      expect(arrow.path.length, inInclusiveRange(5, 10));
    }
  });

  test('demo level is solvable by greedy auto-play', () {
    var arrows = List<ArrowEntity>.of(level.arrows);
    var moves = 0;

    while (arrows.isNotEmpty) {
      final id = getHint(
        arrows: arrows,
        rows: level.rows,
        cols: level.cols,
      );
      expect(id, isNotNull, reason: 'stuck after $moves moves');
      arrows = arrows.where((a) => a.id != id).toList();
      moves++;
    }

    expect(moves, level.arrows.length);
  });
}
