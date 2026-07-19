import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../bloc/game_bloc.dart';

class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.levelLabel,
    required this.hearts,
    required this.maxHearts,
    required this.onReset,
    required this.onHint,
    required this.onTheme,
    required this.onBack,
  });

  final String levelLabel;
  final int hearts;
  final int maxHearts;
  final VoidCallback onReset;
  final VoidCallback onHint;
  final VoidCallback onTheme;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Row(
          children: [
            SoftIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
              tooltip: 'Back',
            ),
            const SizedBox(width: 8),
            SoftIconButton(
              icon: Icons.refresh_rounded,
              onPressed: onReset,
              tooltip: 'Reset',
            ),
            const Spacer(),
            SoftIconButton(
              icon: Icons.palette_rounded,
              onPressed: onTheme,
              tooltip: 'Theme',
              background: colors.accent.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 8),
            SoftIconButton(
              icon: Icons.lightbulb_rounded,
              onPressed: onHint,
              tooltip: 'Hint',
              background: colors.secondary.withValues(alpha: 0.25),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            levelLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(maxHearts, (i) {
            final filled = i < hearts;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                filled ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: filled ? colors.heart : colors.muted.withValues(alpha: 0.45),
                size: 28,
              )
                  .animate(target: filled ? 0 : 1)
                  .scaleXY(begin: 1, end: 0.85, duration: 200.ms),
            );
          }),
        ),
      ],
    );
  }
}

class WinOverlay extends StatelessWidget {
  const WinOverlay({
    super.key,
    required this.stars,
    required this.onNext,
    required this.onReplay,
    required this.onHome,
    this.hasNext = true,
  });

  final int stars;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onHome;
  final bool hasNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cleared!',
              style: Theme.of(context).textTheme.displayMedium,
            )
                .animate()
                .fadeIn()
                .scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final lit = i < stars;
                return Icon(
                  Icons.star_rounded,
                  size: 42,
                  color: lit ? colors.accent : colors.muted.withValues(alpha: 0.3),
                )
                    .animate(delay: (i * 120).ms)
                    .scale(begin: const Offset(0.2, 0.2))
                    .fadeIn();
              }),
            ),
            const SizedBox(height: 24),
            if (hasNext) ...[
              AppPrimaryButton(label: 'Next Level', onPressed: onNext),
              const SizedBox(height: 10),
            ],
            AppSecondaryButton(label: 'Replay', onPressed: onReplay),
            const SizedBox(height: 10),
            TextButton(onPressed: onHome, child: const Text('Home')),
          ],
        ),
      ).animate().slideY(begin: 0.2, duration: 350.ms).fadeIn(),
    );
  }
}

class LoseOverlay extends StatelessWidget {
  const LoseOverlay({
    super.key,
    required this.onRetry,
    required this.onHome,
  });

  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.heart_broken_rounded, size: 56, color: colors.heart)
                .animate()
                .shake(),
            const SizedBox(height: 12),
            Text('Out of Hearts', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Plan the exit order carefully and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(label: 'Retry', onPressed: onRetry),
            const SizedBox(height: 10),
            TextButton(onPressed: onHome, child: const Text('Home')),
          ],
        ),
      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

/// Bridge used by game page for animation-driven exit progress without setState.
class ExitAnimationGate extends StatelessWidget {
  const ExitAnimationGate({
    super.key,
    required this.status,
    required this.animationKey,
    required this.child,
    required this.onCompleted,
  });

  final GameStatus status;
  final String? animationKey;
  final Widget Function(double progress) child;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    if (status != GameStatus.animating || animationKey == null) {
      return child(0);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(animationKey),
      tween: Tween(begin: 0, end: 1),
      // Longer so the path-follow pull-out reads clearly.
      duration: const Duration(milliseconds: 680),
      curve: Curves.easeInOutCubic,
      onEnd: onCompleted,
      builder: (context, value, _) => child(value),
    );
  }
}
