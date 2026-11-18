import 'package:equatable/equatable.dart';

import '../../../models/user_model.dart';

/// Lifecycle of the friends-list stream.
enum FriendsStatus { loading, ready, error }

/// Lifecycle of the add-friend username search overlay.
enum FriendSearchStatus {
  /// No active query — the friends list is shown instead of results.
  idle,
  searching,
  done,

  /// The search query itself failed (offline / permission).
  failed,
}

/// Outcome of the most recent per-row add tap (transient; drives a snackbar).
enum FriendAddStatus { idle, added, failed }

class FriendsState extends Equatable {
  const FriendsState({
    this.status = FriendsStatus.loading,
    this.friends = const [],
    this.friendUids = const [],
    this.searchQuery = '',
    this.searchStatus = FriendSearchStatus.idle,
    this.searchResults = const [],
    this.addStatus = FriendAddStatus.idle,
    this.addedUsername,
    this.addTick = 0,
  });

  /// Loading / ready / error for the friends list itself.
  final FriendsStatus status;

  /// Resolved friend profiles, ordered by display name. A friend whose
  /// document fails to resolve is silently omitted rather than erroring the
  /// whole screen (decorative lookups stay isolated).
  final List<UserModel> friends;

  /// Authoritative `friendUids`, so a search-result row can render its
  /// already-a-friend state without re-resolving the profile list.
  final List<String> friendUids;

  /// The raw text in the search field (drives the empty-state copy).
  final String searchQuery;

  /// Lifecycle of the add-friend search.
  final FriendSearchStatus searchStatus;

  /// Candidate players matching [searchQuery] (username prefix, case-
  /// insensitive). Shown with a per-row Add button.
  final List<UserModel> searchResults;

  /// Result of the last add tap (transient; drives a snackbar).
  final FriendAddStatus addStatus;

  /// The handle just added, for the success snackbar copy.
  final String? addedUsername;

  /// Monotonic counter bumped on every add outcome. Because [addStatus] latches
  /// (a second `added` in a row is not a state change), the snackbar listener
  /// keys on this instead, so each add fires exactly once.
  final int addTick;

  /// Whether [uid] is already in the signed-in user's friends.
  bool isFriend(String uid) => friendUids.contains(uid);

  FriendsState copyWith({
    FriendsStatus? status,
    List<UserModel>? friends,
    List<String>? friendUids,
    String? searchQuery,
    FriendSearchStatus? searchStatus,
    List<UserModel>? searchResults,
    FriendAddStatus? addStatus,
    String? addedUsername,
    int? addTick,
  }) {
    return FriendsState(
      status: status ?? this.status,
      friends: friends ?? this.friends,
      friendUids: friendUids ?? this.friendUids,
      searchQuery: searchQuery ?? this.searchQuery,
      searchStatus: searchStatus ?? this.searchStatus,
      searchResults: searchResults ?? this.searchResults,
      addStatus: addStatus ?? this.addStatus,
      addedUsername: addedUsername ?? this.addedUsername,
      addTick: addTick ?? this.addTick,
    );
  }

  @override
  List<Object?> get props => [
    status,
    friends,
    friendUids,
    searchQuery,
    searchStatus,
    searchResults,
    addStatus,
    addedUsername,
    addTick,
  ];
}
