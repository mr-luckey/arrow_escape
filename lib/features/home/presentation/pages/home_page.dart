import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/ads_service.dart';
import '../../../../core/ads/banner_ad_slot.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/store/app_store_service.dart';
import '../../../../core/store/rate_app_dialog.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../game/domain/entities/game_entities.dart';
import '../../../levels/presentation/bloc/progress_cubit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_onHomeReady());
    });
  }

  Future<void> _onHomeReady() async {
    final store = sl<AppStoreService>();
    try {
      await store.prepareSession().timeout(const Duration(seconds: 2));
    } catch (_) {}
    // Never await update check on the critical UI path.
    unawaited(store.checkForUpdate());

    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    if (store.shouldShowRatePrompt()) {
      await showRateAppDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = Breakpoints.pagePadding(context);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: padding,
            child: Column(
              children: [
                const Spacer(flex: 2),
                _HomeTitle()
                    .animate()
                    .fadeIn(duration: 480.ms)
                    .slideY(begin: -0.1, curve: Curves.easeOutCubic)
                    .scale(
                      begin: const Offset(0.92, 0.92),
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 10),
                Text(
                  'Slide every arrow free',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        shadows: const [
                          Shadow(
                            color: Color(0x99000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                )
                    .animate(delay: 120.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2),
                const Spacer(flex: 2),
                BlocBuilder<ProgressCubit, ProgressState>(
                  builder: (context, progress) {
                    if (progress.loading || progress.levels.isEmpty) {
                      return const SizedBox(
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return _HomeLevelPath(progress: progress);
                  },
                ),
                const SizedBox(height: 22),
                BlocBuilder<ProgressCubit, ProgressState>(
                  builder: (context, progress) {
                    final maxId =
                        progress.levels.isEmpty ? 1000 : progress.levels.length;
                    final continueId = progress.highestUnlocked.clamp(1, maxId);
                    return AppPrimaryButton(
                      label: progress.highestUnlocked > 1
                          ? 'Continue Level $continueId'
                          : 'Play',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => context.go('/game/$continueId'),
                    )
                        .animate(delay: 180.ms)
                        .fadeIn()
                        .slideY(begin: 0.15);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HomeLinkChip(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      onPressed: () {
                        unawaited(
                          sl<AdsService>().runAfterInterstitialBreak(
                            placement: 'open_settings',
                            onContinue: () {
                              if (context.mounted) {
                                context.go('/settings');
                              }
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _HomeLinkChip(
                      icon: Icons.help_outline_rounded,
                      label: 'How to Play',
                      onPressed: () {
                        unawaited(
                          sl<AdsService>().runAfterInterstitialBreak(
                            placement: 'section_transition',
                            onContinue: () {
                              if (context.mounted) {
                                context.go('/howto');
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ],
                )
                    .animate(delay: 240.ms)
                    .fadeIn(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const BannerAdSlot(
          placement: 'home',
          refreshInterval: Duration(seconds: 60),
        ),
      ),
    );
  }
}

/// High-contrast brand title that stays readable on photo backgrounds.
class _HomeTitle extends StatelessWidget {
  const _HomeTitle();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = Theme.of(context).textTheme.displayLarge?.copyWith(
          fontSize: 42,
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: 0.4,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.primary, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: c.onSurface.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Arrow',
              style: base?.copyWith(color: c.primary),
            ),
            TextSpan(
              text: ' Path ',
              style: base?.copyWith(color: c.onSurface),
            ),
            TextSpan(
              text: 'Out',
              style: base?.copyWith(color: c.secondary),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _HomeLinkChip extends StatelessWidget {
  const _HomeLinkChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface.withValues(alpha: 0.92),
      elevation: 2,
      shadowColor: colors.onSurface.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal left-to-right level path with animated connectors.
class _HomeLevelPath extends StatefulWidget {
  const _HomeLevelPath({required this.progress});

  final ProgressState progress;

  @override
  State<_HomeLevelPath> createState() => _HomeLevelPathState();
}

class _HomeLevelPathState extends State<_HomeLevelPath>
    with SingleTickerProviderStateMixin {
  static const _tileSize = 76.0;
  static const _connectorWidth = 36.0;
  static const _itemStride = _tileSize + _connectorWidth;

  late final ScrollController _scrollController;
  late final AnimationController _pathController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _pathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrent();
    });
  }

  @override
  void didUpdateWidget(covariant _HomeLevelPath oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress.highestUnlocked !=
        widget.progress.highestUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrent();
      });
    }
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    final levels = widget.progress.levels;
    if (levels.isEmpty) return;

    final targetId = widget.progress.highestUnlocked.clamp(1, levels.length);
    final index = levels.indexWhere((l) => l.id == targetId);
    if (index < 0) return;

    final viewport = _scrollController.position.viewportDimension;
    final offset = (index * _itemStride) - (viewport - _tileSize) / 2;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final levels = widget.progress.levels;
    final progress = widget.progress;

    return SizedBox(
      height: _tileSize + 8,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: levels.length,
        itemBuilder: (context, index) {
          final level = levels[index];
          final unlocked = progress.isUnlocked(level.id);
          final stars = progress.starsFor(level.id);
          final isCurrent = level.id == progress.highestUnlocked;

          return Row(
            children: [
              if (index > 0)
                _PathConnector(
                  width: _connectorWidth,
                  height: _tileSize,
                  progress: _pathController,
                  active: progress.isUnlocked(levels[index - 1].id),
                  color: colors.primary,
                  muted: colors.muted,
                ),
              _LevelPathTile(
                size: _tileSize,
                level: level,
                unlocked: unlocked,
                stars: stars,
                isCurrent: isCurrent,
                index: index,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Level container copied from [LevelSelectPage] tile styling.
class _LevelPathTile extends StatelessWidget {
  const _LevelPathTile({
    required this.size,
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.isCurrent,
    required this.index,
  });

  final double size;
  final LevelEntity level;
  final bool unlocked;
  final int stars;
  final bool isCurrent;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        // Solid surface so locked tiles stay visible on busy backgrounds.
        color: colors.surface.withValues(alpha: unlocked ? 1 : 0.92),
        elevation: unlocked ? 3 : 2,
        shadowColor: colors.onSurface.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: unlocked ? () => context.go('/game/${level.id}') : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: !unlocked
                    ? colors.primary
                    : isCurrent
                        ? colors.secondary
                        : colors.boardBorder,
                width: !unlocked || isCurrent ? 2.5 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!unlocked) ...[
                  Icon(
                    Icons.lock_rounded,
                    color: colors.primary.withValues(alpha: 0.85),
                    size: 24,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${level.id}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ] else ...[
                  Text(
                    '${level.id}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: colors.primary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: i < stars
                            ? colors.accent
                            : colors.muted.withValues(alpha: 0.3),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: ((index > 16 ? 16 : index) * 28).ms)
        .fadeIn(duration: 320.ms)
        .scale(begin: const Offset(0.88, 0.88), curve: Curves.easeOutBack);
  }
}

class _PathConnector extends StatelessWidget {
  const _PathConnector({
    required this.width,
    required this.height,
    required this.progress,
    required this.active,
    required this.color,
    required this.muted,
  });

  final double width;
  final double height;
  final Animation<double> progress;
  final bool active;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          return CustomPaint(
            painter: _PathDashPainter(
              dashOffset: progress.value,
              active: active,
              color: color,
              muted: muted,
            ),
          );
        },
      ),
    );
  }
}

class _PathDashPainter extends CustomPainter {
  _PathDashPainter({
    required this.dashOffset,
    required this.active,
    required this.color,
    required this.muted,
  });

  final double dashOffset;
  final bool active;
  final Color color;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = active ? color.withValues(alpha: 0.85) : muted.withValues(alpha: 0.35);

    final path = Path();
    final midY = size.height * 0.42;
    final amp = size.height * 0.12;
    path.moveTo(0, midY);
    path.cubicTo(
      size.width * 0.35,
      midY - amp,
      size.width * 0.65,
      midY + amp,
      size.width,
      midY,
    );

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    const dashLen = 7.0;
    const gapLen = 5.0;
    final cycle = dashLen + gapLen;
    final shift = active ? dashOffset * cycle : 0.0;

    for (final metric in metrics) {
      var distance = -shift;
      while (distance < metric.length) {
        final start = math.max(distance, 0.0);
        final end = math.min(distance + dashLen, metric.length);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), paint);
        }
        distance += cycle;
      }

      // Soft glowing dot that travels along completed paths.
      if (active) {
        final t = dashOffset % 1.0;
        final pos = metric.getTangentForOffset(t * metric.length)?.position;
        if (pos != null) {
          canvas.drawCircle(
            pos,
            4.5,
            Paint()..color = color.withValues(alpha: 0.9),
          );
          canvas.drawCircle(
            pos,
            8,
            Paint()..color = color.withValues(alpha: 0.22),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathDashPainter oldDelegate) {
    return oldDelegate.dashOffset != dashOffset ||
        oldDelegate.active != active ||
        oldDelegate.color != color ||
        oldDelegate.muted != muted;
  }
}
