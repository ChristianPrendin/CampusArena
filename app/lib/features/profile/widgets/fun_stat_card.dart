import 'package:flutter/material.dart';

import '../../../core/widgets/identity_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../profile_stats.dart';

/// One gated fun-stat card (Black Beast / Favorite Victim): an accent-colored
/// title row, the opponent's identity avatar and name, and the head-to-head
/// tally from the profile owner's perspective.
class FunStatCard extends StatelessWidget {
  const FunStatCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.tally,
    this.opponentName,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final OpponentTally tally;

  /// Resolved display name; falls back to a placeholder avatar-only row while
  /// the uid → name cache is still filling.
  final String? opponentName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IdentityAvatar(
                  seed: tally.opponentUid,
                  initials: initialsFromName(opponentName),
                  radius: 17,
                  fontSize: 12,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opponentName ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l10n.profileHeadToHeadTally(tally.wins, tally.losses),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
