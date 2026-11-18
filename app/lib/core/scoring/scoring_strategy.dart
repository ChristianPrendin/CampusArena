// The multi-sport scoring seam (`brain/project_description.md` §2.3).
//
// A `ScoringStrategy` owns everything sport-specific about a match result:
// how to validate a score, how to render its entry widget, and how to distil
// the score into a rating-relevant outcome. Adding a sport (Padel is a Phase 6
// stretch) MUST require a new implementation only — never a change to this
// interface. The result-entry screen and the confirm transaction consume a
// strategy purely through the three methods below and never branch on sportId.

import 'package:flutter/material.dart';

import '../../models/match_model.dart';
import '../elo/elo_calculator.dart';

/// Why a result failed validation. Kept as an enum (not a localized string) so
/// validation stays string-free and testable; stage 2 maps each case to an ARB
/// message.
enum ScoringError {
  /// No sets entered, or the two per-set arrays disagree in length.
  malformedResult,

  /// Ping Pong: a set ended level.
  tiedSet,

  /// Ping Pong: a set not decided by ≥2 points with the winner's score ≥11.
  setNotDecisive,

  /// Foosball: a negative goal count.
  negativeScore,

  /// Foosball: the game ended level.
  tiedGame,

  /// The winner-first `score` arrays disagree with `winnerIds` — the side
  /// stored as the winner did not actually win more sets/goals, or
  /// `winnerIds` is empty.
  winnerMismatch,
}

/// Outcome of validating a composed [MatchResult].
class ScoringValidation {
  const ScoringValidation.valid() : isValid = true, error = null;
  const ScoringValidation.invalid(ScoringError this.error) : isValid = false;

  final bool isValid;
  final ScoringError? error;
}

/// The rating-relevant outcome of a validated result, seen from one side.
///
/// [outcome] plugs straight into [EloCalculator.computeUpdate]'s `outcomeA`;
/// [winnerIds] is the winning side's UIDs, ready for the match document. This
/// is the exact shape the confirm transaction feeds the ELO engine.
class MatchOutcome {
  const MatchOutcome({required this.outcome, required this.winnerIds});

  final EloOutcome outcome;
  final List<String> winnerIds;
}

/// Identity of one side of the match, supplied by the (sport-agnostic) entry
/// screen so the entry widget can render its avatar/label and compose
/// `winnerIds` when that side wins.
class ResultEntrySide {
  const ResultEntrySide({
    required this.label,
    required this.displayName,
    required this.uids,
    this.memberNames = const [],
  });

  /// "You" / "Opponent" — shown under the avatar. Supplied by the entry screen
  /// from ARB (`resultSideYou` / `resultSideOpponent`), keeping this widget
  /// decoupled from `AppLocalizations`.
  final String label;

  /// Player (singles) or team (doubles) name — seeds the avatar hue + initials.
  final String displayName;

  /// This side's member UIDs; become `winnerIds` when this side wins.
  final List<String> uids;

  /// Per-member display names, index-aligned with [uids]. Empty for singles;
  /// for doubles it drives the two-avatar team header. A missing lookup leaves
  /// a slot blank (initials fall back), never erroring the header.
  final List<String> memberNames;
}

/// Localized captions the entry widgets need, supplied by the entry screen from
/// ARB (`resultSetLabel` / `resultAddSet` / `resultGoalsLabel`). A plain string
/// bag keeps the widgets decoupled from `AppLocalizations`; it is deliberately
/// NOT part of the stable [ScoringStrategy] seam.
class ResultEntryLabels {
  const ResultEntryLabels({
    required this.setLabel,
    required this.addSetLabel,
    required this.goalsLabel,
  });

  /// Ping Pong per-row caption, e.g. `(1) => "Set 1"`.
  final String Function(int setNumber) setLabel;

  /// Ping Pong "Add set" button.
  final String addSetLabel;

  /// Foosball centre caption, e.g. "Goals".
  final String goalsLabel;
}

/// The §2.3 extensibility seam. Exactly three members — a new sport implements
/// [validateResult] and [getResultWidget] and inherits [computeMatchOutcome].
abstract class ScoringStrategy {
  const ScoringStrategy();

  /// Validates a *canonical* (winner-first) result for this sport. Pure and
  /// synchronous so it can gate the Submit button live as the user types.
  ScoringValidation validateResult(covariant MatchResult result);

  /// The sport's score-entry widget.
  ///
  /// Contract (so the entry screen stays fully sport-agnostic):
  /// - The widget owns its transient stepper state internally.
  /// - It calls [onResultChanged] whenever the input changes, passing a
  ///   validated canonical [MatchResult] when the current input is a legal,
  ///   decisive result, or `null` while it is incomplete/invalid.
  /// - The screen therefore binds Submit-enabled directly to "last emitted
  ///   value is non-null", and on submit passes that value to
  ///   [computeMatchOutcome]. It never inspects the sport-specific score.
  Widget getResultWidget({
    required ResultEntrySide youSide,
    required ResultEntrySide opponentSide,
    required ResultEntryLabels labels,
    required ValueChanged<MatchResult?> onResultChanged,
  });

  /// Distils a validated result into an ELO-ready outcome for the side that
  /// [perspectiveUid] belongs to. Winner-first canonical storage makes this
  /// uniform across today's win/loss sports, so it is provided here; a future
  /// sport with partial/tie semantics may override it.
  MatchOutcome computeMatchOutcome(
    MatchResult result, {
    required String perspectiveUid,
  }) {
    final winnerIds = result.winnerIds;
    final EloOutcome outcome;
    if (winnerIds.isEmpty) {
      outcome = EloOutcome.tie;
    } else if (winnerIds.contains(perspectiveUid)) {
      outcome = EloOutcome.win;
    } else {
      outcome = EloOutcome.loss;
    }
    return MatchOutcome(outcome: outcome, winnerIds: winnerIds);
  }
}
