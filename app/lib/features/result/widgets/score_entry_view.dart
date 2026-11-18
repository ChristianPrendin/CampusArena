import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/scoring/scoring_strategy.dart';
import '../../../core/scoring/scoring_strategy_factory.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/match_model.dart';
import '../cubit/result_cubit.dart';
import '../cubit/result_state.dart';

/// Score-entry screen (`docs/design/screenshots/result.png`). Stays fully
/// sport-agnostic: it resolves the [ScoringStrategy] from the sportId via the
/// factory and embeds `strategy.getResultWidget(...)`, receiving the composed
/// result through the widget's callback. Submit re-checks
/// `strategy.validateResult` before writing.
class ScoreEntryView extends StatefulWidget {
  const ScoreEntryView({super.key, required this.state});

  final ResultState state;

  @override
  State<ScoreEntryView> createState() => _ScoreEntryViewState();
}

class _ScoreEntryViewState extends State<ScoreEntryView> {
  late final ScoringStrategy _strategy;
  MatchResult? _result;
  bool _unsupported = false;

  @override
  void initState() {
    super.initState();
    final sportId = widget.state.match?.sportId ?? '';
    try {
      _strategy = const ScoringStrategyFactory().forSport(sportId);
    } on UnsupportedSportException {
      _unsupported = true;
    }
  }

  String get _uid => context.read<ResultCubit>().uid;

  (ResultEntrySide, ResultEntrySide) _sides(
    MatchModel match,
    AppLocalizations l10n,
  ) {
    final players = widget.state.players;
    String name(String uid) => players[uid] ?? '';

    final youLabel = l10n.resultSideYou;
    final oppLabel = l10n.resultSideOpponent;

    if (match.mode == 'doubles') {
      final (mine, theirs) = _doublesTeams(match);
      return (
        ResultEntrySide(
          label: youLabel,
          displayName: name(_uid),
          uids: mine,
          memberNames: [for (final u in mine) name(u)],
        ),
        ResultEntrySide(
          label: oppLabel,
          displayName: theirs.isEmpty ? '' : name(theirs.first),
          uids: theirs,
          memberNames: [for (final u in theirs) name(u)],
        ),
      );
    }

    final opponentUid = match.playerUids.firstWhere(
      (u) => u != _uid,
      orElse: () => '',
    );
    return (
      ResultEntrySide(label: youLabel, displayName: name(_uid), uids: [_uid]),
      ResultEntrySide(
        label: oppLabel,
        displayName: name(opponentUid),
        uids: [opponentUid],
      ),
    );
  }

  /// Doubles team membership from the stored pair ids (Firebase UIDs carry no
  /// underscore, so the pairId split is safe): the current user's side first,
  /// the opponents second. Falls back to "me vs everyone else" if the pair ids
  /// are somehow absent.
  (List<String>, List<String>) _doublesTeams(MatchModel match) {
    final t1 = match.team1PairId?.split('_') ?? const <String>[];
    final t2 = match.team2PairId?.split('_') ?? const <String>[];
    if (t1.contains(_uid)) return (t1, t2);
    if (t2.contains(_uid)) return (t2, t1);
    return ([_uid], match.playerUids.where((u) => u != _uid).toList());
  }

  void _submit() {
    final result = _result;
    if (result == null || !_strategy.validateResult(result).isValid) return;
    context.read<ResultCubit>().submit(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final match = widget.state.match;
    final submitting = widget.state.phase == ResultPhase.submitting;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.resultEnterScoreTitle)),
      body: SafeArea(
        child: (_unsupported || match == null)
            ? Center(child: Text(l10n.resultErrorTitle))
            : _buildBody(context, match, l10n, submitting),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MatchModel match,
    AppLocalizations l10n,
    bool submitting,
  ) {
    final (youSide, opponentSide) = _sides(match, l10n);
    final labels = ResultEntryLabels(
      setLabel: l10n.resultSetLabel,
      addSetLabel: l10n.resultAddSet,
      goalsLabel: l10n.resultGoalsLabel,
    );
    final canSubmit = _result != null && !submitting;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: _strategy.getResultWidget(
                  youSide: youSide,
                  opponentSide: opponentSide,
                  labels: labels,
                  onResultChanged: (result) => setState(() => _result = result),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_result == null && !submitting)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.resultInvalidHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: canSubmit ? _submit : null,
                    child: submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.resultSubmit),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
