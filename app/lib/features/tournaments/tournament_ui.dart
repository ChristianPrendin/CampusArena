import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/match_display.dart';
import '../../l10n/app_localizations.dart';

/// Status → colour, mapped onto ColorScheme roles per the design tokens
/// (`tstColor`): registering → primary (green), seeded → secondary (violet),
/// active → tertiary (amber), completed/cancelled → muted/error. Never a raw
/// hex, per the theming rule.
Color tournamentStatusColor(ColorScheme colors, String status) {
  switch (status) {
    case TournamentStatus.registering:
      return colors.primary;
    case TournamentStatus.seeded:
      return colors.secondary;
    case TournamentStatus.active:
      return colors.tertiary;
    case TournamentStatus.cancelled:
      return colors.error;
    case TournamentStatus.completed:
    default:
      return colors.onSurfaceVariant;
  }
}

String tournamentStatusLabel(AppLocalizations l10n, String status) {
  switch (status) {
    case TournamentStatus.registering:
      return l10n.tournamentStatusRegistering;
    case TournamentStatus.seeded:
      return l10n.tournamentStatusSeeded;
    case TournamentStatus.active:
      return l10n.tournamentStatusActive;
    case TournamentStatus.cancelled:
      return l10n.tournamentStatusCancelled;
    case TournamentStatus.completed:
    default:
      return l10n.tournamentStatusCompleted;
  }
}

/// The single localized bracket round-name mapper, over the exact round keys the
/// bracket engine emits (`round_of_32`, `round_of_16`, `quarterfinal`,
/// `semifinal`, `final`; see `roundKeysForSize`). Used by both the bracket
/// column headers and the organizer sheets so the copy can never diverge. A key
/// beyond the campus-scale bracket (≤ 32) falls back to the raw key.
String tournamentRoundLabel(AppLocalizations l10n, String roundKey) =>
    switch (roundKey) {
      'round_of_32' => l10n.roundOf32,
      'round_of_16' => l10n.roundOf16,
      'quarterfinal' => l10n.roundQuarterfinal,
      'semifinal' => l10n.roundSemifinal,
      'final' => l10n.roundFinal,
      _ => roundKey,
    };

/// "Today · 18:00" / "Tomorrow · 15:00" / "Aug 8 · 16:30" — the schedule line
/// under a tournament name. [now] is injectable for tests.
String tournamentScheduleLine(
  BuildContext context,
  DateTime scheduledAt, {
  DateTime? now,
}) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
  final diff = day.difference(today).inDays;

  final String dayLabel;
  if (diff == 0) {
    dayLabel = l10n.tournamentToday;
  } else if (diff == 1) {
    dayLabel = l10n.tournamentTomorrow;
  } else {
    dayLabel = DateFormat.MMMd(locale).format(scheduledAt);
  }
  final time = DateFormat.Hm(locale).format(scheduledAt);
  return '$dayLabel · $time';
}

/// The rounded sport glyph tile shown at the leading edge of every tournament
/// card and, larger, nowhere else. Mirrors the design's 40dp secondary-container
/// square.
class TournamentSportTile extends StatelessWidget {
  const TournamentSportTile({super.key, required this.sportId, this.size = 40});

  final String sportId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(size * 0.275),
      ),
      child: Icon(sportIcon(sportId), size: size * 0.55, color: colors.primary),
    );
  }
}

/// Tinted capsule showing a tournament's localized status, coloured by
/// [tournamentStatusColor].
class TournamentStatusPill extends StatelessWidget {
  const TournamentStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tournamentStatusColor(theme.colorScheme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tournamentStatusLabel(AppLocalizations.of(context), status),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
