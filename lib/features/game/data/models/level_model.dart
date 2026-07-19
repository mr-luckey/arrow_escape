import '../../domain/entities/game_entities.dart';

class LevelModel {
  LevelModel({
    required this.id,
    required this.name,
    required this.rows,
    required this.cols,
    required this.arrows,
    this.hearts = 3,
    this.difficulty = 'easy',
  });

  final int id;
  final String name;
  final int rows;
  final int cols;
  final List<ArrowModel> arrows;
  final int hearts;
  final String difficulty;

  factory LevelModel.fromJson(Map<String, dynamic> json) {
    return LevelModel(
      id: json['id'] as int,
      name: json['name'] as String,
      rows: json['rows'] as int,
      cols: json['cols'] as int,
      hearts: json['hearts'] as int? ?? 3,
      difficulty: json['difficulty'] as String? ?? 'easy',
      arrows: (json['arrows'] as List<dynamic>)
          .map((e) => ArrowModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  LevelEntity toEntity() {
    return LevelEntity(
      id: id,
      name: name,
      rows: rows,
      cols: cols,
      hearts: hearts,
      difficulty: LevelDifficulty.values.firstWhere(
        (d) => d.name == difficulty,
        orElse: () => LevelDifficulty.easy,
      ),
      arrows: arrows.map((a) => a.toEntity()).toList(),
    );
  }
}

class ArrowModel {
  ArrowModel({
    required this.id,
    required this.path,
    required this.direction,
    this.colorIndex = 0,
  });

  final String id;
  final List<List<int>> path;
  final String direction;
  final int colorIndex;

  factory ArrowModel.fromJson(Map<String, dynamic> json) {
    return ArrowModel(
      id: json['id'] as String,
      path: (json['path'] as List<dynamic>)
          .map((e) => (e as List<dynamic>).map((n) => n as int).toList())
          .toList(),
      direction: json['direction'] as String,
      colorIndex: json['colorIndex'] as int? ?? 0,
    );
  }

  ArrowEntity toEntity() {
    return ArrowEntity(
      id: id,
      path: path.map((p) => Cell(p[0], p[1])).toList(),
      direction: DirectionX.fromCode(direction),
      colorIndex: colorIndex,
    );
  }
}
