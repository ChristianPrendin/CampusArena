import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants.dart';
import '../../../models/rating_model.dart';
import '../../../models/user_model.dart';
import '../../../repositories/rating_repository.dart';
import '../../../repositories/user_repository.dart';
import 'leaderboard_state.dart';

/// Drives the Leaderboards tab: streams the ranked board for the selected sport
/// and scope, resolves player display names, tracks the current user's own rank
/// for the pinned bar, and serves username search.
///
/// The constructor is side-effect free (synchronous initial state); [init]
/// starts the async work, mirroring `FacilityCubit.subscribe`. Name resolution
/// and the your-rank bar are fire-and-forget decorations over the ranked list;
/// their failures never move the screen to `error`.
class LeaderboardCubit extends Cubit<LeaderboardState> {
  LeaderboardCubit({
    required this.uid,
    RatingRepository? ratingRepository,
    UserRepository? userRepository,
  }) : _ratingRepository = ratingRepository ?? RatingRepository(),
       _userRepository = userRepository ?? UserRepository(),
       super(LeaderboardState());

  final String uid;
  final RatingRepository _ratingRepository;
  final UserRepository _userRepository;

  static const int _boardLimit = 100;
  static const Duration _searchDebounce = Duration(milliseconds: 300);

  /// Current user doc — supplies the degree program (course scope). The
  /// friends board does not read it: friend lists change while the tab is
  /// alive (the friends screen writes `friendUids` directly), so
  /// [_loadFriendsBoard] re-reads the user doc on every run instead.
  UserModel? _currentUser;

  /// Whether the current-user load has completed. Tracked explicitly rather
  /// than inferred from board emptiness, so a friends board built before the
  /// load (self-only) is re-fetched once the real friend list arrives.
  bool _currentUserLoaded = false;

  /// Cache of resolved display names, mirrored into state on each update.
  final Map<String, String> _nameCache = {};

  StreamSubscription<List<RatingModel>>? _boardSub;
  Timer? _searchTimer;

  /// Starts the initial board subscription, current-user load, and rank fetch.
  /// Called once by the screen after construction.
  void init() {
    _subscribe();
    _loadCurrentUser();
    _refreshCurrentUserRank();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _userRepository.getUser(uid);
      if (isClosed) return;
      _currentUser = user;
      _currentUserLoaded = true;
      // A course board built before the user resolved used an empty query —
      // re-run it now with the real degree program. (The friends board loads
      // its own fresh user doc, so it never needs this.)
      if (state.scope == LeaderboardScope.myCourse) _subscribe();
    } catch (_) {
      // Non-fatal: the global board still works; course/friends scopes stay
      // degraded until a retry reloads the user.
    }
  }

  void _subscribe() {
    _boardSub?.cancel();
    _boardSub = null;
    final sportId = state.selectedSportId;

    // Doubles is global-only: pair ratings carry no degreeProgram (no course
    // board) and a friends-pairs board would need a memberUids index we don't
    // ship. One pair-owned board query, reusing the existing (sportId,
    // ownerType, elo) composite index.
    if (state.mode == LeaderboardMode.doubles) {
      _boardSub = _ratingRepository
          .watchLeaderboard(
            sportId: sportId,
            ownerType: OwnerType.pair,
            limit: _boardLimit,
          )
          .listen(_onEntries, onError: _onError);
      return;
    }

    switch (state.scope) {
      case LeaderboardScope.global:
        _boardSub = _ratingRepository
            .watchLeaderboard(sportId: sportId, limit: _boardLimit)
            .listen(_onEntries, onError: _onError);
      case LeaderboardScope.myCourse:
        final degree = _currentUser?.degreeProgram;
        if (degree == null) {
          _onEntries(const []);
          return;
        }
        _boardSub = _ratingRepository
            .watchLeaderboard(
              sportId: sportId,
              degreeProgram: degree,
              limit: _boardLimit,
            )
            .listen(_onEntries, onError: _onError);
      case LeaderboardScope.friends:
        _loadFriendsBoard(sportId);
    }
  }

  /// Friends board is a one-shot fetch (not a stream) — re-run on every sport
  /// or scope switch. Re-reads the user doc first so a friend added (or
  /// removed) since the last load is reflected without an app restart.
  Future<void> _loadFriendsBoard(String sportId) async {
    try {
      final user = await _userRepository.getUser(uid);
      if (isClosed) return;
      _currentUser = user;
      _currentUserLoaded = true;
      final uids = <String>[uid, ...?user?.friendUids];
      final ratings = await _ratingRepository.getFriendsLeaderboard(
        sportId: sportId,
        userAndFriendUids: uids,
      );
      // Bail if the sport OR scope changed while this fetch was in flight, so a
      // slow response can't overwrite a newer board.
      if (isClosed ||
          state.scope != LeaderboardScope.friends ||
          sportId != state.selectedSportId) {
        return;
      }
      _onEntries(ratings);
    } catch (error, stackTrace) {
      _onError(error, stackTrace);
    }
  }

  void _onEntries(List<RatingModel> entries) {
    emit(state.copyWith(status: LeaderboardStatus.ready, entries: entries));
    _resolveNames(entries);
    // Search positions are read off `entries`, so recompute them whenever the
    // board changes under an active query (e.g. the scope-switch refresh ran
    // before the new board had loaded).
    if (state.isSearching) _refreshSearch();
  }

  Future<void> _resolveNames(List<RatingModel> entries) async {
    // A pair row's ownerId is a synthetic pairId, not a user doc — resolve its
    // two memberUids instead so both names render.
    final unknown = <String>{
      for (final r in entries)
        if (r.ownerType == OwnerType.pair) ...?r.memberUids else r.ownerId,
    }..removeWhere(_nameCache.containsKey);
    if (unknown.isEmpty) return;
    try {
      // One batched query instead of a read per row.
      final users = await _userRepository.getUsersByIds(unknown.toList());
      if (isClosed || users.isEmpty) return;
      for (final u in users) {
        _nameCache[u.uid] = u.name;
      }
      emit(state.copyWith(displayNames: Map.of(_nameCache)));
    } catch (_) {
      // Names are decorative: rows fall back to the uid.
    }
  }

  Future<void> _refreshCurrentUserRank() async {
    // The pinned "your rank" bar is a singles, campus-wide rank — a user has no
    // single doubles rank (one per pair), so it stays hidden in doubles mode.
    if (state.mode == LeaderboardMode.doubles) return;
    final sportId = state.selectedSportId;
    try {
      final rating = await _ratingRepository.getUserRating(uid, sportId);
      if (isClosed || sportId != state.selectedSportId || rating == null) {
        return;
      }
      final rank = await _ratingRepository.getUserRank(
        sportId: sportId,
        elo: rating.elo,
      );
      if (isClosed || sportId != state.selectedSportId) return;
      emit(state.copyWith(currentUserRating: rating, currentUserRank: rank));
    } catch (_) {
      // The your-rank bar is decorative: leave it hidden on failure.
    }
  }

  /// Switches the board to [sportId]; refetches the ranked list and the pinned
  /// rank. No-op if already selected.
  void selectSport(String sportId) {
    if (sportId == state.selectedSportId) return;
    // Clear the previous sport's pinned rank so switching to a sport the user
    // has never played doesn't leave a stale rank/ELO showing.
    emit(
      state.copyWith(
        selectedSportId: sportId,
        status: LeaderboardStatus.loading,
        entries: const [],
        resetCurrentUser: true,
      ),
    );
    _subscribe();
    _refreshCurrentUserRank();
    // Ranks in an open search are sport-specific — recompute for the new sport.
    if (state.isSearching) _refreshSearch();
  }

  /// Switches the ranking scope (global / friends / course). No-op if already
  /// active.
  void selectScope(LeaderboardScope scope) {
    if (scope == state.scope) return;
    emit(
      state.copyWith(
        scope: scope,
        status: LeaderboardStatus.loading,
        entries: const [],
      ),
    );
    _subscribe();
    // Ranks in an open search are scope-specific — recompute for the new scope.
    // (Friends scope also re-runs from `_onEntries` once its board loads.)
    if (state.isSearching) _refreshSearch();
  }

  /// Switches between the singles (per-user) and doubles (per-pair) boards.
  /// Doubles is global-only, so it snaps the scope back to global. No-op if
  /// already active.
  void selectMode(LeaderboardMode mode) {
    if (mode == state.mode) return;
    emit(
      state.copyWith(
        mode: mode,
        scope: mode == LeaderboardMode.doubles
            ? LeaderboardScope.global
            : state.scope,
        status: LeaderboardStatus.loading,
        entries: const [],
        resetCurrentUser: true,
      ),
    );
    _subscribe();
    // The pinned bar is singles-only; refresh it when returning to singles.
    if (mode == LeaderboardMode.singles) _refreshCurrentUserRank();
    if (state.isSearching) _refreshSearch();
  }

  /// Debounced username-prefix search. Each match is enriched with the player's
  /// rank in the *current* sport + scope, so the overlay answers "where does
  /// this player sit on the board I'm looking at". An empty query clears it.
  void search(String query) {
    emit(state.copyWith(searchQuery: query));
    _searchTimer?.cancel();
    if (query.trim().isEmpty) {
      emit(
        state.copyWith(
          searchResults: const [],
          searchStatus: LeaderboardSearchStatus.idle,
        ),
      );
      return;
    }
    emit(state.copyWith(searchStatus: LeaderboardSearchStatus.loading));
    _searchTimer = Timer(_searchDebounce, () => _refreshSearch(query));
  }

  /// Re-runs the active search against the current filters. Called on each
  /// debounced keystroke and whenever the sport/scope/current-user changes
  /// while a query is active, so displayed ranks always track the board.
  void _refreshSearch([String? query]) {
    final q = query ?? state.searchQuery;
    if (q.trim().isEmpty) return;
    unawaited(
      _runSearch(q).catchError((_) {
        // Search failure: keep prior results, just clear the spinner.
        if (!isClosed) {
          emit(state.copyWith(searchStatus: LeaderboardSearchStatus.done));
        }
      }),
    );
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    final sportId = state.selectedSportId;
    final scope = state.scope;
    final mode = state.mode;

    // True if the board the search was launched against is no longer showing.
    bool stale() =>
        isClosed ||
        trimmed != state.searchQuery.trim() ||
        sportId != state.selectedSportId ||
        scope != state.scope ||
        mode != state.mode;

    final users = await _userRepository.searchUsers(trimmed, limit: 10);
    if (stale()) return;

    // Doubles: board-first only. A matched member's pair rows on the loaded
    // top-N board become results (exact rank = board index). Teams below the
    // board are out of scope — a deep pairs search would need a memberUids
    // index we don't ship.
    if (mode == LeaderboardMode.doubles) {
      final matchedUids = {for (final u in users) u.uid};
      final results = <LeaderboardSearchResult>[
        for (var i = 0; i < state.entries.length; i++)
          if ((state.entries[i].memberUids ?? const []).any(
            matchedUids.contains,
          ))
            LeaderboardSearchResult(rating: state.entries[i], rank: i + 1),
      ];
      if (stale()) return;
      emit(
        state.copyWith(
          searchResults: results,
          searchStatus: LeaderboardSearchStatus.done,
        ),
      );
      return;
    }

    // A player's position on the *loaded* board is their index there — exact,
    // free, and works identically in every scope. This is the primary path:
    // the board (top-100 / the whole friends set / the course board) already
    // holds the players a user would search for.
    final indexByOwner = <String, int>{
      for (var i = 0; i < state.entries.length; i++)
        state.entries[i].ownerId: i,
    };

    // Only players NOT on the loaded board need a lookup to be placed. Friends
    // scope has no board beyond `entries`, so absentees there are simply not
    // friends and stay unranked — no lookup at all.
    final offBoardUids = scope == LeaderboardScope.friends
        ? const <String>[]
        : [
            for (final u in users)
              if (!indexByOwner.containsKey(u.uid)) u.uid,
          ];
    final offBoardRatings = offBoardUids.isEmpty
        ? const <String, RatingModel>{}
        : await _ratingRepository.getUserRatings(offBoardUids, sportId);
    if (stale()) return;

    final degree = _currentUser?.degreeProgram;
    final results = <LeaderboardSearchResult>[];
    for (final u in users) {
      final onBoard = indexByOwner[u.uid];
      if (onBoard != null) {
        results.add(
          LeaderboardSearchResult(
            user: u,
            rating: state.entries[onBoard],
            rank: onBoard + 1,
          ),
        );
        continue;
      }
      // Off the loaded board. Players with no position on the current board —
      // non-friends, other courses, or no rating for the sport — are omitted
      // entirely rather than shown as "unranked".
      final rating = offBoardRatings[u.uid];
      final inScope =
          scope == LeaderboardScope.global ||
          (degree != null && u.degreeProgram == degree);
      if (rating == null || !inScope) continue;
      // Exact rank for a deep (below top-100) player. Best-effort: if the count
      // aggregation is unavailable, drop the player rather than failing the
      // whole search.
      int? rank;
      try {
        rank = await _ratingRepository.getUserRank(
          sportId: sportId,
          elo: rating.elo,
          degreeProgram: scope == LeaderboardScope.myCourse ? degree : null,
        );
      } catch (_) {
        rank = null;
      }
      if (stale()) return;
      if (rank == null) continue;
      results.add(LeaderboardSearchResult(user: u, rating: rating, rank: rank));
    }

    if (stale()) return;
    emit(
      state.copyWith(
        searchResults: results,
        searchStatus: LeaderboardSearchStatus.done,
      ),
    );
  }

  void _onError(Object error, StackTrace stackTrace) {
    emit(state.copyWith(status: LeaderboardStatus.error));
  }

  /// Rebuilds the board after an error.
  void retry() {
    _boardSub?.cancel();
    emit(state.copyWith(status: LeaderboardStatus.loading, entries: const []));
    _subscribe();
    if (!_currentUserLoaded) _loadCurrentUser();
    _refreshCurrentUserRank();
  }

  @override
  Future<void> close() {
    _boardSub?.cancel();
    _searchTimer?.cancel();
    return super.close();
  }
}
