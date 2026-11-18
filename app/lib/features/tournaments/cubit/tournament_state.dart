import 'package:equatable/equatable.dart';

import '../../../core/bracket/bracket_engine.dart';
import '../../../models/facility_model.dart';
import '../../../models/match_model.dart';
import '../../../models/tournament_model.dart';

enum BracketStatus { loading, ready, error }

/// State of the live-bracket screen: the tournament doc, its participants and
/// bracket matches, the derived [tree], the facility (for the forecast strip),
/// and a uid → display-name cache.
///
/// [tree] is deliberately excluded from [props]: it is a pure function of
/// [tournament] + [participants] + [matches] (all of which ARE in props), so it
/// changes only when one of them does — keeping it out avoids spurious
/// rebuilds from the mutable tree's identity churn.
class TournamentState extends Equatable {
  const TournamentState({
    this.tournament,
    this.participants = const [],
    this.matches = const [],
    this.tree,
    this.facility,
    this.names = const {},
    this.status = BracketStatus.loading,
  });

  final TournamentModel? tournament;
  final List<TournamentParticipantModel> participants;
  final List<MatchModel> matches;
  final BracketTree? tree;
  final FacilityModel? facility;
  final Map<String, String> names;
  final BracketStatus status;

  TournamentState copyWith({
    TournamentModel? tournament,
    List<TournamentParticipantModel>? participants,
    List<MatchModel>? matches,
    BracketTree? tree,
    FacilityModel? facility,
    Map<String, String>? names,
    BracketStatus? status,
  }) {
    return TournamentState(
      tournament: tournament ?? this.tournament,
      participants: participants ?? this.participants,
      matches: matches ?? this.matches,
      tree: tree ?? this.tree,
      facility: facility ?? this.facility,
      names: names ?? this.names,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
    tournament,
    participants,
    matches,
    facility,
    names,
    status,
  ];
}
