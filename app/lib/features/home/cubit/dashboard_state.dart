import 'package:equatable/equatable.dart';

import '../../../core/constants.dart';
import '../../../models/match_model.dart';
import '../../../models/rating_model.dart';

enum DashboardStatus { loading, ready, error }

class DashboardState extends Equatable {
  /// The user's per-sport ratings, ordered per [SportIds.supported].
  final List<RatingModel> ratings;

  /// Terminal-state matches within the fetched window, newest first. The view
  /// filters these to the selected sport and caps the displayed count.
  final List<MatchModel> recentMatches;

  /// uid → username cache for resolving opponent names on history rows.
  final Map<String, String> opponentNames;

  /// The sport the dashboard is currently focused on (drives the hero card and
  /// the history filter). Persisted here so the choice survives rebuilds.
  final String selectedSportId;

  final DashboardStatus status;

  DashboardState({
    this.ratings = const [],
    this.recentMatches = const [],
    this.opponentNames = const {},
    String? selectedSportId,
    this.status = DashboardStatus.loading,
  }) : selectedSportId = selectedSportId ?? SportIds.supported.first;

  /// The rating for [selectedSportId], or null while ratings are still loading
  /// or if the user has no rating for it.
  RatingModel? get selectedRating {
    for (final rating in ratings) {
      if (rating.sportId == selectedSportId) return rating;
    }
    return null;
  }

  /// Terminal matches for the selected sport, newest first.
  List<MatchModel> get selectedRecentMatches =>
      recentMatches.where((m) => m.sportId == selectedSportId).toList();

  DashboardState copyWith({
    List<RatingModel>? ratings,
    List<MatchModel>? recentMatches,
    Map<String, String>? opponentNames,
    String? selectedSportId,
    DashboardStatus? status,
  }) {
    return DashboardState(
      ratings: ratings ?? this.ratings,
      recentMatches: recentMatches ?? this.recentMatches,
      opponentNames: opponentNames ?? this.opponentNames,
      selectedSportId: selectedSportId ?? this.selectedSportId,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
    ratings,
    recentMatches,
    opponentNames,
    selectedSportId,
    status,
  ];
}
