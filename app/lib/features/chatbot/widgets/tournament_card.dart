import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../features/tournaments/tournament_ui.dart';
import '../../../l10n/app_localizations.dart';
import '../data/tool_results.dart';

/// Rich card rendered inside an assistant message when the "tournaments
/// today" tool fired: name, sport, time, participants as "x/max", a status
/// chip, and a "View" action.
class TournamentCard extends StatelessWidget {
  const TournamentCard({super.key, required this.tournaments, this.onView});

  final List<TournamentToolResult> tournaments;
  final ValueChanged<String>? onView;

  IconData _sportIcon(String sportId) {
    switch (sportId) {
      case SportIds.pingPong:
        return Icons.sports_tennis;
      case SportIds.foosball:
        return Icons.sports_soccer;
      default:
        return Icons.sports;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tournament in tournaments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _sportIcon(tournament.sportId),
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament.name,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          '${TimeOfDay.fromDateTime(tournament.scheduledAt).format(context)} · '
                          '${tournament.participantCount}/${tournament.maxParticipants}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TournamentStatusPill(status: tournament.status),
                  if (onView != null)
                    TextButton(
                      onPressed: () => onView!(tournament.tournamentId),
                      child: Text(l10n.chatbotViewTournament),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
