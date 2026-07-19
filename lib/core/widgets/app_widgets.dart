import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme_extension.dart';

/// Brand asset paths for ColorPath Out.
abstract final class BrandAssets {
  /// Official logo (transparent around the icon) — use everywhere in-app.
  static const logo = 'assets/images/brand/app_logo.png';
}

/// Official ColorPath Out logo (transparent background, unchanged art).
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.size = 96,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      BrandAssets.logo,
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
  }
}

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final colors = theme.colors;
    final asset = theme.schemeId.backgroundAsset;

    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.gradientTop, colors.gradientBottom],
        ),
      ),
      child: child,
    );

    if (asset == null) return gradient;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Soft theme-tinted fallback while image loads / behind letterbox.
        ColoredBox(color: colors.gradientBottom),
        Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
        child,
      ],
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final child = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 5,
        shadowColor: colors.primary.withValues(alpha: 0.45),
        minimumSize: Size(expanded ? double.infinity : 160, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22),
            const SizedBox(width: 10),
          ],
          Text(label),
        ],
      ),
    );

    return child
        .animate()
        .fadeIn(duration: 350.ms)
        .scale(begin: const Offset(0.96, 0.96), curve: Curves.easeOutBack);
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface.withValues(alpha: 0.55),
      elevation: 3,
      shadowColor: colors.onSurface.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          side: BorderSide(color: colors.secondary, width: 2),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label),
      ),
    );
  }
}

class SoftIconButton extends StatelessWidget {
  const SoftIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.background,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: background ?? colors.surface,
          elevation: enabled ? 4 : 0,
          shadowColor: colors.onSurface.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, color: colors.onSurface, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared elevated surface used across home, game, settings, and levels.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation = 6,
    this.borderRadius = 20,
    this.color,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double elevation;
  final double borderRadius;
  final Color? color;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: color ?? colors.surface,
        elevation: elevation,
        shadowColor: colors.onSurface.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: clipBehavior,
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}
