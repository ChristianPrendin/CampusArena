import 'dart:async';

import '../../../core/bracket/bracket_engine.dart' as engine;
import '../../../core/constants.dart';
import '../../../models/tournament_model.dart';
import '../../../repositories/match_repository.dart';
import '../../../repositories/rating_repository.dart';
import '../../../repositories/tournament_repository.dart';
import '../../../repositories/user_repository.dart';
import 'tournament_bracket_cubit_base.dart';
import 'tournament_detail_state.dart';

/// Drives the tournament detail screen. On top of the shared
/// [TournamentBracketCubitBase] streams + lazy healings, it derives an ordered
/// standings list, resolves decorative name + ELO enrichment (their failures
/// never move to `error`), and exposes the organizer controls.
///
/// Elimination is a *derived* property: a player is out if they are the
/// non-winning side of any resolved bracket slot (a confirmed loss — never
/// flagged) OR carry the `eliminated` flag (an organizer forfeit/advance). Both
/// feed the standings split and every organizer control reduces to flipping
/// flags.
///
/// The constructor is side-effect free; [init] starts the async work.
class TournamentDetailCubit
    extends TournamentBracketCubitBase<TournamentDetailState> {
  TournamentDetailCubit({
    required super.tournamentId,
    required this.uid,
    TournamentRepository? tournamentRepository,
    MatchRepository? matchRepository,
    UserRepository? userRepository,
    RatingRepository? ratingRepository,
  }) : _userRepo = userRepository ?? UserRepository(),
       _ratingRepo = ratingRepository ?? RatingRepository(),
       super(
         tournamentRepository: tournamentRepository ?? TournamentRepository(),
         matchRepository: matchRepository ?? MatchRepository(),
         initialState: const TournamentDetailState(),
       );

  final String uid;
  final UserRepository _userRepo;
  final RatingRepository _ratingRepo;
  final Map<String, String> _nameCache = {};
  final Map<String, int> _eloCache = {};

  void init() => start();

  @override
  void project() {
    if (hasStreamError) {
      emit(state.copyWith(status: TournamentDetailStatus.error));
      return;
    }
    final tournament = tournamentData;
    if (tournament == null) return; // stay in loading until the doc arrives

    final tree = treeData;

    // Derived eliminations: the non-winning side of every resolved slot with
    // two real players (a bye win — one side null — eliminates no one). The
    // BracketTree groups slots by round key, so flatten across rounds.
    final eliminated = <String>{
      for (final p in participantsData)
        if (p.eliminated) p.uid,
    };
    if (tree != null) {
      for (final slot in tree.slots.values.expand((s) => s)) {
        final winner = slot.winnerUid;
        if (winner == null || slot.a.uid == null || slot.b.uid == null) {
          continue;
        }
        eliminated.add(slot.a.uid == winner ? slot.b.uid! : slot.a.uid!);
      }
    }

    final standings = [
      for (final p in participantsData)
        StandingEntry(
          uid: p.uid,
          name: _nameCache[p.uid],
          elo: _eloCache[p.uid],
          eliminated: eliminated.contains(p.uid),
        ),
    ]..sort(_byStanding);

    emit(
      state.copyWith(
        status: TournamentDetailStatus.ready,
        tournament: tournament,
        participants: participantsData,
        standings: standings,
        tree: tree,
        isOrganizer: tournament.organizerId == uid,
      ),
    );
  }

  @override
  void onTournamentData(TournamentModel tournament) => _resolveEnrichment();

  @override
  void onParticipantsData(List<TournamentParticipantModel> participants) =>
      _resolveEnrichment();

  @override
  void onReset() {
    _nameCache.clear();
    _eloCache.clear();
  }

  /// Alive first, then eliminated; each group by ELO descending (unrated last).
  static int _byStanding(StandingEntry a, StandingEntry b) {
    if (a.eliminated != b.eliminated) return a.eliminated ? 1 : -1;
    final ea = a.elo ?? -1;
    final eb = b.elo ?? -1;
    return eb.compareTo(ea);
  }

  Future<void> _resolveEnrichment() async {
    final sportId = tournamentData?.sportId;
    if (sportId == null) return;
    final uids = participantsData.map((p) => p.uid).toList();

    final unknownNames = uids.where((u) => !_nameCache.containsKey(u)).toList();
    if (unknownNames.isNotEmpty) {
      try {
        final users = await _userRepo.getUsersByIds(unknownNames);
        for (final u in users) {
          _nameCache[u.uid] = u.name;
        }
      } catch (_) {
        // Names decorative: rows fall back to initials.
      }
    }

    final unknownElos = uids.where((u) => !_eloCache.containsKey(u)).toList();
    if (unknownElos.isNotEmpty) {
      try {
        // Batched by document id (deterministic rating ids) — one read for the
        // whole roster instead of an N+1 fan-out.
        final ratings = await _ratingRepo.getUserRatings(unknownElos, sportId);
        ratings.forEach((u, rating) => _eloCache[u] = rating.elo);
      } catch (_) {
        // ELO decorative.
      }
    }

    if (isClosed) return;
    project();
  }

  /// Registers the current user (used while the tournament is still
  /// `registering`, where standings double as the sign-up list). Returns true on
  /// success. The participants stream refreshes the roster.
  Future<bool> register() async {
    try {
      await tournamentRepo.registerParticipant(tournamentId, uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- organizer controls (write ONLY participant flags / status) ----------

  /// Marks [forfeitUid] as forfeited; the bracket re-derives so their opponent
  /// advances. Tagged [EliminationReason.forfeit] to keep a no-show/withdrawal
  /// distinguishable from an organizer-declared win.
  Future<void> markForfeit(String forfeitUid) {
    return tournamentRepo.updateParticipant(tournamentId, forfeitUid, {
      'eliminated': true,
      'eliminationReason': EliminationReason.forfeit,
    });
  }

  /// Advances [slot] by declaring [winnerUid] — the OTHER side is flagged
  /// eliminated ([EliminationReason.advanced]) and the tree re-derives.
  ///
  /// Guarded against a stale sheet: the sheet acts on a slot snapshot from when
  /// it opened, so a result confirmed in the meantime must win. Re-resolve the
  /// live slot by `(round, index)` and abort if it is already decided —
  /// otherwise picking the losing side would flag the real winner `eliminated`,
  /// which the engine reads as a forfeit in their next slot.
  Future<void> advanceSlot(engine.BracketSlot slot, String winnerUid) {
    final live = _liveSlot(slot);
    if (live == null || live.winnerUid != null) return Future.value();
    final loserUid = live.a.uid == winnerUid ? live.b.uid : live.a.uid;
    if (loserUid == null) return Future.value();
    return tournamentRepo.updateParticipant(tournamentId, loserUid, {
      'eliminated': true,
      'eliminationReason': EliminationReason.advanced,
    });
  }

  /// The current derived slot at [slot]'s position, or null if the bracket no
  /// longer has it (re-seeded/shrunk).
  engine.BracketSlot? _liveSlot(engine.BracketSlot slot) {
    final slots = treeData?.slots[slot.round];
    if (slots == null) return null;
    for (final s in slots) {
      if (s.index == slot.index) return s;
    }
    return null;
  }

  /// Cancels the tournament (organizer, `registering` only).
  Future<void> cancel() {
    return tournamentRepo.updateTournament(tournamentId, {
      'status': TournamentStatus.cancelled,
    });
  }
}
