import 'dart:math' as math;

/// The fixed piano melody that belongs to a level.
///
/// Every level always gets the same tune, and each successful arrow plays the
/// next note of it. Once the tune runs out it repeats from the start, so a
/// level reads as one recognisable phrase rather than random key presses.
///
/// Melodies are public-domain classics and original song-like hooks (modern
/// copyrighted hit songs are not transcribed). All notes stay on C-major white
/// keys so they sit consonant with the background track.
///
/// Assignment is deterministic: level N always maps to the same melody + tonal
/// centre. No level's tune is swapped or replaced when the catalog grows —
/// new songs are only appended, and the index math uses a fixed catalog size
/// snapshotted below.
class LevelTunes {
  const LevelTunes._();

  /// MIDI numbers of the white keys from C4 to C6. Index == scale degree.
  static const List<int> _scale = [
    60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83, 84,
  ];

  static const int _topDegree = 14;
  static const int _degreesPerOctave = 7;
  static const int _centreCount = 7;

  /// Frozen catalog length used for indexing. Must be ≤ [_songs.length].
  /// Bump only when appending songs — never shrink or reorder — so existing
  /// level → tune maps stay stable.
  static const int _catalogSize = 183;

  /// Song-like melodic contours as scale degrees relative to the tonal centre.
  /// Public-domain classics first, then original hooks. Never reorder or insert
  /// in the middle — only append, and bump [_catalogSize] when you do.
  static const List<List<int>> _songs = [
    // --- Public-domain classics (recognisable "hit" melodies) ---
    [0, 0, 4, 4, 5, 5, 4, 3, 3, 2, 2, 1, 1, 0], // Twinkle Twinkle
    [2, 1, 0, 1, 2, 2, 2, 1, 1, 1, 2, 4, 4], // Mary Had a Little Lamb
    [2, 2, 3, 4, 4, 3, 2, 1, 0, 0, 1, 2, 2, 1, 1], // Ode to Joy
    [0, 0, 1, 0, 3, 2, 0, 0, 1, 0, 4, 3], // Happy Birthday (A)
    [0, 0, 7, 5, 3, 2, 1, 5, 5, 4, 3, 4, 3], // Happy Birthday (B)
    [0, 2, 4, 0, 0, 2, 4, 0, 4, 5, 7], // Frère Jacques
    [4, 5, 7, 4, 5, 7, 7, 9, 7, 5, 4, 2, 0, 4], // Frère Jacques (end)
    [0, 0, 0, 1, 2, 2, 1, 0, 2, 1, 0], // Row Row Row Your Boat
    [0, 2, 4, 5, 4, 2, 0, 7, 5, 4, 2, 0], // London Bridge
    [4, 2, 0, 2, 4, 4, 4, 2, 2, 2, 4, 7, 7], // Lightly Row
    [0, 2, 4, 4, 2, 0, 7, 5, 4, 2, 4, 0], // This Old Man
    [0, 0, 4, 4, 5, 7, 5, 4, 2, 0, 2, 4], // Aura Lee / Love Me Tender root
    [4, 4, 5, 7, 7, 5, 4, 2, 0, 2, 4, 4, 2, 2, 0], // Jingle Bells
    [0, 0, 0, 2, 4, 4, 2, 0, 7, 5, 4, 2, 0], // Oh Susanna
    [0, 2, 4, 0, 5, 4, 2, 0, 7, 5, 4, 2, 0], // Camptown Races
    [0, 1, 2, 0, 0, 1, 2, 0, 2, 3, 4], // Yankee Doodle
    [4, 2, 0, 2, 4, 5, 4, 2, 0, 2, 4, 2, 0], // When the Saints
    [0, 4, 7, 4, 0, 4, 7, 4, 5, 4, 2, 0], // Amazing Grace (shape)
    [4, 5, 4, 2, 0, 2, 4, 7, 5, 4, 2, 0], // Greensleeves (diatonic)
    [0, 2, 4, 5, 4, 2, 0, 2, 4, 2, 0, -2, 0], // Scarborough Fair (shape)
    [0, 2, 3, 5, 3, 2, 0, 2, 3, 2, 0], // Auld Lang Syne (shape)
    [0, 0, 4, 4, 7, 7, 5, 5, 4], // Brahms Lullaby (open)
    [4, 0, 2, 4, 7, 5, 4, 2, 0, 2, 4], // Minuet in G (shape)
    [0, 2, 4, 2, 0, 2, 4, 7, 5, 4, 2, 4, 0], // Can-Can (shape)
    [7, 5, 4, 2, 0, 2, 4, 5, 4, 2, 0], // Blue Danube (shape)
    [0, 4, 5, 4, 0, 2, 4, 5, 7, 5, 4], // Swan Lake (shape)
    [4, 2, 4, 5, 7, 5, 4, 2, 0, 2, 4], // William Tell (shape)
    [0, 2, 4, 7, 4, 2, 0, 4, 7, 9, 7, 4], // Eine Kleine (shape)
    [0, -2, 0, 2, 4, 2, 0, -2, 0, 2, 0], // Für Elise (diatonic shape)
    [0, 0, 0, 0, 2, 4, 4, 2, 0, 2, 4, 5, 4], // Entertainer (shape)
    [0, 2, 4, 5, 7, 5, 4, 2, 0, 2, 0], // Spring / Vivaldi (shape)
    [7, 4, 0, 4, 7, 9, 7, 4, 5, 4, 2, 0], // Canon in D (shape)
    [0, 3, 5, 0, 3, 5, 7, 5, 3, 0], // La Cucaracha (shape)
    [0, 2, 4, 0, 5, 4, 7, 5, 4, 2, 0], // La Bamba (folk shape)
    [4, 4, 4, 2, 4, 5, 4, 0, 2, 4], // Skip to My Lou
    [0, 4, 7, 9, 7, 4, 0, 4, 5, 4, 2, 0], // Simple Gifts
    [2, 4, 5, 4, 2, 0, 2, 4, 5, 7, 5, 4], // Morning Mood (shape)
    [0, 2, 0, 4, 2, 5, 4, 7, 5, 4, 2, 0], // Hornpipe (shape)
    [5, 4, 2, 0, 2, 4, 5, 7, 5, 4, 2, 4], // Arirang (shape)
    [0, 0, 2, 4, 4, 2, 0, 5, 4, 2, 0], // Sakura (diatonic shape)
    [0, 5, 4, 2, 0, 2, 4, 5, 4, 0], // Danny Boy (shape)
    [0, 2, 4, 5, 4, 0, 2, 4, 7, 5, 4, 2, 0], // Shenandoah (shape)
    [4, 5, 7, 9, 7, 5, 4, 2, 0, 2, 4, 5], // Loch Lomond (shape)
    [0, 4, 2, 0, 5, 4, 2, 4, 0], // Home on the Range (shape)
    [2, 0, 2, 4, 5, 4, 2, 0, 2, 4, 0], // Red River Valley
    [0, 2, 4, 2, 5, 4, 2, 0, 7, 5, 4, 2, 0], // My Bonnie
    [0, 0, 2, 2, 4, 4, 5, 4, 2, 0], // Pop Goes the Weasel
    [4, 2, 0, 4, 2, 0, 7, 5, 4, 2, 0], // Three Blind Mice
    [0, 2, 4, 5, 7, 9, 7, 5, 4, 2, 0], // Scale climb song
    [0, 4, 7, 12, 7, 4, 0, 4, 7, 4, 0], // Octave arpeggio hymn
    [2, 2, 2, 0, 4, 4, 4, 2, 5, 5, 4, 2, 0], // Habanera (shape)
    [0, 1, 2, 4, 5, 4, 2, 1, 0, 2, 4], // Hungarian Dance (shape)
    [7, 5, 4, 5, 7, 9, 7, 5, 4, 2, 0], // Toreador (shape)
    [0, 2, 4, 7, 5, 4, 2, 5, 4, 2, 0], // Radetzky (shape)
    [4, 0, 4, 7, 5, 4, 2, 0, 2, 4], // Wedding March (shape)
    [0, 5, 4, 5, 7, 5, 4, 2, 0, 2, 0], // Bridal Chorus (shape)
    [0, 0, 5, 5, 4, 4, 2, 2, 0], // Chopsticks (shape)
    [2, 4, 5, 7, 5, 4, 2, 0, 2, 4, 5, 4], // Over the Waves
    [0, 3, 5, 7, 5, 3, 0, 3, 5, 3, 0], // Mexican Hat Dance
    [0, 2, 3, 2, 0, 5, 4, 2, 0], // Kalinka (shape)
    [4, 4, 5, 4, 0, 2, 4, 5, 4, 2, 0], // Korobeiniki / Tetris folk
    [0, 4, 5, 7, 5, 4, 0, 2, 4, 2, 0], // Song of the Volga
    [2, 0, -2, 0, 2, 4, 5, 4, 2, 0], // Dark Eyes (shape)
    [0, 2, 4, 5, 4, 7, 5, 4, 2, 0], // Hava Nagila (shape)
    [0, 0, 4, 2, 0, 5, 4, 2, 4, 0], // Hatikvah (shape)
    [5, 4, 2, 4, 5, 7, 5, 4, 2, 0, 2, 4], // Fado folk shape
    [0, 2, 5, 4, 2, 0, 4, 5, 7, 5, 4, 2], // Celtic reel shape
    [0, 4, 2, 5, 4, 7, 5, 4, 2, 0], // Polka bounce
    [7, 7, 5, 4, 5, 7, 4, 2, 0, 2, 4], // Marching hymn
    [0, 2, 0, 4, 0, 5, 4, 2, 0, 2, 4, 0], // Banjo roll shape
    [2, 4, 6, 4, 2, 0, 2, 4, 6, 7, 4, 2], // Waltz rise
    [0, 5, 7, 5, 4, 2, 0, 2, 4, 5, 4, 0], // Gospel lift
    [4, 5, 4, 0, 2, 4, 7, 5, 4, 2, 4, 0], // Soft rock ballad shape
    [0, 0, 2, 4, 5, 5, 4, 2, 2, 0, 0], // Nursery cascade
    [0, 4, 4, 5, 7, 7, 5, 4, 2, 0], // Anthem open
    [2, 2, 4, 4, 5, 7, 5, 4, 2, 0, 2], // Cheerful skip
    [0, 2, 4, 4, 5, 4, 2, 0, 7, 0], // Call and answer
    [5, 5, 4, 4, 2, 2, 0, 2, 4, 5], // Descending answer
    [0, 7, 5, 4, 2, 4, 5, 7, 0], // Arch phrase
    [0, 2, 5, 7, 5, 2, 0, 4, 7, 4, 0], // Wide leap hook
    [3, 5, 7, 5, 3, 1, 0, 1, 3, 5], // Minor-ish modal folk
    [0, 3, 5, 3, 0, 3, 5, 7, 5, 3, 0], // Pent-ish bounce
    [1, 2, 4, 5, 4, 2, 1, 0, 2, 4], // Stepwise climb
    [0, 4, 7, 5, 2, 4, 0, 5, 4, 2, 0], // Surprise drop
    [2, 0, 4, 0, 5, 4, 7, 5, 4, 0], // Zigzag hook
    [0, 2, 4, 7, 9, 7, 4, 5, 4, 2, 0], // Bright fanfare
    [7, 9, 7, 5, 4, 5, 7, 4, 2, 0], // High cascade
    [0, 0, 5, 4, 2, 4, 5, 0], // Short earworm A
    [2, 4, 5, 4, 7, 5, 4, 2], // Short earworm B
    [0, 4, 5, 7, 4, 5, 2, 0], // Short earworm C
    [4, 2, 5, 4, 0, 2, 4, 0], // Short earworm D
    [0, 5, 4, 7, 5, 4, 2, 0, 4], // Short earworm E
    [2, 2, 0, 4, 4, 2, 5, 4, 0], // Short earworm F
    [0, 2, 2, 4, 5, 5, 4, 0], // Short earworm G
    [4, 4, 7, 5, 4, 2, 0, 2], // Short earworm H
    [0, 7, 4, 5, 2, 4, 0], // Leap hook A
    [5, 0, 4, 7, 5, 2, 0], // Leap hook B
    [0, 4, 2, 7, 5, 4, 0], // Leap hook C
    [2, 5, 0, 4, 7, 4, 2, 0], // Leap hook D
    // --- Original song-like hooks (catchy, not transcriptions) ---
    [0, 2, 4, 5, 7, 5, 4, 5, 4, 2, 0, 2, 0],
    [0, 0, 4, 5, 4, 2, 4, 0, 2, 4, 5, 4],
    [2, 4, 5, 7, 9, 7, 5, 4, 2, 4, 0],
    [0, 4, 7, 5, 4, 2, 5, 4, 0, 2, 4],
    [4, 5, 7, 5, 4, 0, 2, 4, 5, 7, 4],
    [0, 2, 0, 5, 4, 2, 0, 4, 5, 4, 2, 0],
    [7, 5, 4, 2, 4, 5, 7, 9, 7, 5, 4, 0],
    [0, 3, 5, 7, 5, 3, 2, 0, 3, 5, 0],
    [2, 0, 2, 5, 4, 7, 5, 4, 2, 0, 4],
    [0, 4, 5, 4, 7, 5, 2, 4, 0, 2, 0],
    [5, 4, 2, 0, 2, 4, 5, 4, 7, 5, 4],
    [0, 2, 4, 7, 5, 9, 7, 5, 4, 2, 0],
    [4, 0, 2, 5, 4, 0, 4, 7, 5, 4],
    [0, 5, 2, 4, 0, 5, 7, 5, 4, 2, 0],
    [2, 4, 0, 5, 4, 7, 4, 2, 0, 2],
    [0, 0, 2, 5, 4, 4, 2, 0, 5, 4, 0],
    [7, 4, 5, 2, 4, 0, 2, 5, 4, 0],
    [0, 4, 2, 4, 5, 7, 5, 2, 4, 0],
    [3, 0, 3, 5, 7, 5, 3, 0, 2, 3],
    [0, 2, 5, 4, 7, 9, 7, 4, 5, 2, 0],
    [4, 4, 2, 5, 5, 4, 0, 2, 4, 5],
    [0, 7, 5, 7, 4, 5, 2, 4, 0],
    [2, 5, 4, 0, 2, 5, 7, 5, 4, 0],
    [0, 2, 4, 5, 2, 4, 0, 5, 4, 7, 0],
    [5, 7, 5, 4, 2, 4, 0, 2, 5, 4],
    [0, 4, 7, 9, 5, 7, 4, 2, 0, 4],
    [2, 2, 5, 4, 4, 0, 2, 5, 4, 0],
    [0, 5, 5, 4, 2, 4, 7, 5, 0],
    [4, 2, 0, 5, 4, 2, 7, 5, 4, 0],
    [0, 2, 7, 5, 4, 2, 4, 0, 5, 4],
    [1, 3, 5, 4, 2, 0, 2, 4, 5, 3, 1],
    [0, 4, 5, 9, 7, 5, 4, 2, 0],
    [2, 0, 5, 4, 7, 5, 2, 0, 4],
    [0, 0, 5, 7, 5, 4, 2, 4, 0, 0],
    [4, 5, 2, 4, 0, 5, 4, 2, 0, 4],
    [0, 3, 2, 5, 4, 7, 5, 3, 0],
    [7, 5, 2, 4, 0, 2, 5, 4, 7],
    [0, 2, 4, 0, 7, 5, 4, 2, 5, 0],
    [2, 4, 5, 0, 4, 5, 7, 4, 2, 0],
    [0, 5, 4, 2, 5, 0, 4, 7, 5, 0],
    [4, 0, 5, 2, 4, 7, 5, 4, 0],
    [0, 2, 2, 0, 5, 5, 4, 2, 4, 0],
    [5, 4, 0, 2, 4, 5, 2, 0, 4],
    [0, 4, 4, 0, 5, 7, 5, 2, 0],
    [2, 5, 7, 5, 0, 2, 4, 5, 0],
    [0, 7, 0, 5, 4, 2, 4, 5, 0],
    [3, 5, 0, 3, 7, 5, 3, 2, 0],
    [0, 2, 5, 0, 4, 7, 5, 2, 0],
    [4, 5, 7, 0, 4, 2, 5, 4, 0],
    [0, 0, 4, 7, 5, 5, 2, 4, 0],
    [2, 4, 0, 2, 7, 5, 4, 0, 2],
    [0, 5, 2, 0, 4, 5, 7, 4, 0],
    [5, 2, 4, 0, 5, 7, 4, 2, 0],
    [0, 4, 2, 5, 0, 7, 5, 4, 0],
    [2, 0, 4, 5, 2, 7, 5, 0, 2],
    [0, 2, 4, 5, 7, 4, 0, 2, 5, 4, 0],
    [4, 7, 5, 2, 0, 4, 5, 2, 0],
    [0, 5, 7, 4, 2, 0, 5, 4, 2, 0],
    [2, 5, 0, 7, 5, 4, 2, 0, 4],
    [0, 4, 5, 2, 7, 0, 5, 4, 0],
    [5, 0, 2, 4, 7, 5, 0, 4, 2],
    [0, 2, 7, 4, 5, 0, 2, 4, 0],
    [4, 2, 5, 0, 7, 5, 2, 4, 0],
    [0, 0, 2, 4, 7, 5, 5, 4, 2, 0],
    [2, 4, 5, 7, 0, 5, 4, 2, 0],
    [0, 5, 4, 0, 2, 7, 5, 4, 0],
    [3, 0, 5, 3, 7, 5, 0, 3],
    [0, 4, 0, 5, 2, 4, 7, 5, 0],
    [2, 0, 2, 4, 0, 5, 7, 5, 4, 0],
    [0, 7, 5, 0, 4, 2, 5, 4, 0],
    [4, 5, 0, 2, 4, 7, 0, 5, 4],
    [0, 2, 5, 7, 0, 4, 5, 2, 0],
    [5, 4, 2, 5, 0, 4, 7, 0],
    [0, 4, 7, 2, 5, 0, 4, 5, 0],
    [2, 5, 4, 7, 0, 2, 5, 4, 0],
    [0, 0, 5, 2, 4, 7, 5, 0, 4],
    [4, 0, 2, 7, 5, 0, 4, 2, 0],
    [0, 2, 4, 0, 5, 0, 7, 5, 4, 0],
    [5, 7, 0, 4, 2, 5, 0, 4],
    [0, 4, 5, 7, 0, 2, 5, 4, 0],
    [2, 0, 5, 7, 4, 0, 2, 4, 0],
    [0, 5, 0, 4, 7, 5, 2, 0],
    [4, 2, 0, 4, 5, 0, 7, 5, 0],
    [0, 2, 0, 4, 5, 7, 5, 0, 2, 0],
  ];

  static int get tuneCount => _catalogSize * _centreCount;

  /// MIDI notes of the tune for [levelId], in playing order.
  static List<int> forLevel(int levelId) {
    final index = levelId < 1 ? 0 : levelId - 1;
    // Use frozen [_catalogSize] (not _songs.length) so appending songs later
    // never reshuffles which level hears which tune.
    final song = _songs[index % _catalogSize];
    final centre = (index ~/ _catalogSize) % _centreCount;

    final degrees = [for (final degree in song) centre + degree];
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
