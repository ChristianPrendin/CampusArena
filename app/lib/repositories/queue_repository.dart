import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/facility_model.dart';

/// Owns `facilities/{facilityId}/queue/{uid}`.
///
/// A join runs in a transaction so `position` is assigned atomically and the
/// write asserts connectivity. `position` is a **monotonic ticket number** and
/// `queueTailPosition` the highest ticket issued — a counter, never rewritten
/// to a live length. Display rank is derived from the *ordered snapshot index*
/// by the queue/match cubits (`mineIndex + 1`), so a leave is a plain delete
/// and stored positions never need re-densifying. The queue-position field is
/// the queue vertical's half of the check-in shared contract.
class QueueRepository {
  QueueRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _queue(String facilityId) {
    return _firestore
        .collection(FirestoreCollections.facilities)
        .doc(facilityId)
        .collection(FirestoreCollections.queue);
  }

  /// Appends [uid] to the tail of the queue and returns the assigned position
  /// (1-based). Idempotent: re-joining returns the existing position.
  Future<int> joinQueue({required String facilityId, required String uid}) {
    final col = _queue(facilityId);
    return _firestore.runTransaction((tx) async {
      final existing = await tx.get(col.doc(uid));
      final existingData = existing.data();
      if (existingData != null) {
        return (existingData['position'] as num).toInt();
      }

      final facilityRef = _firestore
          .collection(FirestoreCollections.facilities)
          .doc(facilityId);
      final facilitySnap = await tx.get(facilityRef);
      final facilityData = facilitySnap.data();
      final currentTail =
          (facilityData?['queueTailPosition'] as num?)?.toInt() ?? 0;
      final nextPosition = currentTail + 1;

      final entry = QueueEntryModel(
        uid: uid,
        facilityId: facilityId,
        position: nextPosition,
        joinedAt: DateTime.now(),
      );

      tx.set(col.doc(uid), entry.toMap());

      final update = <String, dynamic>{'queueTailPosition': nextPosition};
      // Only stamp 'queued' when the facility is already in play. Never
      // overwrite a 'free' status: createMatch requires 'free' to start a
      // match (match_repository.dart), so flipping a free table to 'queued'
      // here would brick it — no match exists to expire, and leaveQueue's
      // revert only reaches 'occupied', which is equally unclaimable.
      final currentStatus = facilityData?['status'] as String?;
      if (currentStatus == FacilityStatus.occupied ||
          currentStatus == FacilityStatus.queued) {
        update['status'] = FacilityStatus.queued;
      }
      tx.update(facilityRef, update);
      return nextPosition;
    });
  }

  /// Removes [uid]'s ticket. Positions are monotonic, so this is a plain delete
  /// — no renumbering, and `queueTailPosition` is left untouched (rank is
  /// derived from the ordered snapshot index, not the stored value). When the
  /// last queued player leaves, the facility's `queued` marker reverts to
  /// `occupied` (the match is still live). No-op if not queued.
  Future<void> leaveQueue({
    required String facilityId,
    required String uid,
  }) async {
    final col = _queue(facilityId);
    final facilityRef = _firestore
        .collection(FirestoreCollections.facilities)
        .doc(facilityId);

    final removed = await _firestore.runTransaction<bool>((tx) async {
      final ticket = await tx.get(col.doc(uid));
      if (!ticket.exists) return false;
      tx.delete(col.doc(uid));
      return true;
    });
    if (!removed) return;

    // Emptiness check + status revert runs outside the delete transaction: a
    // client transaction can't run a query, so the now-empty check is a bounded
    // read after the delete. The window where a concurrent re-join races this
    // revert is accepted — it self-heals on the next queue write, and every
    // match-end path resets status to 'free' unconditionally.
    final remaining = await col.limit(1).get();
    if (remaining.docs.isNotEmpty) return;
    await _firestore.runTransaction((tx) async {
      final fSnap = await tx.get(facilityRef);
      if (fSnap.data()?['status'] == FacilityStatus.queued) {
        tx.update(facilityRef, {'status': FacilityStatus.occupied});
      }
    });
  }

  Stream<List<QueueEntryModel>> watchQueue(String facilityId) {
    return _queue(facilityId)
        .orderBy('position')
        .snapshots()
        .map(
          (q) => q.docs
              .map((d) => QueueEntryModel.fromMap(d.data(), d.id, facilityId))
              .toList(),
        );
  }

  Future<int?> getPosition({
    required String facilityId,
    required String uid,
  }) async {
    final snap = await _queue(facilityId).doc(uid).get();
    final data = snap.data();
    if (data == null) return null;
    return (data['position'] as num).toInt();
  }

  /// One-shot (non-listening) count of the queue at [facilityId], via a
  /// bounded `count()` aggregation query. Used by the chatbot tool layer,
  /// which must never hold a snapshot listener open — [watchQueue] stays for
  /// the live map/facility-detail UI.
  Future<int> getQueueLength(String facilityId) async {
    final result = await _queue(facilityId).count().get();
    return result.count ?? 0;
  }

  /// One-shot lookup of the queue entry for [uid] across all facilities.
  /// Backs the chatbot's "where am I in the queue?" tool without requiring
  /// the caller to already know the facility. Returns `null` if the user
  /// isn't queued anywhere.
  ///
  /// Implemented as a bounded facility scan with direct `queue/{uid}` doc
  /// reads (campus has a small, fixed set of facilities) rather than a
  /// `collectionGroup` query — that would require a collection-group index
  /// exemption for `userId`, and the direct reads stay comfortably inside
  /// Spark-tier quotas for a chatbot one-shot.
  Future<QueueEntryModel?> getUserQueueEntry(String uid) async {
    final facilities = await _firestore
        .collection(FirestoreCollections.facilities)
        .limit(30)
        .get();
    for (final facility in facilities.docs) {
      final entry = await _queue(facility.id).doc(uid).get();
      final data = entry.data();
      if (data != null) {
        return QueueEntryModel.fromMap(data, entry.id, facility.id);
      }
    }
    return null;
  }
}
