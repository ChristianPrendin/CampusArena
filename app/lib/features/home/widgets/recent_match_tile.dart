import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/match_display.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/match_model.dart';

/// A single row in the dashboard's recent-match history: a colour-coded
/// opponent avatar, the opponent name over the score, and the signed ELO delta
/// (green gain / red loss). Non-terminal-but-shown states (disputed, abandoned,
/// unconfirmed) show a status label instead of a delta.
class RecentMatchTile extends StatelessWidget {
  const RecentMatchTile({
    super.key,
    required this.match,
    required this.currentUid,
    required this.opponentNames,
  });

  final MatchModel match;
  final String currentUid;
  final Map<String, String> opponentNames;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isConfirmed = match.state == MatchStates.confirmed;

    final opponents = opponentUids(match, currentUid);
    final names = opponents
        .map((uid) => opponentNames[uid])
        .whereType<String>()
        .toList();
    final title = names.isEmpty
        ? localizedSportName(l10n, match.sportId)
        : names.join(', ');
    final avatarSeed = opponents.isEmpty ? match.matchId : opponents.first;
    final displayInitials = initialsFromName(title);
    final score = matchScoreLabel(match, currentUid);
    final subtitle = score.isNotEmpty
        ? score
        : MaterialLocalizations.of(context).formatShortDate(match.startedAt);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: IdentityAvatar(seed: avatarSeed, initials: displayInitials),
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _trailing(l10n, theme, isConfirmed),
    );
  }

  Widget? _trailing(AppLocalizations l10n, ThemeData theme, bool isConfirmed) {
    if (!isConfirmed) {
      return Text(_stateLabel(l10n), style: theme.textTheme.labelMedium);
    }
    final delta = match.eloDeltas?[currentUid];
    if (delta == null) return null;
    return Text(
      delta >= 0 ? '+$delta' : '$delta',
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: delta >= 0 ? theme.colorScheme.primary : theme.colorScheme.error,
      ),
    );
  }

  String _stateLabel(AppLocalizations l10n) {
    switch (match.state) {
      case MatchStates.disputed:
        return l10n.matchStateDisputed;
      case MatchStates.unconfirmed:
        return l10n.matchStateUnconfirmed;
      case MatchStates.abandoned:
        return l10n.matchStateAbandoned;
      default:
        return '';
    }
  }
}
