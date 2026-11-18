import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/user_model.dart';
import '../../../repositories/user_repository.dart';
import 'friends_state.dart';

/// Owns the signed-in user's friends list.
///
/// Streams `users/{uid}` for the authoritative `friendUids`, resolves each to a
/// [UserModel] (cached `uid → UserModel`, so re-emits don't refetch unchanged
/// friends), and exposes username search + add / remove actions. All writes are
/// single-doc `arrayUnion`/`arrayRemove` on `friendUids`, so no transaction is
/// needed; the list re-emits from the same stream once Firestore acks.
class FriendsCubit extends Cubit<FriendsState> {
  FriendsCubit({required this.uid, UserRepository? userRepository})
    : _userRepository = userRepository ?? UserRepository(),
      super(const FriendsState()) {
    _subscription = _userRepository
        .watchUser(uid)
        .listen(
          _onUserChanged,
          onError: (_) => emit(state.copyWith(status: FriendsStatus.error)),
        );
  }

  final String uid;
  final UserRepository _userRepository;
  late final StreamSubscription<UserModel?> _subscription;

  /// Matches the leaderboard search bar's debounce so both feel identical.
  static const Duration _searchDebounce = Duration(milliseconds: 300);
  Timer? _searchTimer;

  /// Cache of resolved friend profiles, so a `friendUids` change only fetches
  /// the newly-added handles.
  final Map<String, UserModel> _cache = {};

  /// The current `friendUids`, kept for the duplicate-add guard.
  List<String> _friendUids = const [];

  /// Bumped on every stream emission. `_onUserChanged` awaits profile fetches,
  /// so two emissions can overlap; the awaited continuation only commits if it
  /// is still the latest generation, so a stale list never overwrites a fresher
  /// one (whichever is newest wins, not whichever resolves last).
  int _generation = 0;

  Future<void> _onUserChanged(UserModel? user) async {
    final generation = ++_generation;
    if (user == null) {
      _friendUids = const [];
      emit(state.copyWith(status: FriendsStatus.ready, friends: const []));
      return;
    }
    _friendUids = user.friendUids;

    // Batch-resolve only the newly-added handles in a single query (the cache
    // holds the rest). A friend that fails to resolve is dropped from the list,
    // not surfaced as an error — the rest of the screen still renders.
    final missing = [
      for (final friendUid in user.friendUids)
        if (!_cache.containsKey(friendUid)) friendUid,
    ];
    if (missing.isNotEmpty) {
      try {
        for (final friend in await _userRepository.getUsersByIds(missing)) {
          _cache[friend.uid] = friend;
        }
      } catch (_) {
        // Isolated: unresolved friends are simply omitted below.
      }
    }

    // A newer emission arrived while we were fetching: abandon this one.
    if (generation != _generation) return;

    final friends = [
      for (final friendUid in user.friendUids)
        if (_cache[friendUid] != null) _cache[friendUid]!,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    emit(
      state.copyWith(
        status: FriendsStatus.ready,
        friends: friends,
        friendUids: user.friendUids,
      ),
    );
  }

  /// Debounced username-prefix search proposing players to add. An empty query
  /// clears the overlay back to the friends list. Case-insensitive (usernames
  /// are lowercase-only), so a lowercased prefix matches every case variant the
  /// caller might type; each match is added via [addFriend].
  void search(String query) {
    emit(state.copyWith(searchQuery: query));
    _searchTimer?.cancel();
    if (query.trim().isEmpty) {
      emit(
        state.copyWith(
          searchStatus: FriendSearchStatus.idle,
          searchResults: const [],
        ),
      );
      return;
    }
    emit(state.copyWith(searchStatus: FriendSearchStatus.searching));
    _searchTimer = Timer(_searchDebounce, () async {
      try {
        final results = await _userRepository.searchUsers(query.trim());
        if (isClosed || query != state.searchQuery) return;
        emit(
          state.copyWith(
            searchStatus: FriendSearchStatus.done,
            searchResults: results,
          ),
        );
      } catch (_) {
        if (isClosed || query != state.searchQuery) return;
        emit(state.copyWith(searchStatus: FriendSearchStatus.failed));
      }
    });
  }

  /// Adds [candidate] (chosen from the search results). Adding yourself or an
  /// existing friend is a guarded no-op — the UI already renders those rows
  /// without an active Add button, so this just backstops a stale tap. The
  /// friends list itself re-emits from the watchUser stream.
  Future<void> addFriend(UserModel candidate) async {
    if (candidate.uid == uid || _friendUids.contains(candidate.uid)) return;
    try {
      await _userRepository.addFriend(uid, candidate.uid);
    } catch (_) {
      emit(
        state.copyWith(
          addStatus: FriendAddStatus.failed,
          addTick: state.addTick + 1,
        ),
      );
      return;
    }
    // Seed the profile cache only after the write succeeds, so a failed add
    // never leaves a phantom entry.
    _cache[candidate.uid] = candidate;
    emit(
      state.copyWith(
        addStatus: FriendAddStatus.added,
        addedUsername: candidate.username,
        addTick: state.addTick + 1,
      ),
    );
  }

  /// Removes [friendUid] from the friends list. The stream re-emits the
  /// shortened list once Firestore acks.
  Future<void> removeFriend(String friendUid) {
    return _userRepository.removeFriend(uid, friendUid);
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    _subscription.cancel();
    return super.close();
  }
}
