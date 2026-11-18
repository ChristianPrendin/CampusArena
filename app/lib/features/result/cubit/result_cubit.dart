import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants.dart' as fs;
import '../../../core/scoring/scoring_strategy_factory.dart';
import '../../../models/match_model.dart';
import '../../../repositories/achievement_repository.dart';
import '../../../repositories/match_repository.dart';
import '../../../repositories/rating_repository.dart';
import '../../../repositories/user_repository.dart';
import 'result_state.dart';

/// Drives the result flow for one match: streams `matches/{id}`, derives the
/// phase from the doc's `state`, and owns the submit / confirm / dispute writes.
///
/// Reader-plus-writer: it reflects the streamed match state, and its three
/// action methods invoke the [MatchRepository] transactions (which are the
/// atomic ELO + facility writers). It touches Firestore only through
/// repositories — never `cloud_firestore` directly.
class ResultCubit extends Cubit<ResultState> {
  ResultCubit({
    required this.uid,
    required this.matchId,
    MatchRepository? matchRepository,
    RatingRepository? ratingRepository,
    UserRepository? userRepository,
    AchievementRepository? achievementRepository,
    DateTime Function()? now,
  }) : _matchRepo = matchRepository ?? MatchRepository(),
       _ratingRepo = ratingRepository ?? RatingRepository(),
       _userRepo = userRepository ?? UserRepository(),
       _achievementRepo = achievementRepository ?? AchievementRepository(),
       _now = now ?? DateTime.now,
       super(const ResultState());

  final String uid;
  final String matchId;
  final MatchRepository _matchRepo;
  final RatingRepository _ratingRepo;
  final UserRepository _userRepo;
  final AchievementRepository _achievementRepo;
  final DateTime Function() _now;

  StreamSubscription<MatchModel?>? _matchSub;

  /// Begins streaming the match. Invoked by the page after provider creation so
  /// the constructor stays side-effect-free after its synchronous initial state.
  void load() {
    _matchSub?.cancel();
    _matchSub = _matchRepo.watchMatch(matchId).listen(_onMatch);
  }

  void _onMatch(MatchModel? match) {
    if (isClosed) return;
    if (match == null) {
      emit(
        state.copyWith(
          phase: ResultPhase.error,
          errorKind: ResultErrorKind.load,
        ),
      );
      return;
    }

    // Lazily resolve a stale match (schema Timeout note); the stream then
    // re-emits the transitioned state. Idempotent + state-guarded, so repeated
    // fires are harmless no-ops.
    _maybeResolveTimeout(match);

    // Hold an error until the user retries, but keep tracking the latest doc.
    // Exception: a lost submit race self-heals — once the opponent's
    // submission arrives, fall through and derive normally (→ review).
    final lostSubmitRace =
        state.errorKind == ResultErrorKind.submit &&
        match.state != fs.MatchStates.occupied;
    if (state.phase == ResultPhase.error && !lostSubmitRace) {
      emit(state.copyWith(match: match));
      _loadPlayersIfNeeded(match);
      return;
    }

    final natural = _derivePhase(match);

    // Keep a transient action phase until the match state actually advances —
    // otherwise a same-state re-emission (e.g. player enrichment) would flash
    // the pre-action view.
    final keepTransient =
        (state.phase == ResultPhase.submitting &&
            match.state == fs.MatchStates.occupied) ||
        ((state.phase == ResultPhase.confirming ||
                state.phase == ResultPhase.disputing) &&
            match.state == fs.MatchStates.awaitingConfirmation);

    final phase = keepTransient ? state.phase : natural;

    emit(
      state.copyWith(
        phase: phase,
        match: match,
        closedKind: _closedKind(match),
        summary: phase == ResultPhase.summary ? _buildSummary(match) : null,
      ),
    );

    _loadPlayersIfNeeded(match);
    if (phase == ResultPhase.summary) {
      _loadRank(match);
      _resolveNewBadgesFromDoc(match);
    }
  }

  ResultPhase _derivePhase(MatchModel match) {
    switch (match.state) {
      case fs.MatchStates.occupied:
        return ResultPhase.scoreEntry;
      case fs.MatchStates.awaitingConfirmation:
        return match.submittedByUid == uid
            ? ResultPhase.awaitingOpponent
            : ResultPhase.review;
      case fs.MatchStates.confirmed:
        return ResultPhase.summary;
      case fs.MatchStates.disputed:
      case fs.MatchStates.unconfirmed:
      case fs.MatchStates.abandoned:
        return ResultPhase.closed;
      default:
        return ResultPhase.loading;
    }
  }

  ResultClosedKind? _closedKind(MatchModel match) {
    switch (match.state) {
      case fs.MatchStates.disputed:
        return ResultClosedKind.disputed;
      case fs.MatchStates.unconfirmed:
        return ResultClosedKind.unconfirmed;
      case fs.MatchStates.abandoned:
        return ResultClosedKind.abandoned;
      default:
        return null;
    }
  }

  void _maybeResolveTimeout(MatchModel match) {
    final elapsed = _now().difference(match.startedAt);
    final stale =
        (match.state == fs.MatchStates.occupied &&
            elapsed > MatchRepository.occupiedTimeout) ||
        (match.state == fs.MatchStates.awaitingConfirmation &&
            elapsed > MatchRepository.awaitingConfirmationTimeout);
    if (stale) {
      unawaited(
        _matchRepo.resolveTimeout(match, now: _now()).catchError((_) {}),
      );
    }
  }

  // --- actions -------------------------------------------------------------

  /// Submits [result] (score entry). Re-validates through the sport's strategy
  /// as the authoritative gate — an invalid result never writes (the entry
  /// widget already keeps the button disabled, but this guards a raced/forced
  /// call). A failed write surfaces as an error with retry.
  Future<void> submit(MatchResult result) async {
    if (state.phase != ResultPhase.scoreEntry) return;
    final sportId = state.match?.sportId ?? '';
    final ScoringStrategyFactory factory = const ScoringStrategyFactory();
    try {
      if (!factory.forSport(sportId).validateResult(result).isValid) return;
    } on UnsupportedSportException {
      return;
    }
    emit(state.copyWith(phase: ResultPhase.submitting));
    try {
      await _matchRepo.submitResult(
        matchId: matchId,
        result: result,
        submittedByUid: uid,
      );
      // The stream advances the phase to awaitingOpponent.
    } catch (_) {
      if (isClosed) return;
      // Losing the submit race is not an error: the opponent's submission
      // landed first and the state-guarded transaction rejected ours. If the
      // streamed doc has already advanced, derive from it (→ review) instead
      // of demanding a retry; if the doc arrives after this catch, the
      // lost-race check in _onMatch recovers instead.
      final match = state.match;
      if (match != null && match.state != fs.MatchStates.occupied) {
        emit(state.copyWith(phase: _derivePhase(match)));
        return;
      }
      emit(
        state.copyWith(
          phase: ResultPhase.error,
          errorKind: ResultErrorKind.submit,
        ),
      );
    }
  }

  /// Confirms the opponent's submitted result → the atomic ELO transaction.
  /// The transaction also returns any badges unlocked by this confirmation; we
  /// resolve *this* user's set to their definitions for the client-local unlock
  /// reveal on the summary (the stream, meanwhile, advances the phase).
  Future<void> confirm() async {
    if (state.phase != ResultPhase.review) return;
    emit(state.copyWith(phase: ResultPhase.confirming));
    try {
      final unlocked = await _matchRepo.confirmResult(
        matchId: matchId,
        now: _now(),
      );
      // The stream advances the phase to summary.
      await _resolveNewBadges(unlocked[uid] ?? const {});
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: ResultPhase.error,
          errorKind: ResultErrorKind.confirm,
        ),
      );
    }
  }

  /// Reveals this user's just-unlocked badges when the summary is reached via the
  /// match stream rather than a local `confirm()` — i.e. for the player who did
  /// NOT run the confirm write (their badges are written by the opponent's confirm
  /// transaction, so `confirmResult`'s return value never reaches this device).
  ///
  /// The confirm transaction stamps each earned badge with the same instant it
  /// sets `confirmedAt`, so a badge earned by THIS match is exactly one whose
  /// timestamp is not before `match.confirmedAt`. Guarded so it never re-reveals,
  /// and swallows failures — the reveal is decorative and the badge is already
  /// persisted server-side.
  Future<void> _resolveNewBadgesFromDoc(MatchModel match) async {
    if (state.newBadges.isNotEmpty) return;
    final confirmedAt = match.confirmedAt;
    if (confirmedAt == null) return;
    try {
      final me = await _userRepo.getUser(uid);
      if (isClosed || me == null) return;
      final ids = me.badges.entries
          .where((e) => !e.value.isBefore(confirmedAt))
          .map((e) => e.key)
          .toSet();
      await _resolveNewBadges(ids);
    } catch (_) {
      // Decorative; the badge is already persisted server-side.
    }
  }

  /// Resolves the ids this user just unlocked to their [AchievementDefModel]s
  /// (badge PNG + name key) for the reveal. Fire-and-forget decoration: a failed
  /// definitions read leaves the summary intact, no reveal — never an error.
  Future<void> _resolveNewBadges(Set<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final defs = await _achievementRepo.getDefinitions();
      if (isClosed) return;
      final mine = defs.where((d) => ids.contains(d.achievementId)).toList();
      if (mine.isEmpty) return;
      emit(state.copyWith(newBadges: mine));
    } catch (_) {
      // Reveal is decorative; the badge is already persisted server-side.
    }
  }

  /// Disputes the opponent's submitted result. (A griefer serving a penalty is
  /// silently force-confirmed by the transaction, so the stream may advance to
  /// summary instead of closed — handled uniformly by the stream.)
  Future<void> dispute() async {
    if (state.phase != ResultPhase.review) return;
    emit(state.copyWith(phase: ResultPhase.disputing));
    try {
      await _matchRepo.disputeResult(
        matchId: matchId,
        disputingUid: uid,
        now: _now(),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: ResultPhase.error,
          errorKind: ResultErrorKind.dispute,
        ),
      );
    }
  }

  /// Recovers from an error: re-derive the phase from the latest match, or
  /// re-subscribe if the load itself failed.
  void retry() {
    final match = state.match;
    if (state.errorKind == ResultErrorKind.load || match == null) {
      emit(const ResultState());
      load();
      return;
    }
    final phase = _derivePhase(match);
    emit(
      state.copyWith(
        phase: phase,
        errorKind: null,
        summary: phase == ResultPhase.summary ? _buildSummary(match) : null,
      ),
    );
    if (phase == ResultPhase.summary) _loadRank(match);
  }

  // --- summary + enrichment ------------------------------------------------

  /// The `eloBefore`/`eloDeltas` map key for this user: their uid (singles) or
  /// their pair's id (doubles — the stored key whose members include them).
  String _myKey(MatchModel match) {
    if (match.mode != 'doubles') return uid;
    final keys = match.eloBefore?.keys ?? const <String>[];
    for (final k in keys) {
      if (k == uid || k.split('_').contains(uid)) return k;
    }
    return uid;
  }

  EloSummary? _buildSummary(MatchModel match) {
    final before = match.eloBefore;
    final deltas = match.eloDeltas;
    if (before == null || deltas == null) return null;
    final key = _myKey(match);
    final oldElo = before[key];
    final delta = deltas[key];
    if (oldElo == null || delta == null) return null;
    final isWin = match.result?.winnerIds.contains(uid) ?? false;
    return EloSummary(
      isWin: isWin,
      oldElo: oldElo,
      newElo: oldElo + delta,
      delta: delta,
      isSingles: match.mode != 'doubles',
    );
  }

  /// Loads the updated campus rank for the summary pill (singles only).
  Future<void> _loadRank(MatchModel match) async {
    final summary = state.summary;
    if (summary == null || !summary.isSingles || summary.rank != null) return;
    try {
      final rank = await _ratingRepo.getUserRank(
        sportId: match.sportId,
        elo: summary.newElo,
      );
      if (isClosed || state.summary == null) return;
      emit(state.copyWith(summary: state.summary!.copyWith(rank: rank)));
    } catch (_) {
      // The pill just stays hidden — decorative.
    }
  }

  bool _playersLoadedFor(List<String> uids) =>
      uids.every(state.players.containsKey);

  /// Best-effort display names for the player cards. Isolated from the match
  /// stream so an enrichment failure can't blank the screen.
  void _loadPlayersIfNeeded(MatchModel match) {
    if (_playersLoadedFor(match.playerUids)) return;
    unawaited(_loadPlayers(match.playerUids));
  }

  Future<void> _loadPlayers(List<String> uids) async {
    final entries = await Future.wait(
      uids.map((puid) async {
        try {
          final name = (await _userRepo.getUser(puid))?.name;
          return MapEntry(puid, name ?? '');
        } catch (_) {
          return MapEntry(puid, '');
        }
      }),
    );
    if (isClosed) return;
    emit(
      state.copyWith(players: {...state.players, ...Map.fromEntries(entries)}),
    );
  }

  @override
  Future<void> close() {
    _matchSub?.cancel();
    return super.close();
  }
}
