import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants.dart' as fs;
import '../../../models/facility_model.dart';
import '../../../models/match_model.dart';
import '../../../repositories/facility_repository.dart';
import '../../../repositories/match_repository.dart';
import '../../../repositories/queue_repository.dart';
import '../../../repositories/rating_repository.dart';
import '../../../repositories/tournament_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../map/facility_ui.dart';
import '../../map/user_location_service.dart';
import 'match_state.dart';

/// Beyond this straight-line distance (metres) from the facility the check-in
/// shows the soft "you seem far" warning. It NEVER blocks — indoor/covered GPS
/// drift would otherwise risk a failed demo (project_description.md §3.4, §0).
/// No exact number is specified there; 100 m is a campus-sane default that
/// tolerates GPS drift while still catching an obviously-remote spoof.
const double kGpsSoftCheckThresholdMeters = 100;

/// Drives one QR check-in and the resulting active-match session.
///
/// Writer role: [confirmCheckIn] calls [MatchRepository.createMatch], which
/// atomically flips `facilities/{id}.status` → `occupied` and sets
/// `currentMatchId` (the facility-status-flip shared contract; the map vertical
/// reads it). This cubit is *only* a reader of the match doc thereafter — it
/// streams `matches/{id}` and maps the doc's `state` onto [MatchStatus], so the
/// result/confirm/dispute transitions come from C's result flow and the
/// confirmation transaction, never from a write here.
///
/// Soft checks on scan (both non-blocking, per the Decision Log): GPS distance
/// is logged into the match's `gpsDistanceMeters`; a non-front queued user gets
/// the Phase-3B priority nudge (surfaced via [MatchState.queuePriorityWarning]).
class MatchCubit extends Cubit<MatchState> {
  MatchCubit({
    required this.uid,
    this.tournamentId,
    this.tournamentRound,
    this.expectedSportId,
    MatchRepository? matchRepository,
    FacilityRepository? facilityRepository,
    QueueRepository? queueRepository,
    RatingRepository? ratingRepository,
    UserRepository? userRepository,
    TournamentRepository? tournamentRepository,
    UserLocationService? locationService,
  }) : _matchRepo = matchRepository ?? MatchRepository(),
       _facilityRepo = facilityRepository ?? FacilityRepository(),
       _queueRepo = queueRepository ?? QueueRepository(),
       _ratingRepo = ratingRepository ?? RatingRepository(),
       _userRepo = userRepository ?? UserRepository(),
       _tournamentRepo = tournamentRepository ?? TournamentRepository(),
       _location = locationService ?? const UserLocationService(),
       super(const MatchState());

  final String uid;

  /// Tournament context threaded from the check-in deep link
  /// (`?tournamentId=…&round=…`). Both null for an ordinary walk-up match; both
  /// set when a bracket slot's check-in URL is opened. Persisted onto the match
  /// doc at [confirmCheckIn], which unlocks the ×1.5 confirm-time multiplier.
  final String? tournamentId;
  final String? tournamentRound;

  /// The sport a scanned/opened table must be for, threaded from an accepted
  /// direct challenge's "scan to play" (`/play/scan?sport=…`). Null for an
  /// ordinary walk-up scan, which accepts any table. When set, a facility whose
  /// `sportId` differs is rejected with [MatchErrorKind.sportMismatch] rather
  /// than starting a match on the wrong sport's table.
  final String? expectedSportId;

  final MatchRepository _matchRepo;
  final FacilityRepository _facilityRepo;
  final QueueRepository _queueRepo;
  final RatingRepository _ratingRepo;
  final UserRepository _userRepo;
  final TournamentRepository _tournamentRepo;
  final UserLocationService _location;

  StreamSubscription<MatchModel?>? _matchSub;

  /// Deep-link open: resolve the facility, then attach to its active match if
  /// one exists, otherwise prepare a check-in (with the soft warnings computed).
  Future<void> openFacility(String id) async {
    emit(const MatchState(status: MatchStatus.resolving));
    final FacilityModel? facility;
    try {
      facility = await _facilityRepo.getFacility(id);
    } catch (_) {
      _emitError(MatchErrorKind.invalidCode);
      return;
    }
    if (isClosed) return;
    if (facility == null) {
      _emitError(MatchErrorKind.invalidCode);
      return;
    }
    if (_isWrongSport(facility)) {
      _emitError(MatchErrorKind.sportMismatch);
      return;
    }

    // Already-live table: join it if the roster has room, then attach. A
    // deep-linked opponent (scanning the table's QR with the OS camera) lands
    // here, so this is their only join path — without it they would sit as a
    // spectator while both players wait forever.
    if (await _attachExistingMatch(facility)) return;
    if (isClosed) return;

    await _prepare(facility);
  }

  /// Attaches to [facility]'s live match (`occupied` or `awaitingConfirmation`),
  /// joining its roster first when there is an open slot and this user isn't
  /// already in it. Returns true when the live match was handled (attached, or
  /// rejected as busy), false when the table has none (the caller then proceeds
  /// to create one).
  ///
  /// The single implementation of "join-or-reject an already-live table", shared
  /// by the deep-link open and the blind-scan create-race fallback, so both
  /// entry paths treat an occupied table — including one that has raced to
  /// `awaitingConfirmation` — identically. The three outcomes:
  ///  - **Participant** (already in `playerUids`): re-attach as a viewer of
  ///    their own match. This is the supported re-entry path — the confirming
  ///    player lands here to confirm, and a player whose app restarted mid-match
  ///    rejoins their own table.
  ///  - **Non-participant with an open slot** (`occupied`, roster not full):
  ///    join it — singles auto-joins the one slot; doubles attaches so the
  ///    active-match screen can surface the Team 1 / Team 2 side picker.
  ///  - **Non-participant, no open slot** (full roster, or already
  ///    `awaitingConfirmation`/beyond): the table has an ongoing match this user
  ///    cannot join, so fail with [MatchErrorKind.tableBusy] rather than
  ///    silently spectating a match they can't act on.
  Future<bool> _attachExistingMatch(FacilityModel facility) async {
    final MatchModel? active;
    try {
      active = await _matchRepo.getActiveMatchForFacility(facility.facilityId);
    } catch (e) {
      // A genuine read failure (offline, permission) must not be swallowed
      // into "no live match": that would send the caller into createMatch,
      // which fails on the already-occupied facility and reports the same
      // failure back as a misleading generic check-in error.
      debugPrint(
        'getActiveMatchForFacility(${facility.facilityId}) failed: $e',
      );
      _emitError(MatchErrorKind.checkIn);
      return true;
    }
    if (isClosed) return true;
    if (active == null) return false;

    final isParticipant = active.playerUids.contains(uid);
    final hasOpenSlot =
        active.state == fs.MatchStates.occupied &&
        active.playerUids.length < _requiredPlayers(active.mode);

    // A live table this user is neither in nor able to join: reject it. Without
    // this, scanning a full or already-submitted table would drop the scanner
    // into a spectator view of a match they can't influence.
    if (!isParticipant && !hasOpenSlot) {
      _emitError(MatchErrorKind.tableBusy);
      return true;
    }

    // Doubles: never auto-join — the joiner must pick Team 1 or Team 2 first, so
    // attach and let the active-match screen surface the side picker (which
    // calls [joinSide]). Singles keeps the one-slot auto-join.
    if (active.mode == fs.MatchModes.singles && !isParticipant && hasOpenSlot) {
      try {
        await _matchRepo.joinMatch(
          facilityId: facility.facilityId,
          uid: uid,
          // Backfill this deep link's bracket context onto a match the opponent
          // created context-free (they scanned the plain facility QR first).
          tournamentId: tournamentId,
          tournamentRound: tournamentRound,
        );
        // The joined match had no tournament context but this player deep-linked
        // into a bracket slot: record it so the slot resolves and confirm scores
        // at ×1.5. Idempotent + best-effort — the same treatment as the create
        // path, and it never dead-ends the attach.
        final tid = tournamentId;
        final round = tournamentRound;
        if (tid != null && round != null && active.tournamentId == null) {
          try {
            await _tournamentRepo.recordBracketMatch(
              tid,
              round,
              active.matchId,
            );
          } catch (_) {}
        }
      } catch (_) {
        // Raced full / no longer joinable (e.g. already awaitingConfirmation):
        // fall back to attaching as a viewer.
      }
      if (isClosed) return true;
    }
    emit(MatchState(status: _statusForMatch(active), facility: facility));
    _attachMatch(active.matchId);
    return true;
  }

  /// Blind-scanner entry: a scanned QR value or a typed fallback code.
  Future<void> submitCode(String rawCode) async {
    emit(const MatchState(status: MatchStatus.resolving));
    final facility = await _resolveCode(rawCode);
    if (isClosed) return;
    if (facility == null) {
      _emitError(MatchErrorKind.invalidCode);
      return;
    }
    if (_isWrongSport(facility)) {
      _emitError(MatchErrorKind.sportMismatch);
      return;
    }
    await _prepare(facility);
  }

  /// True when a challenge fixed the sport ([expectedSportId] set) and this
  /// facility is for a different one — the guard that stops a ping-pong
  /// challenge from being played on a foosball table.
  bool _isWrongSport(FacilityModel facility) =>
      expectedSportId != null && facility.sportId != expectedSportId;

  /// Resolves the soft-check signals for [facility] and moves to
  /// [MatchStatus.readyToConfirm]. Never blocks: every probe failure degrades
  /// to "no signal" rather than an error.
  Future<void> _prepare(FacilityModel facility) async {
    final distance = await _distanceTo(facility);
    final (mine, front) = await _queueStanding(facility.facilityId);
    if (isClosed) return;
    emit(
      MatchState(
        status: MatchStatus.readyToConfirm,
        facility: facility,
        gpsDistanceMeters: distance,
        gpsFar: distance != null && distance > kGpsSoftCheckThresholdMeters,
        queuePosition: mine,
        queueFrontPosition: front,
      ),
    );
  }

  /// Creates the match and occupies the facility (the writer contract). Safe to
  /// call only from [MatchStatus.readyToConfirm].
  ///
  /// [mode] is `singles` (default) or `doubles`; for doubles the creator's
  /// chosen side ([creatorTeam], 1 or 2) is seeded into `teamNPairId` as a
  /// single-member pairId (its own uid). The three others fill the roster via
  /// [joinSide].
  Future<void> confirmCheckIn({
    String mode = fs.MatchModes.singles,
    int creatorTeam = 1,
  }) async {
    final facility = state.facility;
    if (state.status != MatchStatus.readyToConfirm || facility == null) return;

    final pending = state.copyWith(status: MatchStatus.checkingIn);
    emit(pending);

    final isDoubles = mode == fs.MatchModes.doubles;
    final match = MatchModel(
      matchId: '',
      facilityId: facility.facilityId,
      sportId: facility.sportId,
      mode: mode,
      playerUids: [uid],
      team1PairId: isDoubles && creatorTeam == 1 ? uid : null,
      team2PairId: isDoubles && creatorTeam == 2 ? uid : null,
      state: fs.MatchStates.occupied,
      tournamentId: tournamentId,
      tournamentRound: tournamentRound,
      gpsDistanceMeters: state.gpsDistanceMeters,
      startedAt: DateTime.now(),
    );

    try {
      final id = await _matchRepo.createMatch(match);
      // Tournament context: record the new match under its bracket round (the
      // only tournament write the match path makes) and flip seeded → active on
      // the first. Genuinely best-effort — the match doc already carries
      // `tournamentId`/`tournamentRound`, and the bracket engine reconstructs a
      // failed record from that field, so a dropped write self-heals rather than
      // desyncing the bracket. It also never dead-ends the check-in.
      final tid = tournamentId;
      final round = tournamentRound;
      if (tid != null && round != null) {
        try {
          await _tournamentRepo.recordBracketMatch(tid, round, id);
        } catch (_) {}
      }
      if (isClosed) return;
      _attachMatch(id);
    } on StateError {
      // The table was occupied between prepare and confirm (a race, or the
      // opponent started first). Attach to whatever live match now exists —
      // joining if there's an open slot, else spectating — the same way the
      // deep-link path does, so a table that raced to awaitingConfirmation
      // lands on the clean spectator view instead of a generic error.
      if (await _attachExistingMatch(facility)) return;
      if (isClosed) return;
      _emitError(MatchErrorKind.checkIn);
    } catch (_) {
      _emitError(MatchErrorKind.checkIn);
    }
  }

  /// Joins the currently-attached doubles match on [team] (1 or 2). The roster
  /// updates through the match stream, so this only writes. Best-effort: a side
  /// that raced to full throws in the repo and is swallowed — the stream keeps
  /// showing the true roster and the picker stays available for the open side.
  Future<void> joinSide(int team) async {
    final match = state.match;
    if (match == null || match.playerUids.contains(uid)) return;
    try {
      await _matchRepo.joinMatch(
        facilityId: match.facilityId,
        uid: uid,
        team: team,
        tournamentId: tournamentId,
        tournamentRound: tournamentRound,
      );
      // Mirror the deep-link create path: record this bracket slot when the
      // joined match carried no tournament context of its own.
      final tid = tournamentId;
      final round = tournamentRound;
      if (tid != null && round != null && match.tournamentId == null) {
        try {
          await _tournamentRepo.recordBracketMatch(tid, round, match.matchId);
        } catch (_) {}
      }
    } catch (_) {
      // Side full / raced: nothing fatal — the stream reflects the truth.
    }
  }

  /// Leaves the flow. A *participant* in an in-progress (`occupied`, no result
  /// yet) match settles it so the table doesn't stay locked until the lazy
  /// timeout; how depends on whether an opponent had joined:
  ///  - No opponent yet (`waitingOpponent`): the check-in never became a real
  ///    match, so it is *cancelled* — the doc is deleted, leaving no phantom
  ///    `abandoned` entry in the player's history.
  ///  - Opponent present (`active`): a real match is being walked away from, so
  ///    it is genuinely *abandoned*.
  /// The gate is roster membership, not who created the doc: re-entering your
  /// own table via a fresh deep link attaches as a viewer, and this still lets
  /// you free it. A pure spectator (not in `playerUids`) or a match past
  /// `occupied` just detaches. Best-effort — leaving never blocks on the write.
  Future<void> leave() async {
    await _matchSub?.cancel();
    _matchSub = null;
    final match = state.match;
    if (match != null &&
        match.state == fs.MatchStates.occupied &&
        match.playerUids.contains(uid)) {
      final opponentJoined =
          match.playerUids.length >= _requiredPlayers(match.mode);
      try {
        if (opponentJoined) {
          await _matchRepo.abandonMatch(
            matchId: match.matchId,
            facilityId: match.facilityId,
          );
        } else {
          await _matchRepo.cancelMatch(
            matchId: match.matchId,
            facilityId: match.facilityId,
          );
        }
      } catch (_) {
        // The lazy 4-hour timeout is the backstop if this free-write fails.
      }
    }
  }

  /// Backs out of a prepared or failed check-in (e.g. the user yields to the
  /// queue after the priority nudge) — returns to the idle scanner.
  void reset() {
    _matchSub?.cancel();
    _matchSub = null;
    emit(const MatchState());
  }

  // --- internals -----------------------------------------------------------

  void _attachMatch(String matchId) {
    _matchSub?.cancel();
    _matchSub = _matchRepo.watchMatch(matchId).listen(_onMatch);
  }

  void _onMatch(MatchModel? m) {
    if (isClosed) return;
    if (m == null) {
      _emitError(MatchErrorKind.load);
      return;
    }
    final previous = state.match;
    emit(state.copyWith(status: _statusForMatch(m), match: m));
    if (previous == null || !listEquals(previous.playerUids, m.playerUids)) {
      unawaited(_loadPlayers(m));
    }
  }

  /// Best-effort name + ELO for each player card. Isolated from the match
  /// stream so an enrichment failure can't blank the whole screen.
  Future<void> _loadPlayers(MatchModel m) async {
    // Resolve every player card in parallel — a doubles roster would otherwise
    // cost up to eight serial round-trips before the screen fills in.
    final cards = await Future.wait(
      m.playerUids.map((puid) async {
        String? name;
        int? elo;
        try {
          name = (await _userRepo.getUser(puid))?.name;
        } catch (_) {}
        try {
          elo = (await _ratingRepo.getUserRating(puid, m.sportId))?.elo;
        } catch (_) {}
        return PlayerDisplay(uid: puid, name: name, elo: elo);
      }),
    );
    if (isClosed) return;
    emit(state.copyWith(players: {for (final c in cards) c.uid: c}));
  }

  MatchStatus _statusForMatch(MatchModel m) {
    switch (m.state) {
      case fs.MatchStates.occupied:
        return m.playerUids.length >= _requiredPlayers(m.mode)
            ? MatchStatus.active
            : MatchStatus.waitingOpponent;
      case fs.MatchStates.awaitingConfirmation:
        return MatchStatus.resultSubmitted;
      case fs.MatchStates.confirmed:
        return MatchStatus.confirmed;
      case fs.MatchStates.disputed:
        return MatchStatus.disputed;
      case fs.MatchStates.unconfirmed:
      case fs.MatchStates.abandoned:
        return MatchStatus.ended;
      default:
        return MatchStatus.active;
    }
  }

  int _requiredPlayers(String mode) => mode == 'doubles' ? 4 : 2;

  /// Distance to [facility] using the shared location service + geodesy. Null
  /// when location is unavailable (permission denied, services off, drift).
  Future<double?> _distanceTo(FacilityModel facility) async {
    try {
      final position = await _location.getCurrentPosition();
      return facilityDistanceMeters(facility, position);
    } catch (_) {
      return null;
    }
  }

  /// My dense 1-based rank in this facility's queue and the front rank (always
  /// 1), derived from the ordered snapshot index — the stored `position` is a
  /// monotonic ticket number, not a display rank. `(null, null)` when the queue
  /// is empty or unreadable; a `(null, 1)` means others are queued but I am not.
  Future<(int?, int?)> _queueStanding(String facilityId) async {
    try {
      final entries = await _queueRepo.watchQueue(facilityId).first;
      if (entries.isEmpty) return (null, null);
      final mineIndex = entries.indexWhere((e) => e.uid == uid);
      final mine = mineIndex >= 0 ? mineIndex + 1 : null;
      return (mine, 1);
    } catch (_) {
      return (null, null);
    }
  }

  Future<FacilityModel?> _resolveCode(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final candidateId = _lastPathSegment(trimmed);

    // The QR sticker encodes the deep-link value, so the trailing segment is
    // usually the facility doc id — a direct lookup covers the common case.
    try {
      final byId = await _facilityRepo.getFacility(candidateId);
      if (byId != null) return byId;
    } catch (_) {}

    // Otherwise match the raw value against qrCode / the printed fallbackCode.
    // The facility set is capped small (Spark tier), so a client-side scan of
    // the one live snapshot is cheap and needs no new repository query.
    try {
      final all = await _facilityRepo.watchFacilities().first;
      final upper = trimmed.toUpperCase();
      for (final f in all) {
        if (f.qrCode == trimmed ||
            f.qrCode == candidateId ||
            f.fallbackCode.toUpperCase() == upper) {
          return f;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Extracts the last non-empty path segment, so a bare id, a
  /// `/play/facility/<id>` path, or a full URL all resolve to `<id>`.
  String _lastPathSegment(String raw) {
    final noQuery = raw.split('?').first.split('#').first;
    final segments = noQuery.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? raw : segments.last;
  }

  void _emitError(MatchErrorKind kind) {
    if (isClosed) return;
    emit(MatchState(status: MatchStatus.error, errorKind: kind));
  }

  @override
  Future<void> close() {
    _matchSub?.cancel();
    return super.close();
  }
}
