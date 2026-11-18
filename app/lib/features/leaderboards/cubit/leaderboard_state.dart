import 'package:equatable/equatable.dart';

import '../../../core/constants.dart';
import '../../../models/rating_model.dart';
import '../../../models/user_model.dart';

enum LeaderboardStatus { loading, ready, error }

/// The three ranking scopes the leaderboard can show. [global] is every player
/// for the sport; [friends] is the user + their friends; [myCourse] is players
/// on the user's own degree program (the course-rivalry board).
enum LeaderboardScope { global, friends, myCourse }

/// Which rating entity the board ranks: [singles] shows per-user ratings across
/// all scopes; [doubles] shows the pair (team) ratings, global-only.
enum LeaderboardMode { singles, doubles }

/// Lifecycle of the player-search overlay: [idle] when no query, [loading] while
/// resolving matches and their ranks, [done] once results are ready.
enum LeaderboardSearchStatus { idle, loading, done }

/// A search match enriched with a standing in the *current* sport + scope.
///
/// Singles: [user] is the matched player; [rating]/[rank] are null when they
/// have no position in that scope but the result still links to their profile.
/// Doubles: [user] is null and [rating] is the matched *pair* board row (its
/// `memberUids` name the two players), [rank] its board position — the row taps
/// through to the team profile.
class LeaderboardSearchResult extends Equatable {
  const LeaderboardSearchResult({this.user, this.rating, this.rank});

  final UserModel? user;
  final RatingModel? rating;
  final int? rank;

  @override
  List<Object?> get props => [user, rating, rank];
}

class LeaderboardState extends Equatable {
  /// The ranked rows for the current sport + scope, ELO-descending.
  final List<RatingModel> entries;

  /// ownerId (uid) → display name, resolved lazily. A row is absent while its
  /// name is still loading or if the lookup failed (decorative, never blocks).
  final Map<String, String> displayNames;

  /// The current user's own rating for the selected sport, for the pinned
  /// "your rank" bar; null while loading or if they have no rating.
  final RatingModel? currentUserRating;

  /// The current user's campus rank for the selected sport; null while the
  /// aggregation is in flight or failed (the bar hides rather than erroring).
  final int? currentUserRank;

  final String selectedSportId;
  final LeaderboardScope scope;
  final LeaderboardMode mode;
  final LeaderboardStatus status;

  /// The raw player-search query. Non-empty means the search overlay is shown
  /// in place of the ranked list.
  final String searchQuery;

  /// Players matching [searchQuery], each carrying their rank in the current
  /// sport + scope; empty when not searching.
  final List<LeaderboardSearchResult> searchResults;

  /// Lifecycle of the search overlay, so the UI can distinguish "still
  /// resolving" from "no matches".
  final LeaderboardSearchStatus searchStatus;

  LeaderboardState({
    this.entries = const [],
    this.displayNames = const {},
    this.currentUserRating,
    this.currentUserRank,
    String? selectedSportId,
    this.scope = LeaderboardScope.global,
    this.mode = LeaderboardMode.singles,
    this.status = LeaderboardStatus.loading,
    this.searchQuery = '',
    this.searchResults = const [],
    this.searchStatus = LeaderboardSearchStatus.idle,
  }) : selectedSportId = selectedSportId ?? SportIds.supported.first;

  bool get isSearching => searchQuery.trim().isNotEmpty;

  LeaderboardState copyWith({
    List<RatingModel>? entries,
    Map<String, String>? displayNames,
    RatingModel? currentUserRating,
    int? currentUserRank,
    String? selectedSportId,
    LeaderboardScope? scope,
    LeaderboardMode? mode,
    LeaderboardStatus? status,
    String? searchQuery,
    List<LeaderboardSearchResult>? searchResults,
    LeaderboardSearchStatus? searchStatus,
    // Clears the pinned-rank fields to null (which the `?? this` pattern can't
    // express) — used when switching to a sport the user may never have played.
    bool resetCurrentUser = false,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      displayNames: displayNames ?? this.displayNames,
      currentUserRating: resetCurrentUser
          ? null
          : (currentUserRating ?? this.currentUserRating),
      currentUserRank: resetCurrentUser
          ? null
          : (currentUserRank ?? this.currentUserRank),
      selectedSportId: selectedSportId ?? this.selectedSportId,
      scope: scope ?? this.scope,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      searchStatus: searchStatus ?? this.searchStatus,
    );
  }

  @override
  List<Object?> get props => [
    entries,
    displayNames,
    currentUserRating,
    currentUserRank,
    selectedSportId,
    scope,
    mode,
    status,
    searchQuery,
    searchResults,
    searchStatus,
  ];
}
