import 'package:flutter/material.dart';

/// Bright brand palettes for ColorPath Out.
class AppColors {
  const AppColors({
    required this.gradientTop,
    required this.gradientBottom,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.heart,
    required this.boardFill,
    required this.boardBorder,
    required this.surface,
    required this.onSurface,
    required this.muted,
    required this.success,
    required this.danger,
    required this.arrowPalette,
  });

  final Color gradientTop;
  final Color gradientBottom;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color heart;
  final Color boardFill;
  final Color boardBorder;
  final Color surface;
  final Color onSurface;
  final Color muted;
  final Color success;
  final Color danger;
  final List<Color> arrowPalette;

  static const sky = AppColors(
    gradientTop: Color(0xFFE8F7FF),
    gradientBottom: Color(0xFFFFF8E7),
    primary: Color(0xFFFF5A5F),
    secondary: Color(0xFF00C2A8),
    accent: Color(0xFFFFC145),
    heart: Color(0xFFFF4D6D),
    boardFill: Color(0xFFFFFFF8),
    boardBorder: Color(0xFFE2EEF5),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1B2B34),
    muted: Color(0xFF6B7C86),
    success: Color(0xFF22C55E),
    danger: Color(0xFFFF5A5F),
    arrowPalette: [
      Color(0xFFFF5A5F),
      Color(0xFF00C2A8),
      Color(0xFF7C5CFF),
      Color(0xFFFFC145),
      Color(0xFF00B4D8),
      Color(0xFFFF8A5B),
    ],
  );

  static const ocean = AppColors(
    gradientTop: Color(0xFFE0F7FA),
    gradientBottom: Color(0xFFE8F5E9),
    primary: Color(0xFF00897B),
    secondary: Color(0xFF039BE5),
    accent: Color(0xFFFFCA28),
    heart: Color(0xFFE53935),
    boardFill: Color(0xFFF7FFFE),
    boardBorder: Color(0xFFD0EBE8),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0D3B3B),
    muted: Color(0xFF5A7A7A),
    success: Color(0xFF43A047),
    danger: Color(0xFFE53935),
    arrowPalette: [
      Color(0xFF00897B),
      Color(0xFF039BE5),
      Color(0xFF5E35B1),
      Color(0xFFFFCA28),
      Color(0xFF26A69A),
      Color(0xFFFF7043),
    ],
  );

  static const sunset = AppColors(
    gradientTop: Color(0xFFFFF3E0),
    gradientBottom: Color(0xFFFFEBEE),
    primary: Color(0xFFFF6F00),
    secondary: Color(0xFFFF4081),
    accent: Color(0xFFFFD54F),
    heart: Color(0xFFFF1744),
    boardFill: Color(0xFFFFFBF5),
    boardBorder: Color(0xFFFFE0B2),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF3E2723),
    muted: Color(0xFF8D6E63),
    success: Color(0xFF66BB6A),
    danger: Color(0xFFFF6F00),
    arrowPalette: [
      Color(0xFFFF6F00),
      Color(0xFFFF4081),
      Color(0xFFAB47BC),
      Color(0xFFFFD54F),
      Color(0xFFFF7043),
      Color(0xFF42A5F5),
    ],
  );
}

enum AppColorSchemeId { sky, ocean, sunset }

extension AppColorSchemeIdX on AppColorSchemeId {
  AppColors get colors => switch (this) {
        AppColorSchemeId.sky => AppColors.sky,
        AppColorSchemeId.ocean => AppColors.ocean,
        AppColorSchemeId.sunset => AppColors.sunset,
      };

  String get label => switch (this) {
        AppColorSchemeId.sky => 'Sky Pop',
        AppColorSchemeId.ocean => 'Ocean Glow',
        AppColorSchemeId.sunset => 'Sunset Burst',
      };

  /// Full-bleed theme background. Null = use gradient fallback.
  String? get backgroundAsset => switch (this) {
        AppColorSchemeId.sunset =>
          'assets/images/backgrounds/bg_sunset.png',
        AppColorSchemeId.sky => 'assets/images/backgrounds/bg_sky.png',
        AppColorSchemeId.ocean => 'assets/images/backgrounds/bg_ocean.png',
      };
}
