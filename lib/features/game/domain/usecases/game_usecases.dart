import '../entities/game_entities.dart';

/// Returns true when every cell from the head (exclusive start at head+1)
/// to the edge of the board is free of other arrows.
class CanEscapeUseCase {
  const CanEscapeUseCase();

  bool call({
    required ArrowEntity arrow,
    required List<ArrowEntity> allArrows,
    required int rows,
    required int cols,
  }) {
    final occupied = <Cell>{};
    for (final other in allArrows) {
      if (other.id == arrow.id) continue;
      occupied.addAll(other.path);
    }

    var cursor = arrow.head.step(arrow.direction);
    while (cursor.row >= 0 &&
        cursor.row < rows &&
        cursor.col >= 0 &&
        cursor.col < cols) {
      if (occupied.contains(cursor)) return false;
      cursor = cursor.step(arrow.direction);
    }
    return true;
  }
}

class GetHintUseCase {
  const GetHintUseCase({this.canEscape = const CanEscapeUseCase()});

  final CanEscapeUseCase canEscape;

  /// Returns the id of an arrow that can currently escape, or null.
  String? call({
    required List<ArrowEntity> arrows,
    required int rows,
    required int cols,
  }) {
    for (final arrow in arrows) {
      if (canEscape(
        arrow: arrow,
        allArrows: arrows,
        rows: rows,
        cols: cols,
      )) {
        return arrow.id;
      }
    }
    return null;
  }
}

class MoveResult {
  const MoveResult({
    required this.success,
    required this.arrows,
    required this.hearts,
    this.removedArrowId,
  });

  final bool success;
  final List<ArrowEntity> arrows;
  final int hearts;
  final String? removedArrowId;

  bool get isWon => arrows.isEmpty;
  bool get isLost => hearts <= 0;
}

class ApplyMoveUseCase {
  const ApplyMoveUseCase({this.canEscape = const CanEscapeUseCase()});

  final CanEscapeUseCase canEscape;

  MoveResult call({
    required String arrowId,
    required List<ArrowEntity> arrows,
    required int rows,
    required int cols,
    required int hearts,
  }) {
    final arrow = arrows.firstWhere((a) => a.id == arrowId);
    final ok = canEscape(
      arrow: arrow,
      allArrows: arrows,
      rows: rows,
      cols: cols,
    );

    if (ok) {
      return MoveResult(
        success: true,
        arrows: arrows.where((a) => a.id != arrowId).toList(),
        hearts: hearts,
        removedArrowId: arrowId,
      );
    }

    return MoveResult(
      success: false,
      arrows: arrows,
      hearts: hearts - 1,
    );
  }
}
