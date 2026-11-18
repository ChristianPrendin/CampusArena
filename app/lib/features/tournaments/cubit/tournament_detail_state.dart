import 'package:equatable/equatable.dart';

import '../../../core/bracket/bracket_engine.dart';
import '../../../models/tournament_model.dart';

enum TournamentDetailStatus { loading, ready, error }

/// One standings row: the participant, resolved display name + current sport
/// ELO (both decorative), and whether they are out (dimmed, sorted last).
class StandingEntry extends Equatable {
  const StandingEntry({
    required this.uid,
    this.name,
    this.elo,
    required this.eliminated,
  });

  final String uid;
  final String? name;
  final int? elo;
  final bool eliminated;

  @override
  List<Object?> get props => [uid, name, elo, eliminated];
}

class TournamentDetailState extends Equatable {
  const TournamentDetailState({
    this.status = TournamentDetailStatus.loading,
    this.tournament,
    this.participants = const [],
    this.standings = const [],
    this.tree,
    this.isOrganizer = false,
  });

  final TournamentDetailStatus status;
  final TournamentModel? tournament;
  final List<TournamentParticipantModel> participants;

  /// Standings, already ordered: alive first then eliminated, each group by ELO
  /// descending.
  final List<StandingEntry> standings;

  /// The derived bracket; null until the first derivation. Its `playableSlots`
  /// drive the Advance-slot organizer sheet.
  final BracketTree? tree;

  /// The viewer is the organizer (drives the controls' visibility).
  final bool isOrganizer;

  /// Slots the organizer can advance (both sides concrete, no winner yet).
  List<BracketSlot> get playableSlots => tree?.playableSlots ?? const [];

  /// Alive participants (not eliminated) — the mark-forfeit candidate list.
  List<StandingEntry> get aliveStandings =>
      standings.where((s) => !s.eliminated).toList();

  TournamentDetailState copyWith({
    TournamentDetailStatus? status,
    TournamentModel? tournament,
    List<TournamentParticipantModel>? participants,
    List<StandingEntry>? standings,
    BracketTree? tree,
    bool? isOrganizer,
  }) {
    return TournamentDetailState(
      status: status ?? this.status,
      tournament: tournament ?? this.tournament,
      participants: participants ?? this.participants,
      standings: standings ?? this.standings,
      tree: tree ?? this.tree,
      isOrganizer: isOrganizer ?? this.isOrganizer,
    );
  }

  @override
  List<Object?> get props => [
    status,
    tournament,
    participants,
    standings,
    tree,
    isOrganizer,
  ];
}
