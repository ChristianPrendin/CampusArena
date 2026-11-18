import 'package:flutter/material.dart';

import '../../../models/tournament_model.dart';
import '../cubit/tournament_browser_state.dart';
import '../tournament_ui.dart';

/// UPCOMING card (browser.png): sport tile, name, schedule line (+ sun icon when
/// outdoor), status pill, then a `n/max` progress row. Registration happens on
/// the detail screen, so the whole card taps through with no inline action.
class UpcomingTournamentCard extends StatelessWidget {
  const UpcomingTournamentCard({
    super.key,
    required this.tournament,
    required this.info,
    required this.onTap,
  });

  final TournamentModel tournament;
  final TournamentCardInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = tournament.maxParticipants == 0
        ? 0.0
        : (tournament.participantCount / tournament.maxParticipants).clamp(
            0.0,
            1.0,
          );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TournamentSportTile(sportId: tournament.sportId),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                tournamentScheduleLine(
                                  context,
                                  tournament.scheduledAt,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (info.outdoor) ...[
                              const SizedBox(width: 5),
                              Icon(
                                Icons.wb_sunny,
                                size: 14,
                                color: theme.colorScheme.tertiary,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TournamentStatusPill(status: tournament.status),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${tournament.participantCount}/${tournament.maxParticipants}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ONGOING card (browser.png): sport tile, name, `n/max · time` line, and a
/// status pill. The whole card taps through to detail — there is no inline
/// action button, since the detail screen surfaces the tournament's controls.
class OngoingTournamentCard extends StatelessWidget {
  const OngoingTournamentCard({
    super.key,
    required this.tournament,
    required this.onTap,
  });

  final TournamentModel tournament;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line =
        '${tournament.participantCount}/${tournament.maxParticipants} · '
        '${tournamentScheduleLine(context, tournament.scheduledAt)}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            children: [
              TournamentSportTile(sportId: tournament.sportId),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TournamentStatusPill(status: tournament.status),
            ],
          ),
        ),
      ),
    );
  }
}
