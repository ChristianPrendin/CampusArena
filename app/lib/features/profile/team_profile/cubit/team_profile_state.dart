import 'package:equatable/equatable.dart';

import '../../../../core/constants.dart';
import '../../../../models/match_model.dart';
import '../../../../models/rating_model.dart';
import '../../../../models/user_model.dart';
import '../../profile_stats.dart';

enum TeamProfileStatus { loading, ready, error }

/// State for the team (pair) profile — the doubles counterpart of
/// [ProfileState], keyed on the deterministic pairId. Holds the two members
/// (header), the pair's per-sport team ratings, the pair's match history, and
/// the isolate-derived team stats/trend.
class TeamProfileState extends Equatable {
  final String pairId;

  /// The two players, once resolved — drives the header avatars and names.
  final List<UserModel> members;

  /// The pair's per-sport team ratings, ordered per [SportIds.supported].
  final List<RatingModel> ratings;

  /// The pair's terminal-state matches within the window, newest first.
  final List<MatchModel> matches;

  /// Isolate-derived team stats + trend (no fun stats for a pair).
  final ProfileDerivation derivation;

  final Map<String, String> opponentNames;
  final Map<String, String> facilityNames;

  final String selectedSportId;
  final TeamProfileStatus status;

  TeamProfileState({
    required this.pairId,
    this.members = const [],
    this.ratings = const [],
    this.matches = const [],
    this.derivation = ProfileDerivation.empty,
    this.opponentNames = const {},
    this.facilityNames = const {},
    String? selectedSportId,
    this.status = TeamProfileStatus.loading,
  }) : selectedSportId = selectedSportId ?? SportIds.supported.first;

  SportStats get selectedStats => derivation.statsFor(selectedSportId);

  List<TrendPoint> get selectedTrend => derivation.trendFor(selectedSportId);

  TeamProfileState copyWith({
    List<UserModel>? members,
    List<RatingModel>? ratings,
    List<MatchModel>? matches,
    ProfileDerivation? derivation,
    Map<String, String>? opponentNames,
    Map<String, String>? facilityNames,
    String? selectedSportId,
    TeamProfileStatus? status,
  }) {
    return TeamProfileState(
      pairId: pairId,
      members: members ?? this.members,
      ratings: ratings ?? this.ratings,
      matches: matches ?? this.matches,
      derivation: derivation ?? this.derivation,
      opponentNames: opponentNames ?? this.opponentNames,
      facilityNames: facilityNames ?? this.facilityNames,
      selectedSportId: selectedSportId ?? this.selectedSportId,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
    pairId,
    members,
    ratings,
    matches,
    derivation,
    opponentNames,
    facilityNames,
    selectedSportId,
    status,
  ];
}
