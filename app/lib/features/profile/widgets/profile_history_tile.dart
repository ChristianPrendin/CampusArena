import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/match_display.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/match_model.dart';

/// One row of the profile's full match history: opponent avatar and name(s),
/// score · date · facility underneath, and the signed ELO delta on confirmed
/// matches (green gain / red loss) or a status label on
/// disputed/unconfirmed/abandoned ones. The RecentMatchTile pattern, extended
/// with the date and facility the history log requires.
class ProfileHistoryTile extends StatelessWidget {
  const ProfileHistoryTile({
    super.key,
    required this.match,
    required this.currentUid,
    required this.opponentNames,
    required this.facilityNames,
    this.deltaKey,
  });

  final MatchModel match;
  final String currentUid;
  final Map<String, String> opponentNames;
  final Map<String, String> facilityNames;

  /// Which `eloDeltas` key to read for the trailing delta — defaults to
  /// [currentUid]. The team profile passes the pairId, since a doubles match
  /// keys its ELO maps by pair, not by member uid.
  final String? deltaKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final opponents = opponentUids(match, currentUid);
    final names = opponents
        .map((uid) => opponentNames[uid])
        .whereType<String>()
        .toList();
    final title = names.isEmpty
        ? localizedSportName(l10n, match.sportId)
        : names.join(', ');
    final avatarSeed = opponents.isEmpty ? match.matchId : opponents.first;

    final score = matchScoreLabel(match, currentUid);
    final facilityName = facilityNames[match.facilityId];
    final subtitle = [
      if (score.isNotEmpty) score,
      MaterialLocalizations.of(context).formatShortDate(match.startedAt),
      ?facilityName,
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: IdentityAvatar(
        seed: avatarSeed,
        initials: initialsFromName(title),
      ),
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _trailing(l10n, theme),
    );
  }

  Widget? _trailing(AppLocalizations l10n, ThemeData theme) {
    if (match.state != MatchStates.confirmed) {
      return Text(_stateLabel(l10n), style: theme.textTheme.labelMedium);
    }
    final delta = match.eloDeltas?[deltaKey ?? currentUid];
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
