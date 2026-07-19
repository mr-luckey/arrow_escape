import 'package:arrow_escape/features/game/domain/entities/game_entities.dart';
import 'package:arrow_escape/features/game/domain/usecases/game_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const canEscape = CanEscapeUseCase();
  const applyMove = ApplyMoveUseCase();
  const getHint = GetHintUseCase();

  group('CanEscapeUseCase', () {
    test('allows exit when path to edge is clear', () {
      final a = ArrowEntity(
        id: 'a',
        path: const [Cell(0, 0), Cell(0, 1)],
        direction: Direction.right,
      );
      expect(
        canEscape(arrow: a, allArrows: [a], rows: 3, cols: 4),
        isTrue,
      );
    });

    test('blocks when another arrow occupies exit lane', () {
      final a = ArrowEntity(
        id: 'a',
        path: const [Cell(1, 0), Cell(1, 1)],
        direction: Direction.right,
      );
      final b = ArrowEntity(
        id: 'b',
        path: const [Cell(1, 3)],
        direction: Direction.down,
      );
      expect(
        canEscape(arrow: a, allArrows: [a, b], rows: 4, cols: 4),
        isFalse,
      );
    });
  });

  group('ApplyMoveUseCase', () {
    test('removes arrow on success', () {
      final a = ArrowEntity(
        id: 'a',
        path: const [Cell(0, 0)],
        direction: Direction.up,
      );
      final result = applyMove(
        arrowId: 'a',
        arrows: [a],
        rows: 3,
        cols: 3,
        hearts: 3,
      );
      expect(result.success, isTrue);
      expect(result.arrows, isEmpty);
      expect(result.isWon, isTrue);
    });

    test('loses a heart on failure', () {
      final a = ArrowEntity(
        id: 'a',
        path: const [Cell(0, 0)],
        direction: Direction.right,
      );
      final b = ArrowEntity(
        id: 'b',
        path: const [Cell(0, 2)],
        direction: Direction.down,
      );
      final result = applyMove(
        arrowId: 'a',
        arrows: [a, b],
        rows: 3,
        cols: 3,
        hearts: 3,
      );
      expect(result.success, isFalse);
      expect(result.hearts, 2);
      expect(result.arrows.length, 2);
    });
  });

  group('GetHintUseCase', () {
    test('returns an escapable arrow id', () {
      final a = ArrowEntity(
        id: 'blocked',
        path: const [Cell(1, 0)],
        direction: Direction.right,
      );
      final b = ArrowEntity(
        id: 'free',
        path: const [Cell(1, 2)],
        direction: Direction.right,
      );
      expect(
        getHint(arrows: [a, b], rows: 3, cols: 4),
        'free',
      );
    });
  });
}
