import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.colors,
    required this.schemeId,
    this.radiusLg = 28,
    this.radiusMd = 18,
    this.radiusSm = 12,
  });

  final AppColors colors;
  final AppColorSchemeId schemeId;
  final double radiusLg;
  final double radiusMd;
  final double radiusSm;

  @override
  AppThemeExtension copyWith({
    AppColors? colors,
    AppColorSchemeId? schemeId,
    double? radiusLg,
    double? radiusMd,
    double? radiusSm,
  }) {
    return AppThemeExtension(
      colors: colors ?? this.colors,
      schemeId: schemeId ?? this.schemeId,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusSm: radiusSm ?? this.radiusSm,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppThemeX on BuildContext {
  AppThemeExtension get appTheme =>
      Theme.of(this).extension<AppThemeExtension>() ??
      const AppThemeExtension(
        colors: AppColors.sky,
        schemeId: AppColorSchemeId.sky,
      );

  AppColors get colors => appTheme.colors;
}
