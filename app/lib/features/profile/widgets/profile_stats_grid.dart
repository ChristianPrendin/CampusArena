import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../profile_stats.dart';

/// The 3×2 stat-tile grid: games, wins, losses on the first row; win rate,
/// current streak, all-time best streak on the second — per the design's
/// profile stats grid.
class ProfileStatsGrid extends StatelessWidget {
  const ProfileStatsGrid({super.key, required this.stats});

  final SportStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    Widget row(List<Widget> tiles) => Row(
      children: [
        for (final tile in tiles) ...[
          if (tile != tiles.first) const SizedBox(width: 8),
          Expanded(child: tile),
        ],
      ],
    );

    return Column(
      children: [
        row([
          _StatTile(
            icon: Icons.sports_esports_outlined,
            iconColor: colors.onSurface,
            value: '${stats.games}',
            label: l10n.profileStatGames,
          ),
          _StatTile(
            icon: Icons.emoji_events_outlined,
            iconColor: colors.primary,
            value: '${stats.wins}',
            label: l10n.profileStatWins,
          ),
          _StatTile(
            icon: Icons.do_not_disturb_on_outlined,
            iconColor: colors.error,
            value: '${stats.losses}',
            label: l10n.profileStatLosses,
          ),
        ]),
        const SizedBox(height: 8),
        row([
          _StatTile(
            icon: Icons.percent,
            iconColor: colors.primary,
            value: l10n.profileWinRateValue((stats.winRate * 100).round()),
            label: l10n.profileStatWinRate,
          ),
          _StatTile(
            icon: Icons.local_fire_department_outlined,
            iconColor: colors.tertiary,
            value: '${stats.currentStreak}',
            label: l10n.profileStatStreak,
          ),
          _StatTile(
            icon: Icons.military_tech_outlined,
            iconColor: colors.onSurface,
            value: '${stats.bestStreak}',
            label: l10n.profileStatBest,
          ),
        ]),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
