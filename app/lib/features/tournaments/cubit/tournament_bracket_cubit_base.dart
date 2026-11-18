import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bracket/bracket_engine.dart' as engine;
import '../../../core/constants.dart';
import '../../../models/match_model.dart';
import '../../../models/tournament_model.dart';
import '../../../repositories/match_repository.dart';
import '../../../repositories/tournament_repository.dart';

/// Shared core for the two tournament-bracket cubits — the live-bracket screen's
/// `TournamentCubit` and the detail screen's `TournamentDetailCubit`. Owns the
/// three Firestore streams (tournament doc, participants, bracket matches), the
/// engine-derived [engine.BracketTree], the lazy Spark-tier lifecycle healings
/// (`seedIfDue` on load, `activateIfStarted` + `completeIfDecided` on derive),
/// and per-stream liveness.
///
/// Liveness matters: a Firestore `snapshots()` error terminates its stream
/// permanently. [hasStreamError] latches on the first such failure so a later
/// emission on a surviving stream can never paper a dead stream over with a
/// healthy-looking projection — the subclass keeps showing `error` (and its
/// reachable `retry`) until [retry] resubscribes all three.
///
/// Subclasses own only their state type and its projection: they implement
/// [project] (consulting [hasStreamError]/[coreLoaded]/[tournamentData]/
/// [treeData]/the raw lists) and may override the [onTournamentData]/
/// [onParticipantsData]/[onReset] hooks for their own enrichment. They must not
/// touch the streams directly.
abstract class TournamentBracketCubitBase<S> extends Cubit<S> {
  TournamentBracketCubitBase({
    required this.tournamentId,
    required TournamentRepository tournamentRepository,
    required MatchRepository matchRepository,
    required S initialState,
  }) : _tournamentRepo = tournamentRepository,
       _matchRepo = matchRepository,
       super(initialState);

  final String tournamentId;
  final TournamentRepository _tournamentRepo;
  final MatchRepository _matchRepo;

  /// The tournament repository, exposed for subclass organizer/registration
  /// writes (participant flags, status).
  @protected
  TournamentRepository get tournamentRepo => _tournamentRepo;

  // --- raw stream inputs + derived tree (protected for projection) ----------
  @protected
  TournamentModel? tournamentData;
  @protected
  List<TournamentParticipantModel> participantsData = const [];
  @protected
  List<MatchModel> matchesData = const [];
  @protected
  engine.BracketTree? treeData;

  StreamSubscription<TournamentModel?>? _tournamentSub;
  StreamSubscription<List<TournamentParticipantModel>>? _participantsSub;
  StreamSubscription<List<MatchModel>>? _matchesSub;

  bool _errored = false;
  bool _tournamentLoaded = false;
  bool _participantsLoaded = false;
  bool _seedFired = false;
  bool _activationFired = false;
  bool _completionFired = false;

  /// A `snapshots()` stream has permanently errored (or the tournament doc went
  /// missing). Latches until [retry].
  @protected
  bool get hasStreamError => _errored;

  /// Both the tournament doc and participants have produced a first value — the
  /// bracket is derivable. (Matches may still be loading; an empty bracket is
  /// valid.)
  @protected
  bool get coreLoaded => _tournamentLoaded && _participantsLoaded;

  /// Starts the three streams and fires the one-shot lazy seeding. [now] is
  /// injectable so tests can drive the deadline-based `seedIfDue` transition.
  @protected
  void start({DateTime? now}) {
    _seedIfDue(now);
    _tournamentSub = _tournamentRepo
        .watchTournament(tournamentId)
        .listen(_onTournament, onError: (_) => _onStreamError());
    _participantsSub = _tournamentRepo
        .watchParticipants(tournamentId)
        .listen(_onParticipants, onError: (_) => _onStreamError());
    _matchesSub = _matchRepo
        .watchTournamentMatches(tournamentId)
        .listen(_onMatches, onError: (_) => _onStreamError());
  }

  Future<void> _seedIfDue(DateTime? now) async {
    if (_seedFired) return;
    _seedFired = true;
    // Best-effort lazy transition; a failure just leaves the tournament in
    // `registering` for the next visitor to retry.
    try {
      await _tournamentRepo.seedIfDue(tournamentId, now: now);
    } catch (_) {}
  }

  void _onTournament(TournamentModel? tournament) {
    if (isClosed) return;
    if (tournament == null) {
      _onStreamError();
      return;
    }
    tournamentData = tournament;
    _tournamentLoaded = true;
    _afterData();
    onTournamentData(tournament);
  }

  void _onParticipants(List<TournamentParticipantModel> participants) {
    if (isClosed) return;
    participantsData = participants;
    _participantsLoaded = true;
    _afterData();
    onParticipantsData(participants);
  }

  void _onMatches(List<MatchModel> matches) {
    if (isClosed) return;
    matchesData = matches;
    _afterData();
  }

  void _onStreamError() {
    if (isClosed) return;
    _errored = true;
    project();
  }

  /// Re-derives the tree, runs the lazy healings, and asks the subclass to
  /// project the state. [hasStreamError] latches, so [project] can never emit a
  /// ready projection over an errored stream.
  void _afterData() {
    treeData = tournamentData == null
        ? null
        : engine.build(
            participants: participantsData,
            bracket: tournamentData!.bracket,
            matches: matchesData,
          );
    _heal();
    project();
  }

  void _heal() {
    final tournament = tournamentData;
    if (tournament == null) return;
    final status = tournament.status;

    // `seeded → active` self-heal: a bracket match exists but the best-effort
    // status flip that rides `recordBracketMatch` was dropped. Fired once, from
    // whichever screen observes the started bracket first — no extra read.
    if (!_activationFired &&
        matchesData.isNotEmpty &&
        status == TournamentStatus.seeded) {
      _activationFired = true;
      _tournamentRepo.activateIfStarted(tournamentId).catchError((_) {});
    }

    // Lazy completion the moment a champion is derived; the repository guard
    // ignores a raced/terminal tournament anyway.
    final champion = treeData?.championUid;
    if (!_completionFired &&
        champion != null &&
        (status == TournamentStatus.active ||
            status == TournamentStatus.seeded)) {
      _completionFired = true;
      _tournamentRepo
          .completeIfDecided(tournamentId, champion)
          .catchError((_) {});
    }
  }

  /// Tears down and re-establishes the streams after an error and re-enters
  /// loading — a Firestore `snapshots()` error terminates the stream, so
  /// recovery must resubscribe, not just re-read.
  void retry() {
    _cancelSubs();
    tournamentData = null;
    participantsData = const [];
    matchesData = const [];
    treeData = null;
    _errored = false;
    _tournamentLoaded = false;
    _participantsLoaded = false;
    _seedFired = false;
    _activationFired = false;
    _completionFired = false;
    onReset();
    project(); // emits the subclass loading state (no data, no error)
    start();
  }

  void _cancelSubs() {
    _tournamentSub?.cancel();
    _participantsSub?.cancel();
    _matchesSub?.cancel();
  }

  // --- subclass contract ----------------------------------------------------

  /// Emit the state for the current inputs. Implementations MUST branch on
  /// [hasStreamError] first (emit their error state), then on load progress,
  /// then project the ready state from [tournamentData]/[treeData]/the raw
  /// lists. Safe to call again after out-of-band enrichment resolves.
  @protected
  void project();

  /// Hook: the tournament doc produced a new value (after the tree rebuilt and
  /// projected). Override to launch tournament-scoped enrichment (e.g. facility
  /// forecast); default no-op.
  @protected
  void onTournamentData(TournamentModel tournament) {}

  /// Hook: the participants list produced a new value. Override to launch
  /// roster-scoped enrichment (names, ELO); default no-op.
  @protected
  void onParticipantsData(List<TournamentParticipantModel> participants) {}

  /// Hook: [retry] cleared the raw inputs — clear subclass-owned caches here so
  /// stale enrichment can't survive a resubscribe. Default no-op.
  @protected
  void onReset() {}

  @override
  Future<void> close() {
    _cancelSubs();
    return super.close();
  }
}
