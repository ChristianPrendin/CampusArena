// Ping Pong: set-based, best-of-N. See `brain/firestore_schema.md` for the
// locked `result` shape and `brain/project_description.md` §2.3.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/match_model.dart';
import 'scoring_strategy.dart';
import 'scoring_widgets.dart';

class PingPongScoringStrategy extends ScoringStrategy {
  const PingPongScoringStrategy();

  /// Minimum points the set winner must reach — covers both 11- and 21-point
  /// games (a 21-point game's winner is trivially ≥11).
  static const int _minSetPoints = 11;

  /// A set must be won by at least this margin (deuce continues past 10-10).
  static const int _minSetMargin = 2;

  @override
  ScoringValidation validateResult(covariant PingPongResult result) {
    final winnerSets = result.sets;
    final loserSets = result.opponentSets;

    if (winnerSets.isEmpty || winnerSets.length != loserSets.length) {
      return const ScoringValidation.invalid(ScoringError.malformedResult);
    }

    var winnerSetWins = 0;
    var loserSetWins = 0;
    for (var i = 0; i < winnerSets.length; i++) {
      final a = winnerSets[i];
      final b = loserSets[i];
      if (a == b) {
        return const ScoringValidation.invalid(ScoringError.tiedSet);
      }
      final high = math.max(a, b);
      final low = math.min(a, b);
      if (high < _minSetPoints || high - low < _minSetMargin) {
        return const ScoringValidation.invalid(ScoringError.setNotDecisive);
      }
      if (a > b) {
        winnerSetWins++;
      } else {
        loserSetWins++;
      }
    }

    // Canonical storage is winner-first: the `sets` side must hold strictly
    // more sets and be named in `winnerIds`.
    if (winnerSetWins <= loserSetWins || result.winnerIds.isEmpty) {
      return const ScoringValidation.invalid(ScoringError.winnerMismatch);
    }
    return const ScoringValidation.valid();
  }

  /// Builds a canonical (winner-first) [PingPongResult] from per-set points
  /// entered in the [yourUids]/[opponentUids] frame, or `null` when the set
  /// tally is level (no decisive winner yet). Score legality is left to
  /// [validateResult]; this only fixes orientation and `winnerIds`.
  PingPongResult? composeResult({
    required List<int> yourPoints,
    required List<int> opponentPoints,
    required List<String> yourUids,
    required List<String> opponentUids,
  }) {
    assert(yourPoints.length == opponentPoints.length);
    var yourSetWins = 0;
    var opponentSetWins = 0;
    for (var i = 0; i < yourPoints.length; i++) {
      if (yourPoints[i] > opponentPoints[i]) {
        yourSetWins++;
      } else if (opponentPoints[i] > yourPoints[i]) {
        opponentSetWins++;
      }
    }
    if (yourSetWins == opponentSetWins) return null;

    final youWon = yourSetWins > opponentSetWins;
    return PingPongResult(
      winnerIds: youWon ? yourUids : opponentUids,
      sets: youWon ? yourPoints : opponentPoints,
      opponentSets: youWon ? opponentPoints : yourPoints,
    );
  }

  @override
  Widget getResultWidget({
    required ResultEntrySide youSide,
    required ResultEntrySide opponentSide,
    required ResultEntryLabels labels,
    required ValueChanged<MatchResult?> onResultChanged,
  }) {
    return PingPongResultEntry(
      strategy: this,
      youSide: youSide,
      opponentSide: opponentSide,
      labels: labels,
      onResultChanged: onResultChanged,
    );
  }
}

/// Per-set stepper rows + "Add set", per `docs/design/screenshots/result.png`.
/// Emits a validated canonical [PingPongResult] (or `null`) on every edit.
class PingPongResultEntry extends StatefulWidget {
  const PingPongResultEntry({
    super.key,
    required this.strategy,
    required this.youSide,
    required this.opponentSide,
    required this.labels,
    required this.onResultChanged,
  });

  final PingPongScoringStrategy strategy;
  final ResultEntrySide youSide;
  final ResultEntrySide opponentSide;
  final ResultEntryLabels labels;
  final ValueChanged<MatchResult?> onResultChanged;

  @override
  State<PingPongResultEntry> createState() => _PingPongResultEntryState();
}

class _PingPongResultEntryState extends State<PingPongResultEntry> {
  // One [you, opponent] pair per set; starts at a single 0–0 set.
  final List<List<int>> _sets = [
    [0, 0],
  ];

  void _emit() {
    final result = widget.strategy.composeResult(
      yourPoints: [for (final s in _sets) s[0]],
      opponentPoints: [for (final s in _sets) s[1]],
      yourUids: widget.youSide.uids,
      opponentUids: widget.opponentSide.uids,
    );
    final isValid =
        result != null && widget.strategy.validateResult(result).isValid;
    widget.onResultChanged(isValid ? result : null);
  }

  void _setPoint(int index, int side, int value) {
    setState(() => _sets[index][side] = value);
    _emit();
  }

  void _addSet() {
    setState(() => _sets.add([0, 0]));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ResultEntryHeader(
          youSide: widget.youSide,
          opponentSide: widget.opponentSide,
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < _sets.length; i++) ...[
          _SetRow(
            label: widget.labels.setLabel(i + 1),
            youValue: _sets[i][0],
            opponentValue: _sets[i][1],
            onYouChanged: (v) => _setPoint(i, 0, v),
            onOpponentChanged: (v) => _setPoint(i, 1, v),
          ),
          const SizedBox(height: 12),
        ],
        TextButton.icon(
          onPressed: _addSet,
          icon: const Icon(Icons.add_circle_outline),
          label: Text(widget.labels.addSetLabel),
        ),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.label,
    required this.youValue,
    required this.opponentValue,
    required this.onYouChanged,
    required this.onOpponentChanged,
  });

  final String label;
  final int youValue;
  final int opponentValue;
  final ValueChanged<int> onYouChanged;
  final ValueChanged<int> onOpponentChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ScoreStepper(value: youValue, onChanged: onYouChanged),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          ScoreStepper(value: opponentValue, onChanged: onOpponentChanged),
        ],
      ),
    );
  }
}
