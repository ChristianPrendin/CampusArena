// Foosball: a single game, decided on goal count. See
// `brain/firestore_schema.md` for the locked `result` shape.

import 'package:flutter/material.dart';

import '../../models/match_model.dart';
import 'scoring_strategy.dart';
import 'scoring_widgets.dart';

class FoosballScoringStrategy extends ScoringStrategy {
  const FoosballScoringStrategy();

  @override
  ScoringValidation validateResult(covariant FoosballResult result) {
    if (result.goals < 0 || result.opponentGoals < 0) {
      return const ScoringValidation.invalid(ScoringError.negativeScore);
    }
    if (result.goals == result.opponentGoals) {
      return const ScoringValidation.invalid(ScoringError.tiedGame);
    }
    // Canonical storage is winner-first: `goals` must be the higher count and
    // `winnerIds` must name that side.
    if (result.goals < result.opponentGoals || result.winnerIds.isEmpty) {
      return const ScoringValidation.invalid(ScoringError.winnerMismatch);
    }
    return const ScoringValidation.valid();
  }

  /// Builds a canonical (winner-first) [FoosballResult] from goals entered in
  /// the [yourUids]/[opponentUids] frame, or `null` on a tie (no winner).
  /// Non-negativity is left to [validateResult].
  FoosballResult? composeResult({
    required int yourGoals,
    required int opponentGoals,
    required List<String> yourUids,
    required List<String> opponentUids,
  }) {
    if (yourGoals == opponentGoals) return null;
    final youWon = yourGoals > opponentGoals;
    return FoosballResult(
      winnerIds: youWon ? yourUids : opponentUids,
      goals: youWon ? yourGoals : opponentGoals,
      opponentGoals: youWon ? opponentGoals : yourGoals,
    );
  }

  @override
  Widget getResultWidget({
    required ResultEntrySide youSide,
    required ResultEntrySide opponentSide,
    required ResultEntryLabels labels,
    required ValueChanged<MatchResult?> onResultChanged,
  }) {
    return FoosballResultEntry(
      strategy: this,
      youSide: youSide,
      opponentSide: opponentSide,
      labels: labels,
      onResultChanged: onResultChanged,
    );
  }
}

/// A single goal-count row between the two sides. Emits a validated canonical
/// [FoosballResult] (or `null`) on every edit.
class FoosballResultEntry extends StatefulWidget {
  const FoosballResultEntry({
    super.key,
    required this.strategy,
    required this.youSide,
    required this.opponentSide,
    required this.labels,
    required this.onResultChanged,
  });

  final FoosballScoringStrategy strategy;
  final ResultEntrySide youSide;
  final ResultEntrySide opponentSide;
  final ResultEntryLabels labels;
  final ValueChanged<MatchResult?> onResultChanged;

  @override
  State<FoosballResultEntry> createState() => _FoosballResultEntryState();
}

class _FoosballResultEntryState extends State<FoosballResultEntry> {
  int _yourGoals = 0;
  int _opponentGoals = 0;

  void _emit() {
    final result = widget.strategy.composeResult(
      yourGoals: _yourGoals,
      opponentGoals: _opponentGoals,
      yourUids: widget.youSide.uids,
      opponentUids: widget.opponentSide.uids,
    );
    final isValid =
        result != null && widget.strategy.validateResult(result).isValid;
    widget.onResultChanged(isValid ? result : null);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ResultEntryHeader(
          youSide: widget.youSide,
          opponentSide: widget.opponentSide,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ScoreStepper(
                value: _yourGoals,
                onChanged: (v) {
                  setState(() => _yourGoals = v);
                  _emit();
                },
              ),
              Text(
                widget.labels.goalsLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              ScoreStepper(
                value: _opponentGoals,
                onChanged: (v) {
                  setState(() => _opponentGoals = v);
                  _emit();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
