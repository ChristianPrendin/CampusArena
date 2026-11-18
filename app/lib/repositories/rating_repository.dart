import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/elo/elo_calculator.dart';
import '../models/rating_model.dart';

/// Owns the entire `ratings` collection — both `user`- and `pair`-owned
/// entities. A dedicated top-level collection keeps the leaderboard a single
/// indexed query, minimising Firestore reads. Absorbs what the task board
/// called `PairRepository`.
class RatingRepository {
  RatingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreCollections.ratings);

  /// Deterministic doc ID: `{sportId}_{ownerId}`.
  static String ratingId(String sportId, String ownerId) =>
      '${sportId}_$ownerId';

  /// Deterministic pair identity from member UIDs (sorted, underscore-joined),
  /// so the same two players always resolve to one rated entity. Delegates to
  /// the canonical pure function in `core/elo/elo_calculator.dart`.
  static String pairId(List<String> memberUids) => pairIdFromUids(memberUids);

  /// Seeds one `user`-owned rating per [SportIds.supported] at registration,
  /// in a single batch. `degreeProgram` is denormalised here for the
  /// course-rivalry leaderboard query.
  Future<void> seedUserRatings({
    required String uid,
    required String degreeProgram,
    DateTime? now,
  }) {
    final batch = _firestore.batch();
    final timestamp = now ?? DateTime.now();
    for (final sportId in SportIds.supported) {
      final id = ratingId(sportId, uid);
      final rating = RatingModel(
        ratingId: id,
        ownerType: OwnerType.user,
        ownerId: uid,
        sportId: sportId,
        degreeProgram: degreeProgram,
        elo: kInitialElo,
        matchesPlayed: 0,
        lastMatchAt: timestamp,
      );
      batch.set(_col.doc(id), rating.toMap());
    }
    return batch.commit();
  }

  Future<RatingModel?> getRating(String ratingId) async {
    final snap = await _col.doc(ratingId).get();
    final data = snap.data();
    if (data == null) return null;
    return RatingModel.fromMap(data, snap.id);
  }

  Future<RatingModel?> getUserRating(String uid, String sportId) =>
      getRating(ratingId(sportId, uid));

  /// Batched user ratings for one sport, keyed by uid. The rating doc ids are
  /// deterministic ([ratingId]), so this fetches them by document id via
  /// `whereIn` instead of one round-trip per uid — Firestore caps `whereIn` at
  /// 30 values, so ids are queried in chunks of 30. Missing ratings are simply
  /// absent from the map. Empty [uids] issues no read.
  Future<Map<String, RatingModel>> getUserRatings(
    List<String> uids,
    String sportId,
  ) async {
    if (uids.isEmpty) return const {};
    final idToUid = {for (final u in uids) ratingId(sportId, u): u};
    final ids = idToUid.keys.toList();
    final result = <String, RatingModel>{};
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _col.where(FieldPath.documentId, whereIn: chunk).get();
      for (final d in snap.docs) {
        final uid = idToUid[d.id];
        if (uid != null) result[uid] = RatingModel.fromMap(d.data(), d.id);
      }
    }
    return result;
  }

  /// Campus rank for a sport: 1 + the number of `user`-owned ratings with a
  /// strictly higher ELO, so tied players share the best rank (competition
  /// ranking). One `count()` aggregation, served by the existing
  /// `(sportId, ownerType, elo)` composite index.
  ///
  /// Passing [degreeProgram] narrows the population to that course (the
  /// course-rivalry scope), which needs the
  /// `(sportId, ownerType, degreeProgram, elo)` composite index.
  Future<int> getUserRank({
    required String sportId,
    required int elo,
    String? degreeProgram,
  }) async {
    Query<Map<String, dynamic>> query = _col
        .where('sportId', isEqualTo: sportId)
        .where('ownerType', isEqualTo: OwnerType.user)
        .where('elo', isGreaterThan: elo);
    if (degreeProgram != null) {
      query = query.where('degreeProgram', isEqualTo: degreeProgram);
    }
    final snap = await query.count().get();
    return 1 + (snap.count ?? 0);
  }

  /// All `user`-owned ratings for a uid — drives the profile's per-sport ELO.
  Stream<List<RatingModel>> watchUserRatings(String uid) {
    return _col
        .where('ownerId', isEqualTo: uid)
        .where('ownerType', isEqualTo: OwnerType.user)
        .snapshots()
        .map(
          (q) =>
              q.docs.map((d) => RatingModel.fromMap(d.data(), d.id)).toList(),
        );
  }

  /// All ratings for one pair (its per-sport team ELO) — drives the team
  /// profile. Keyed on the deterministic [pairId], which is unique to the two
  /// members, so the single-field `ownerId` equality needs no composite index.
  Stream<List<RatingModel>> watchPairRatings(String pairId) {
    return _col
        .where('ownerId', isEqualTo: pairId)
        .snapshots()
        .map(
          (q) =>
              q.docs.map((d) => RatingModel.fromMap(d.data(), d.id)).toList(),
        );
  }

  /// Resolves the shared rating for a doubles pair, creating it at
  /// [kInitialElo] on first use. Transactional so concurrent first-match
  /// resolutions can't clobber each other (and asserts connectivity).
  Future<RatingModel> getOrCreatePairRating({
    required String sportId,
    required List<String> memberUids,
  }) {
    final members = [...memberUids]..sort();
    final id = ratingId(sportId, pairId(members));
    final ref = _col.doc(id);
    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data != null) return RatingModel.fromMap(data, snap.id);
      final rating = RatingModel(
        ratingId: id,
        ownerType: OwnerType.pair,
        ownerId: pairId(members),
        memberUids: members,
        sportId: sportId,
        elo: kInitialElo,
        matchesPlayed: 0,
        lastMatchAt: DateTime.now(),
      );
      tx.set(ref, rating.toMap());
      return rating;
    });
  }

  /// Applies a computed ELO update. The caller (ELO engine, Phase 4) owns the
  /// arithmetic; this only persists the result.
  Future<void> updateElo({
    required String ratingId,
    required int elo,
    required int matchesPlayed,
    required DateTime lastMatchAt,
  }) {
    return _col.doc(ratingId).update({
      'elo': elo,
      'matchesPlayed': matchesPlayed,
      'lastMatchAt': Timestamp.fromDate(lastMatchAt),
    });
  }

  /// Top-[limit] singles leaderboard for a sport, optionally filtered to a
  /// degree program (course rivalry). Single composite-indexed query.
  Stream<List<RatingModel>> watchLeaderboard({
    required String sportId,
    String ownerType = OwnerType.user,
    String? degreeProgram,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query = _col
        .where('sportId', isEqualTo: sportId)
        .where('ownerType', isEqualTo: ownerType);
    if (degreeProgram != null) {
      query = query.where('degreeProgram', isEqualTo: degreeProgram);
    }
    query = query.orderBy('elo', descending: true).limit(limit);
    return query.snapshots().map(
      (q) => q.docs.map((d) => RatingModel.fromMap(d.data(), d.id)).toList(),
    );
  }

  /// Leaderboard filtered to just the current user and their friends.
  /// Bypasses the Firestore `whereIn` 30-item limit by fetching docs directly
  /// and sorting client-side, since friend lists are capped/small anyway.
  Future<List<RatingModel>> getFriendsLeaderboard({
    required String sportId,
    required List<String> userAndFriendUids,
  }) async {
    if (userAndFriendUids.isEmpty) return [];

    // Batch fetch all rating docs for the provided UIDs
    final futures = userAndFriendUids.map((uid) => getUserRating(uid, sportId));
    final ratings = await Future.wait(futures);

    // Filter out nulls (friends who haven't played this sport yet, though they
    // should be seeded) and sort by ELO descending.
    final validRatings = ratings.whereType<RatingModel>().toList();
    validRatings.sort((a, b) => b.elo.compareTo(a.elo));
    return validRatings;
  }
}
