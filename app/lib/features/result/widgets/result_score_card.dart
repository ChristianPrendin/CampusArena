import 'package:flutter/material.dart';

import '../../../core/widgets/identity_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/match_model.dart';

/// Read-only render of a submitted [MatchResult], oriented to the current user's
/// perspective (per `docs/design/screenshots/opponentconfirmation.png`): two
/// avatars flanking the set/goal totals, then the per-set breakdown for ping
/// pong. Switches on the concrete result type — the score-*entry* seam stays in
/// `ScoringStrategy`; this is display only.
class ResultScoreCard extends StatelessWidget {
  const ResultScoreCard({
    super.key,
    required this.result,
    required this.youWon,
    required this.youUids,
    required this.opponentUids,
    required this.youNames,
    required this.opponentNames,
    required this.youLabel,
    required this.opponentLabel,
    this.footer,
  });

  final MatchResult result;

  /// Whether the current user's side won — orients the winner-first score arrays.
  final bool youWon;

  /// Member uids/names per side (one each for singles, two for doubles),
  /// index-aligned. Drive the avatars and the team name line.
  final List<String> youUids;
  final List<String> opponentUids;
  final List<String> youNames;
  final List<String> opponentNames;

  /// Localized labels under each side ("You" / "Opponent(s)").
  final String youLabel;
  final String opponentLabel;

  /// Optional footer (e.g. the submitter's "waiting for opponent" line).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = this.result;

    final String caption;
    final int myTotal;
    final int oppTotal;
    List<Widget> breakdown = const [];

    if (result is PingPongResult) {
      final mySets = youWon ? result.sets : result.opponentSets;
      final oppSets = youWon ? result.opponentSets : result.sets;
      caption = l10n.resultSetsLabel;
      myTotal = _setsWon(mySets, oppSets);
      oppTotal = _setsWon(oppSets, mySets);
      breakdown = [
        for (var i = 0; i < mySets.length; i++)
          _SetRow(
            label: l10n.resultSetLabel(i + 1),
            mine: mySets[i],
            theirs: oppSets[i],
          ),
      ];
    } else if (result is FoosballResult) {
      caption = l10n.resultGoalsLabel;
      myTotal = youWon ? result.goals : result.opponentGoals;
      oppTotal = youWon ? result.opponentGoals : result.goals;
    } else {
      caption = '';
      myTotal = 0;
      oppTotal = 0;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              youUids: youUids,
              opponentUids: opponentUids,
              youNames: youNames,
              opponentNames: opponentNames,
              youLabel: youLabel,
              opponentLabel: opponentLabel,
              caption: caption,
              myTotal: myTotal,
              oppTotal: oppTotal,
            ),
            if (breakdown.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...breakdown,
            ],
            if (footer != null) ...[const SizedBox(height: 16), footer!],
          ],
        ),
      ),
    );
  }

  static int _setsWon(List<int> a, List<int> b) {
    var count = 0;
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] > b[i]) count++;
    }
    return count;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.youUids,
    required this.opponentUids,
    required this.youNames,
    required this.opponentNames,
    required this.youLabel,
    required this.opponentLabel,
    required this.caption,
    required this.myTotal,
    required this.oppTotal,
  });

  final List<String> youUids;
  final List<String> opponentUids;
  final List<String> youNames;
  final List<String> opponentNames;
  final String youLabel;
  final String opponentLabel;
  final String caption;
  final int myTotal;
  final int oppTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _AvatarColumn(
          uids: youUids,
          names: youNames,
          label: youLabel,
          highlight: true,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '$myTotal – $oppTotal',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                caption,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _AvatarColumn(
          uids: opponentUids,
          names: opponentNames,
          label: opponentLabel,
          highlight: false,
        ),
      ],
    );
  }
}

/// One side of the score-card header: a single avatar for singles, two stacked
/// avatars for a doubles pair, then the side label and (for doubles) a small
/// member-names line.
class _AvatarColumn extends StatelessWidget {
  const _AvatarColumn({
    required this.uids,
    required this.names,
    required this.label,
    required this.highlight,
  });

  final List<String> uids;
  final List<String> names;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTeam = uids.length > 1;
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          if (isTeam)
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < uids.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  IdentityAvatar(
                    seed: uids[i],
                    initials: initialsFromName(
                      i < names.length ? names[i] : '',
                    ),
                    radius: 19,
                    fontSize: 12,
                  ),
                ],
              ],
            )
          else
            IdentityAvatar(
              seed: uids.isEmpty ? label : uids.first,
              initials: initialsFromName(names.isEmpty ? '' : names.first),
              radius: 26,
              fontSize: 15,
            ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
          if (isTeam)
            Text(
              names.where((n) => n.isNotEmpty).join(' & '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.label,
    required this.mine,
    required this.theirs,
  });

  final String label;
  final int mine;
  final int theirs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$mine',
              textAlign: TextAlign.center,
              style: numberStyle,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              '$theirs',
              textAlign: TextAlign.center,
              style: numberStyle,
            ),
          ),
        ],
      ),
    );
  }
}
