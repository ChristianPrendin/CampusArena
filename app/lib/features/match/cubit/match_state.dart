import 'package:equatable/equatable.dart';

import '../../../core/constants.dart';
import '../../../models/facility_model.dart';
import '../../../models/match_model.dart';

/// UX lifecycle of one check-in / active-match session.
///
/// This is the *screen* lifecycle, distinct from the Firestore match-doc
/// `state` field (`occupied`/`awaitingConfirmation`/…). The pre-match states
/// (`idle`→`readyToConfirm`→`checkingIn`) are owned by this cubit; every state
/// from [waitingOpponent] onward is *derived from the streamed match doc*, so
/// this vertical never writes results — it only reflects what C's result flow
/// and the confirmation transaction persist.
enum MatchStatus {
  /// Pre-scan: the viewfinder is live, nothing resolved yet.
  idle,

  /// A scanned/typed code is being resolved to a facility.
  resolving,

  /// Facility resolved and soft-checks computed; awaiting the user's explicit
  /// check-in (deep-link entry) or the auto-confirm after the queue nudge
  /// (blind-scan entry).
  readyToConfirm,

  /// Creating the match (occupies the facility). Ranked write → asserts network.
  checkingIn,

  /// Match `occupied` but fewer than the mode's required players have checked
  /// in — the opponent slot shows a "waiting" placeholder.
  waitingOpponent,

  /// Match `occupied` with a full roster: the live timer runs.
  active,

  /// Match `awaitingConfirmation` — a result was submitted (by this device via
  /// the result flow, or by the opponent) and awaits confirmation.
  resultSubmitted,

  /// Streamed terminal states.
  confirmed,
  disputed,

  /// Streamed terminal without a confirmed result (`unconfirmed`/`abandoned`).
  ended,

  /// Resolution or check-in failed (see [MatchState.errorKind]).
  error,
}

/// What failed, so the UI can pick the right copy and retry affordance.
///
/// [tableBusy] is the deliberate "you can't join this" outcome: the scanned
/// table already has a live match this user is neither in nor able to join (a
/// full roster, or one already `awaitingConfirmation`). It is surfaced instead
/// of silently attaching the scanner as a spectator to a match they can't act
/// on.
enum MatchErrorKind { invalidCode, checkIn, load, tableBusy, sportMismatch }

/// Decorative name + ELO for one player card. Both fields are best-effort
/// enrichment (see the `decorative-lookups-isolated` rule): a failed lookup
/// leaves them null and the card falls back to initials / a blank ELO rather
/// than erroring the whole screen.
class PlayerDisplay extends Equatable {
  const PlayerDisplay({required this.uid, this.name, this.elo});

  final String uid;
  final String? name;
  final int? elo;

  @override
  List<Object?> get props => [uid, name, elo];
}

class MatchState extends Equatable {
  const MatchState({
    this.status = MatchStatus.idle,
    this.facility,
    this.match,
    this.gpsDistanceMeters,
    this.gpsFar = false,
    this.queuePosition,
    this.queueFrontPosition,
    this.players = const {},
    this.errorKind,
  });

  final MatchStatus status;

  /// The resolved facility, once a code is resolved or a deep link opens.
  final FacilityModel? facility;

  /// The streamed match doc; null before check-in.
  final MatchModel? match;

  /// Distance from the user to [facility] at scan time, logged into the match's
  /// `gpsDistanceMeters`. Null when location was unavailable (never blocks).
  final double? gpsDistanceMeters;

  /// Whether [gpsDistanceMeters] exceeds the soft threshold — drives the
  /// non-blocking "you seem far" banner only.
  final bool gpsFar;

  /// My ticket position in this facility's queue, or null if I'm not queued.
  final int? queuePosition;

  /// The front-of-queue ticket position, or null if the queue is empty.
  final int? queueFrontPosition;

  /// uid → decorative display info for the player cards.
  final Map<String, PlayerDisplay> players;

  final MatchErrorKind? errorKind;

  /// True when I'm queued but not at the front *and* this check-in is a claim of
  /// a free table — the soft priority nudge fires. A join of an already-occupied
  /// table (scanning in as the opponent) is never queue-jumping, so it never
  /// warns even when I'm mid-queue for that table.
  bool get queuePriorityWarning =>
      facility?.status == FacilityStatus.free &&
      queuePosition != null &&
      queueFrontPosition != null &&
      queuePosition != queueFrontPosition;

  MatchState copyWith({
    MatchStatus? status,
    FacilityModel? facility,
    MatchModel? match,
    double? gpsDistanceMeters,
    bool? gpsFar,
    int? queuePosition,
    int? queueFrontPosition,
    Map<String, PlayerDisplay>? players,
    MatchErrorKind? errorKind,
  }) {
    return MatchState(
      status: status ?? this.status,
      facility: facility ?? this.facility,
      match: match ?? this.match,
      gpsDistanceMeters: gpsDistanceMeters ?? this.gpsDistanceMeters,
      gpsFar: gpsFar ?? this.gpsFar,
      queuePosition: queuePosition ?? this.queuePosition,
      queueFrontPosition: queueFrontPosition ?? this.queueFrontPosition,
      players: players ?? this.players,
      errorKind: errorKind ?? this.errorKind,
    );
  }

  @override
  List<Object?> get props => [
    status,
    facility,
    match,
    gpsDistanceMeters,
    gpsFar,
    queuePosition,
    queueFrontPosition,
    players,
    errorKind,
  ];
}
