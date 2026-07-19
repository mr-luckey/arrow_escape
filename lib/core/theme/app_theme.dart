import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_theme_extension.dart';

abstract final class AppTheme {
  static ThemeData light(AppColorSchemeId schemeId) {
    final colors = schemeId.colors;
    final baseText = GoogleFonts.nunitoTextTheme();
    final display = GoogleFonts.fredoka();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: colors.primary,
        secondary: colors.secondary,
        tertiary: colors.accent,
        surface: colors.surface,
        onSurface: colors.onSurface,
        error: colors.danger,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: baseText.copyWith(
        displayLarge: display.copyWith(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
        displayMedium: display.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
        headlineMedium: display.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: colors.onSurface,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(color: colors.onSurface),
        bodyMedium: baseText.bodyMedium?.copyWith(color: colors.muted),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.onSurface,
          backgroundColor: colors.surface.withValues(alpha: 0.85),
        ),
      ),
      extensions: [
        AppThemeExtension(colors: colors, schemeId: schemeId),
      ],
    );
  }
}
