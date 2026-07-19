import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/widgets/app_widgets.dart';

class HowToPlayPage extends StatelessWidget {
  const HowToPlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final padding = Breakpoints.pagePadding(context);
    final steps = [
      (
        Icons.touch_app_rounded,
        'Tap an arrow',
        'Choose any colorful path on the board.',
      ),
      (
        Icons.route_rounded,
        'Clear the exit',
        'It only slides out if the path from its tip to the edge is empty.',
      ),
      (
        Icons.favorite_rounded,
        'Mind your hearts',
        'A blocked tap costs a heart. Clear every arrow to win.',
      ),
    ];

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: padding.copyWith(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SoftIconButton(
                            icon: Icons.arrow_back_rounded,
                            onPressed: () => context.go('/'),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'How to Play',
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ...steps.asMap().entries.map((entry) {
                        final i = entry.key;
                        final (icon, title, body) = entry.value;
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: colors.arrowPalette[i]
                                    .withValues(alpha: 0.2),
                                child:
                                    Icon(icon, color: colors.arrowPalette[i]),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${i + 1}. $title',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(body),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate(delay: (i * 120).ms)
                            .fadeIn()
                            .slideX(begin: 0.08);
                      }),
                      const Spacer(),
                      AppPrimaryButton(
                        label: 'Got it — Play',
                        onPressed: () => context.go('/game/1'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const BannerAdWidget(height: 50),
              SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ),
    );
  }
}
