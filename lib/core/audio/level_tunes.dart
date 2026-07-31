import 'dart:math' as math;

/// The fixed piano melody that belongs to a level.
///
/// Every level always gets the same tune, and each successful arrow plays the
/// next note of it. Once the tune runs out it repeats from the start, so a
/// level reads as one recognisable phrase rather than random key presses.
///
/// All tunes are built from the C-major white keys, because the background
/// track is in C major — that keeps the notes consonant with the music instead
/// of fighting it. Variety comes from two axes applied on top of the base
/// contours: the tonal centre (which rotates the mode) and a contour transform
/// (upright, inverted, backwards, or both). That yields 36 x 7 x 4 = 1008
/// combinations, enough for one tune per level.
class LevelTunes {
  const LevelTunes._();

  /// MIDI numbers of the white keys from C4 to C6. Index == scale degree.
  static const List<int> _scale = [
    60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83, 84,
  ];

  static const int _topDegree = 14;
  static const int _degreesPerOctave = 7;
  static const int _centreCount = 7;

  /// Melodic contours written as scale degrees relative to the tonal centre.
  static const List<List<int>> _contours = [
    [0, 2, 4, 5, 7, 5, 4, 2],
    [0, 4, 7, 4, 0, 4, 7, 11],
    [7, 4, 2, 0, 2, 4, 7, 9],
    [0, 1, 2, 4, 2, 1, 0, -2],
    [0, 2, 1, 4, 3, 5, 4, 7],
    [4, 4, 2, 0, 4, 4, 2, 0, 7, 5, 4, 2],
    [0, 7, 6, 5, 4, 3, 2, 1, 0],
    [0, 3, 2, 5, 4, 7, 6, 9],
    [2, 4, 6, 4, 2, 0, 2, 4],
    [0, 5, 4, 3, 2, 4, 3, 2, 1, 0],
    [7, 7, 5, 4, 5, 7, 4, 2, 0],
    [0, 2, 4, 6, 8, 6, 4, 2],
    [0, -1, 0, 2, 4, 2, 0, -1, 0],
    [4, 7, 4, 2, 4, 7, 9, 7, 4],
    [0, 4, 5, 7, 5, 4, 0, -3],
    [5, 4, 2, 4, 5, 7, 9, 7, 5, 4],
    [0, 2, 4, 7, 9, 7, 4, 2, 0],
    [9, 7, 5, 4, 2, 4, 5, 7],
    [0, 3, 5, 7, 5, 3, 0, 3, 5],
    [2, 0, 2, 4, 5, 4, 2, 0, -2, 0],
    [7, 9, 11, 9, 7, 5, 4, 2],
    [0, 4, 2, 6, 4, 8, 6, 4, 2, 0],
    [0, 0, 4, 4, 5, 5, 4, 2, 2, 1, 1, 0],
    [4, 2, 4, 5, 7, 7, 5, 4, 2, 0],
    [0, 5, 3, 1, 2, 4, 6, 7],
    [7, 5, 7, 9, 7, 5, 4, 5, 4, 2],
    [0, 2, 0, 4, 2, 5, 4, 7],
    [3, 5, 7, 5, 3, 1, 0, 1, 3],
    [0, 7, 5, 4, 7, 5, 4, 2, 0],
    [1, 2, 4, 5, 4, 2, 1, -1],
    [0, 4, 7, 9, 11, 9, 7, 4],
    [6, 4, 2, 0, 1, 3, 5, 7],
    [0, 2, 5, 4, 7, 9, 7, 5, 4, 2, 0],
    [4, 5, 4, 2, 0, 2, 4, 5, 7],
    [0, -2, 0, 3, 5, 3, 0, -2],
    [2, 5, 4, 7, 6, 9, 7, 4, 2],
  ];

  static const int _variantCount = 4;

  static int get tuneCount =>
      _contours.length * _centreCount * _variantCount;

  /// MIDI notes of the tune for [levelId], in playing order.
  static List<int> forLevel(int levelId) {
    final index = levelId < 1 ? 0 : levelId - 1;
    final contour = _contours[index % _contours.length];
    final centre = (index ~/ _contours.length) % _centreCount;
    final variant =
        (index ~/ (_contours.length * _centreCount)) % _variantCount;

    final pivot = contour.first;
    final inverted = variant == 1 || variant == 3;
    final backwards = variant >= 2;

    var degrees = [
      for (final degree in contour)
        centre + (inverted ? pivot * 2 - degree : degree),
    ];
    if (backwards) {
      degrees = degrees.reversed.toList();
    }

    return _intoRange(degrees)
        .map((degree) => _scale[degree])
        .toList(growable: false);
  }

  /// Shifts the whole phrase by octaves until it fits the sampled range, so the
  /// shape of the melody survives instead of being flattened by clamping.
  static List<int> _intoRange(List<int> degrees) {
    var lowest = degrees.reduce(math.min);
    var highest = degrees.reduce(math.max);
    var shift = 0;

    while (highest + shift > _topDegree &&
        lowest + shift - _degreesPerOctave >= 0) {
      shift -= _degreesPerOctave;
    }
    while (lowest + shift < 0) {
      shift += _degreesPerOctave;
    }

    return [
      for (final degree in degrees) (degree + shift).clamp(0, _topDegree),
    ];
  }

  /// Asset path of the sampled piano note for a MIDI number.
  static String assetFor(int midi) => 'audio/piano/p$midi.wav';
}
