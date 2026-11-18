import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants.dart';
import '../../../core/match_display.dart';
import '../../../models/match_model.dart';
import '../../../models/rating_model.dart';
import '../../../repositories/match_repository.dart';
import '../../../repositories/rating_repository.dart';
import '../../../repositories/user_repository.dart';
import 'dashboard_state.dart';

/// Drives the Home / Dashboard tab: streams the user's per-sport ratings and
/// recent matches, and resolves opponent display names for the history list.
///
/// Opponent-name lookups are a fire-and-forget decoration layered onto the two
/// live streams; their failures never move the dashboard to `error`.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({
    required this.uid,
    RatingRepository? ratingRepository,
    MatchRepository? matchRepository,
    UserRepository? userRepository,
  }) : _ratingRepository = ratingRepository ?? RatingRepository(),
       _matchRepository = matchRepository ?? MatchRepository(),
       _userRepository = userRepository ?? UserRepository(),
       super(DashboardState()) {
    _subscribe();
  }

  final String uid;
  final RatingRepository _ratingRepository;
  final MatchRepository _matchRepository;
  final UserRepository _userRepository;

  // Over-fetch a bounded window so each sport still has enough terminal matches
  // to fill its five-row history slice after the view filters by sport.
  static const int _historyFetchLimit = 20;
  static const Set<String> _terminalStates = {
    MatchStates.confirmed,
    MatchStates.disputed,
    MatchStates.unconfirmed,
    MatchStates.abandoned,
  };

  StreamSubscription<List<RatingModel>>? _ratingsSub;
  StreamSubscription<List<MatchModel>>? _matchesSub;

  bool _ratingsLoaded = false;
  bool _matchesLoaded = false;

  void _subscribe() {
    _ratingsSub = _ratingRepository
        .watchUserRatings(uid)
        .listen(_onRatings, onError: _onError);
    _matchesSub = _matchRepository
        .watchUserMatches(uid, limit: _historyFetchLimit)
        .listen(_onMatches, onError: _onError);
  }

  DashboardStatus get _computedStatus {
    if (state.status == DashboardStatus.error) return DashboardStatus.error;
    return (_ratingsLoaded && _matchesLoaded)
        ? DashboardStatus.ready
        : DashboardStatus.loading;
  }

  void _onRatings(List<RatingModel> ratings) {
    final ordered = [
      for (final sportId in SportIds.supported)
        ...ratings.where((r) => r.sportId == sportId),
    ];
    _ratingsLoaded = true;
    emit(state.copyWith(ratings: ordered, status: _computedStatus));
  }

  void _onMatches(List<MatchModel> matches) {
    final recent = matches
        .where((m) => _terminalStates.contains(m.state))
        .toList();
    _matchesLoaded = true;
    emit(state.copyWith(recentMatches: recent, status: _computedStatus));
    _resolveOpponentNames(recent);
  }

  Future<void> _resolveOpponentNames(List<MatchModel> matches) async {
    final unknown = <String>{for (final m in matches) ...opponentUids(m, uid)}
      ..removeWhere(state.opponentNames.containsKey);
    if (unknown.isEmpty) return;
    try {
      final users = await Future.wait(unknown.map(_userRepository.getUser));
      if (isClosed) return;
      final resolved = {
        for (final u in users)
          if (u != null) u.uid: u.username,
      };
      if (resolved.isEmpty) return;
      emit(
        state.copyWith(opponentNames: {...state.opponentNames, ...resolved}),
      );
    } catch (_) {
      // Names are decorative: rows fall back to the sport-name title.
    }
  }

  /// Focuses the dashboard on [sportId]; the hero card and history filter
  /// follow. No-op if it is already selected. Ranks and matches for the sport
  /// are already in state, so switching is instant with no refetch.
  void selectSport(String sportId) {
    if (sportId == state.selectedSportId) return;
    emit(state.copyWith(selectedSportId: sportId));
  }

  void _onError(Object error, StackTrace stackTrace) {
    emit(state.copyWith(status: DashboardStatus.error));
  }

  /// Tears down and re-establishes both streams after an error.
  void retry() {
    _ratingsSub?.cancel();
    _matchesSub?.cancel();
    _ratingsLoaded = false;
    _matchesLoaded = false;
    // Preserve the sport the user was viewing across the reload.
    emit(DashboardState(selectedSportId: state.selectedSportId));
    _subscribe();
  }

  @override
  Future<void> close() {
    _ratingsSub?.cancel();
    _matchesSub?.cancel();
    return super.close();
  }
}
