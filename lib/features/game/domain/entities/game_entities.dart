import 'package:equatable/equatable.dart';

enum Direction { up, down, left, right }

extension DirectionX on Direction {
  String get code => switch (this) {
        Direction.up => 'U',
        Direction.down => 'D',
        Direction.left => 'L',
        Direction.right => 'R',
      };

  static Direction fromCode(String code) => switch (code.toUpperCase()) {
        'U' => Direction.up,
        'D' => Direction.down,
        'L' => Direction.left,
        'R' => Direction.right,
        _ => throw ArgumentError('Unknown direction: $code'),
      };

  (int, int) get delta => switch (this) {
        Direction.up => (-1, 0),
        Direction.down => (1, 0),
        Direction.left => (0, -1),
        Direction.right => (0, 1),
      };

  /// Direction of travel from [from] → [to] for orthogonal neighbors.
  static Direction? between(Cell from, Cell to) {
    final dr = to.row - from.row;
    final dc = to.col - from.col;
    if (dr == -1 && dc == 0) return Direction.up;
    if (dr == 1 && dc == 0) return Direction.down;
    if (dr == 0 && dc == -1) return Direction.left;
    if (dr == 0 && dc == 1) return Direction.right;
    return null;
  }
}

class Cell extends Equatable {
  const Cell(this.row, this.col);

  final int row;
  final int col;

  Cell step(Direction direction) {
    final (dr, dc) = direction.delta;
    return Cell(row + dr, col + dc);
  }

  @override
  List<Object?> get props => [row, col];

  @override
  String toString() => '($row,$col)';
}

class ArrowEntity extends Equatable {
  const ArrowEntity({
    required this.id,
    required this.path,
    required this.direction,
    this.colorIndex = 0,
  });

  final String id;
  /// Ordered from tail to head.
  final List<Cell> path;
  final Direction direction;
  final int colorIndex;

  Cell get head => path.last;
  Cell get tail => path.first;

  /// Exit direction must match the last body segment (tip orientation).
  Direction get tipDirection {
    if (path.length < 2) return direction;
    return DirectionX.between(path[path.length - 2], path.last) ?? direction;
  }

  /// Ensures stored [direction] matches the painted tip.
  ArrowEntity normalized() {
    final tip = tipDirection;
    if (tip == direction) return this;
    return copyWith(direction: tip);
  }

  ArrowEntity copyWith({
    String? id,
    List<Cell>? path,
    Direction? direction,
    int? colorIndex,
  }) {
    return ArrowEntity(
      id: id ?? this.id,
      path: path ?? this.path,
      direction: direction ?? this.direction,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }

  @override
  List<Object?> get props => [id, path, direction, colorIndex];
}

enum LevelDifficulty { easy, medium, hard }

class LevelEntity extends Equatable {
  const LevelEntity({
    required this.id,
    required this.name,
    required this.rows,
    required this.cols,
    required this.arrows,
    this.hearts = 3,
    this.difficulty = LevelDifficulty.easy,
  });

  final int id;
  final String name;
  final int rows;
  final int cols;
  final List<ArrowEntity> arrows;
  final int hearts;
  final LevelDifficulty difficulty;

  LevelEntity copyWith({List<ArrowEntity>? arrows, int? hearts}) {
    return LevelEntity(
      id: id,
      name: name,
      rows: rows,
      cols: cols,
      arrows: arrows ?? this.arrows,
      hearts: hearts ?? this.hearts,
      difficulty: difficulty,
    );
  }

  @override
  List<Object?> get props => [id, name, rows, cols, arrows, hearts, difficulty];
}
