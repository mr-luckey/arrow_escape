import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../di/injection.dart';
import '../theme/app_theme_extension.dart';
import '../widgets/app_widgets.dart';
import 'app_store_service.dart';

/// Soft "Rate this app" card — matches app surfaces, not a hard modal block.
Future<void> showRateAppDialog(BuildContext context) async {
  final store = sl<AppStoreService>();
  await store.markRatePromptShown();

  if (!context.mounted) return;

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss rate dialog',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: const _RateAppCard(),
        ),
      );
    },
  );
}

class _RateAppCard extends StatelessWidget {
  const _RateAppCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final store = sl<AppStoreService>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: AppCard(
          elevation: 12,
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppBrandLogo(size: 72)
                  .animate()
                  .scale(duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 12),
              Text(
                'Enjoying ColorPath Out?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'A quick rating helps more puzzle fans find the game. Thanks!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.muted,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: 'Rate this app',
                icon: Icons.favorite_rounded,
                onPressed: () async {
                  Navigator.of(context).pop();
                  await store.requestReviewOrOpenStore();
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  store.markDeclined();
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(foregroundColor: colors.muted),
                child: const Text('Maybe later'),
              ),
              TextButton(
                onPressed: () {
                  store.markNeverAsk();
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(foregroundColor: colors.muted),
                child: const Text('No thanks'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
