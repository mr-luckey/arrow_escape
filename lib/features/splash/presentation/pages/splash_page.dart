import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/widgets/app_widgets.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Hard navigation fallback — never stay stuck on splash.
    Future<void>.delayed(const Duration(milliseconds: 1400), _goHome);
  }

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppBrandLogo(size: 112)
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .fadeIn(),
              const SizedBox(height: 16),
              Text(
                'ColorPath Out',
                style: Theme.of(context).textTheme.displayMedium,
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
              const SizedBox(height: 28),
              SizedBox(
                width: 160,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1100),
                  onEnd: _goHome,
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: colors.surface.withValues(alpha: 0.6),
                        color: colors.secondary,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
