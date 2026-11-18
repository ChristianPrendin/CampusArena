// Pure Dart achievement engine — no Flutter, no Firestore. Mirrors
// `core/elo/elo_calculator.dart`: side-effect-free and fully unit-tested.
//
// Evaluation is client-side and cosmetic (Spark-Tier Trust Boundary,
// `brain/firestore_schema.md`). Thresholds are read from each
// [AchievementDefModel], never hardcoded here — so the seed's 10→15 workaholic
// change is pure data. The caller (the confirmResult transaction) owns
// persistence into `users/{uid}.badges`.

import '../../models/achievement_def_model.dart';

/// Canonical `achievementDefs/{id}` document ids.
class AchievementIds {
  AchievementIds._();

  static const String firstVictory = 'first_victory';
  static const String streak5 = 'streak_5';
  static const String giantSlayer = 'giant_slayer';
  static const String explorer = 'explorer';
  static const String tournamentChampion = 'tournament_champion';
  static const String workaholic = 'workaholic';
}

/// `achievementDefs/{id}.condition` rule identifiers the evaluator branches on.
class AchievementConditions {
  AchievementConditions._();

  static const String firstVictory = 'first_victory';
  static const String winStreak = 'win_streak';
  static const String giantSlayer = 'giant_slayer';
  static const String explorer = 'explorer';
  static const String tournamentChampion = 'tournament_champion';
  static const String monthlyCount = 'monthly_count';
}

/// One prior confirmed match, reduced to the fields the conditions need.
class ConfirmedMatchRecord {
  const ConfirmedMatchRecord({
    required this.won,
    required this.sportId,
    required this.facilityId,
    required this.playedAt,
  });

  final bool won;
  final String sportId;
  final String facilityId;
  final DateTime playedAt;
}

/// Everything the evaluator needs for one player at one match confirmation.
///
/// [priorConfirmedMatches] is that player's confirmed history *before* this
/// match (order-independent — the evaluator sorts what it needs). The match
/// being confirmed is described by [wonThisMatch]/[sportId]/[facilityId]/
/// [playedAt] and folded in as the latest entry. [ownEloBefore]/
/// [opponentEloBefore] are the pre-match snapshots straight off the match's
/// `eloBefore` map (giant slayer). [allFacilityIds] is the full campus set
/// (explorer target); [currentBadges] enforces write-once.
class AchievementContext {
  const AchievementContext({
    required this.playerUid,
    required this.wonThisMatch,
    required this.sportId,
    required this.facilityId,
    required this.playedAt,
    required this.ownEloBefore,
    required this.opponentEloBefore,
    required this.priorConfirmedMatches,
    required this.allFacilityIds,
    required this.currentBadges,
    required this.defs,
  });

  final String playerUid;
  final bool wonThisMatch;
  final String sportId;
  final String facilityId;
  final DateTime playedAt;
  final int ownEloBefore;
  final int opponentEloBefore;
  final List<ConfirmedMatchRecord> priorConfirmedMatches;
  final Set<String> allFacilityIds;
  final Set<String> currentBadges;
  final List<AchievementDefModel> defs;
}

/// Stateless achievement arithmetic. [evaluate] returns the set of newly-earned
/// achievement ids per the write-once rule: an id qualifies only when its
/// condition holds *now* AND it is absent from [AchievementContext.currentBadges].
/// An already-owned badge is never re-emitted, so a `merge` write can never
/// overwrite an existing unlock timestamp.
class AchievementEvaluator {
  const AchievementEvaluator();

  Set<String> evaluate(AchievementContext ctx) {
    final earned = <String>{};
    for (final def in ctx.defs) {
      if (ctx.currentBadges.contains(def.achievementId)) continue;
      if (_qualifies(def, ctx)) earned.add(def.achievementId);
    }
    return earned;
  }

  bool _qualifies(AchievementDefModel def, AchievementContext ctx) {
    switch (def.condition) {
      case AchievementConditions.firstVictory:
        // This confirmed win is the player's first ranked win ever.
        return ctx.wonThisMatch && !ctx.priorConfirmedMatches.any((m) => m.won);

      case AchievementConditions.winStreak:
        return ctx.wonThisMatch && _currentStreak(ctx) >= (def.threshold ?? 0);

      case AchievementConditions.giantSlayer:
        // Beat an opponent rated at least `threshold` above your pre-match ELO.
        return ctx.wonThisMatch &&
            (ctx.opponentEloBefore - ctx.ownEloBefore) >= (def.threshold ?? 0);

      case AchievementConditions.monthlyCount:
        return _monthlyCount(ctx) >= (def.threshold ?? 0);

      case AchievementConditions.explorer:
        // Played at least one confirmed match at every campus facility.
        final played = <String>{
          ctx.facilityId,
          for (final m in ctx.priorConfirmedMatches) m.facilityId,
        };
        return ctx.allFacilityIds.isNotEmpty &&
            played.containsAll(ctx.allFacilityIds);

      case AchievementConditions.tournamentChampion:
        // Evaluated in the tournament-completion path, never at match confirm.
        return false;

      default:
        return false;
    }
  }

  /// Consecutive confirmed wins for this player+sport ending with this match.
  /// The match being confirmed is the latest win; walk back through prior
  /// same-sport confirmed matches (most recent first) and count until a loss
  /// breaks the run.
  int _currentStreak(AchievementContext ctx) {
    final sameSport =
        ctx.priorConfirmedMatches
            .where((m) => m.sportId == ctx.sportId)
            .toList()
          ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    var streak = 1; // this match (a win — guarded by the caller).
    for (final m in sameSport) {
      if (!m.won) break;
      streak++;
    }
    return streak;
  }

  /// Confirmed matches in the same calendar month as this match, including it.
  int _monthlyCount(AchievementContext ctx) {
    var count = 1; // this match.
    for (final m in ctx.priorConfirmedMatches) {
      if (m.playedAt.year == ctx.playedAt.year &&
          m.playedAt.month == ctx.playedAt.month) {
        count++;
      }
    }
    return count;
  }
}
