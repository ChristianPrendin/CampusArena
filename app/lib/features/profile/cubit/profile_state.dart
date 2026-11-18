import 'package:equatable/equatable.dart';

import '../../../core/constants.dart';
import '../../../models/achievement_def_model.dart';
import '../../../models/match_model.dart';
import '../../../models/rating_model.dart';
import '../../../models/user_model.dart';
import '../profile_stats.dart';

enum ProfileStatus { loading, ready, error }

class ProfileState extends Equatable {
  /// The profiled user's document — header identity plus the `badges` map
  /// (carried for the Phase 7/A achievements grid; no UI here).
  final UserModel? user;

  /// The user's per-sport ratings, ordered per [SportIds.supported].
  final List<RatingModel> ratings;

  /// Terminal-state matches within the fetched window, newest first — the
  /// full history log across sports (non-confirmed states included).
  final List<MatchModel> matches;

  /// Isolate-derived stats/trend/fun-stats over the same window.
  final ProfileDerivation derivation;

  /// uid → username cache for opponent names on history rows and fun-stat
  /// cards.
  final Map<String, String> opponentNames;

  /// facilityId → facility name cache for history rows.
  final Map<String, String> facilityNames;

  /// The sport the trend card, stat tiles, and fun-stat cards focus on.
  final String selectedSportId;

  /// The badge definitions for the achievement grid (all 6). Loaded best-effort
  /// and independent of [status] — an empty list just hides the section.
  final List<AchievementDefModel> achievementDefs;

  final ProfileStatus status;

  ProfileState({
    this.user,
    this.ratings = const [],
    this.matches = const [],
    this.derivation = ProfileDerivation.empty,
    this.opponentNames = const {},
    this.facilityNames = const {},
    String? selectedSportId,
    this.achievementDefs = const [],
    this.status = ProfileStatus.loading,
  }) : selectedSportId = selectedSportId ?? SportIds.supported.first;

  /// Achievement badges keyed by achievement id (unlock timestamp as value).
  Map<String, DateTime> get badges => user?.badges ?? const {};

  SportStats get selectedStats => derivation.statsFor(selectedSportId);

  List<TrendPoint> get selectedTrend => derivation.trendFor(selectedSportId);

  SportFunStats get selectedFunStats => derivation.funStatsFor(selectedSportId);

  ProfileState copyWith({
    UserModel? user,
    List<RatingModel>? ratings,
    List<MatchModel>? matches,
    ProfileDerivation? derivation,
    Map<String, String>? opponentNames,
    Map<String, String>? facilityNames,
    String? selectedSportId,
    List<AchievementDefModel>? achievementDefs,
    ProfileStatus? status,
  }) {
    return ProfileState(
      user: user ?? this.user,
      ratings: ratings ?? this.ratings,
      matches: matches ?? this.matches,
      derivation: derivation ?? this.derivation,
      opponentNames: opponentNames ?? this.opponentNames,
      facilityNames: facilityNames ?? this.facilityNames,
      selectedSportId: selectedSportId ?? this.selectedSportId,
      achievementDefs: achievementDefs ?? this.achievementDefs,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
    user,
    ratings,
    matches,
    derivation,
    opponentNames,
    facilityNames,
    selectedSportId,
    achievementDefs,
    status,
  ];
}
