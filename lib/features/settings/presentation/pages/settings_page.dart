import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../bloc/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final padding = Breakpoints.pagePadding(context);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
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
                      'Settings',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, state) {
                    return Column(
                      children: [
                        _Tile(
                          title: 'Sound',
                          subtitle: 'Soft cue tones (coming with polish)',
                          trailing: Switch(
                            value: state.soundEnabled,
                            activeThumbColor: colors.secondary,
                            onChanged: (_) =>
                                context.read<SettingsCubit>().toggleSound(),
                          ),
                        ),
                        _Tile(
                          title: 'Haptics',
                          subtitle: 'Vibrate on taps and misses',
                          trailing: Switch(
                            value: state.hapticsEnabled,
                            activeThumbColor: colors.secondary,
                            onChanged: (_) =>
                                context.read<SettingsCubit>().toggleHaptics(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Color Scheme',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                BlocBuilder<ThemeCubit, AppColorSchemeId>(
                  builder: (context, scheme) {
                    return Column(
                      children: AppColorSchemeId.values.map((id) {
                        final selected = id == scheme;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: selected
                                      ? colors.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              title: Text(id.label),
                              trailing: selected
                                  ? Icon(Icons.check_circle, color: colors.primary)
                                  : null,
                              onTap: () =>
                                  context.read<ThemeCubit>().setScheme(id),
                              leading: CircleAvatar(
                                backgroundColor: id.colors.primary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}
