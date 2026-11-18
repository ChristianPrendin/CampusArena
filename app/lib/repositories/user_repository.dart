import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/user_model.dart';

/// Thrown by [UserRepository.createUser] when the requested `username` is
/// already claimed. Carries the offending [username] for the UI to echo back.
class UsernameTakenException implements Exception {
  const UsernameTakenException(this.username);

  final String username;

  @override
  String toString() => 'UsernameTakenException($username)';
}

/// CRUD on `users/{uid}`.
///
/// Per-sport rating seeding at registration is owned by `RatingRepository`;
/// the registration flow calls both. Keeping the two collections behind
/// separate repositories preserves the schema's single-source-of-truth split.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> get _usernames =>
      _firestore.collection(FirestoreCollections.usernames);

  /// Creates the `users/{uid}` doc and atomically claims the handle in
  /// `usernames/{handle}` (doc id = the lowercased, trimmed handle). If the
  /// handle is already claimed the transaction throws [UsernameTakenException]
  /// and neither doc is written.
  ///
  /// Usernames are lowercase-only, so uniqueness is case-insensitive and the
  /// canonical stored `username` is the lowercased handle too — this is the
  /// single enforcement point for that invariant (`searchUsers` orders on
  /// `username` directly, no mirror field).
  ///
  /// This reservation-doc-as-lock is the schema's deterministic-ID idiom
  /// (`ratingId`, `pairId`, queue doc id) and the only way to enforce username
  /// uniqueness on the Spark tier, where there are no Cloud Functions: two
  /// concurrent claims collide on Firestore's optimistic retry, and the
  /// security rule forbids ever overwriting a claim.
  Future<void> createUser(UserModel user) {
    final handle = user.username.trim().toLowerCase();
    final usernameRef = _usernames.doc(handle);
    final userRef = _col.doc(user.uid);
    return _firestore.runTransaction((tx) async {
      final claim = await tx.get(usernameRef);
      if (claim.exists) throw UsernameTakenException(handle);
      tx.set(usernameRef, {'uid': user.uid});
      tx.set(userRef, {...user.toMap(), 'username': handle});
    });
  }

  Future<UserModel?> getUser(String uid) async {
    final snap = await _col.doc(uid).get();
    final data = snap.data();
    if (data == null) return null;
    return UserModel.fromMap(data, snap.id);
  }

  /// Batch-loads users by id in a single (chunked) query rather than one read
  /// per uid — used to resolve leaderboard display names. Firestore caps a
  /// `whereIn` at 30 values, so ids are fetched in chunks of 30. Missing ids
  /// are simply absent from the result; order is not guaranteed.
  Future<List<UserModel>> getUsersByIds(List<String> uids) async {
    final unique = uids.toSet().toList();
    if (unique.isEmpty) return const [];
    const chunkSize = 30;
    final results = <UserModel>[];
    for (var i = 0; i < unique.length; i += chunkSize) {
      final end = i + chunkSize < unique.length ? i + chunkSize : unique.length;
      final chunk = unique.sublist(i, end);
      final snap = await _col.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)));
    }
    return results;
  }

  Stream<UserModel?> watchUser(String uid) {
    return _col.doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return UserModel.fromMap(data, snap.id);
    });
  }

  /// Partial update (e.g. `onboardingComplete`, `pushTokens`, `friendUids`).
  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _col.doc(uid).update(data);
  }

  /// Bounded prefix search over the `username` handle, backing both the
  /// leaderboard player-search bar and the add-friend search. A blank query
  /// returns no results rather than scanning the collection. The `[q, q + )`
  /// range is Firestore's standard prefix trick: it brackets every username
  /// starting with [query].
  ///
  /// Case-insensitive by construction: usernames are lowercase-only (enforced in
  /// [createUser]), so ordering on `username` with a lowercased prefix matches
  /// every case variant of the query. Always `.limit()`ed for the Spark tier.
  Future<List<UserModel>> searchUsers(String query, {int limit = 25}) async {
    final prefix = query.trim().toLowerCase();
    if (prefix.isEmpty) return const [];
    final snap = await _col
        .orderBy('username')
        .startAt([prefix])
        .endAt(['$prefix\u{F8FF}'])
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data(), d.id))
        .toList(growable: false);
  }

  /// Adds [friendUid] to [uid]'s `friendUids`. Single-doc `arrayUnion`, so
  /// re-adding an existing friend is a harmless no-op — no transaction needed.
  Future<void> addFriend(String uid, String friendUid) {
    return _col.doc(uid).update({
      'friendUids': FieldValue.arrayUnion([friendUid]),
    });
  }

  /// Removes [friendUid] from [uid]'s `friendUids` (single-doc `arrayRemove`).
  Future<void> removeFriend(String uid, String friendUid) {
    return _col.doc(uid).update({
      'friendUids': FieldValue.arrayRemove([friendUid]),
    });
  }

  /// Registers this device's FCM [token] under [uid]'s `pushTokens`
  /// (`arrayUnion`, idempotent). Backs the Settings notification toggle: the
  /// locked schema has no notification-preference field, so opting in is
  /// simply this token's membership in the set.
  Future<void> addPushToken(String uid, String token) {
    return _col.doc(uid).update({
      'pushTokens': FieldValue.arrayUnion([token]),
    });
  }

  /// Deregisters this device's FCM [token] from [uid]'s `pushTokens`
  /// (`arrayRemove`) — the notification toggle's opt-out.
  Future<void> removePushToken(String uid, String token) {
    return _col.doc(uid).update({
      'pushTokens': FieldValue.arrayRemove([token]),
    });
  }
}
