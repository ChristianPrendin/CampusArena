import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/facility_model.dart';

/// Reads facilities and writes the denormalised `status` / `currentMatchId`
/// the map listener renders. The match flow is the canonical writer of those
/// two fields (see the facility-status shared contract).
class FacilityRepository {
  FacilityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Spark-tier bound: the campus has a fixed, small set of tables, so cap the
  /// live listener; a runaway collection can never blow the read quota.
  static const int maxFacilities = 50;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreCollections.facilities);

  Stream<List<FacilityModel>> watchFacilities() {
    return _col
        .limit(maxFacilities)
        .snapshots()
        .map(
          (q) =>
              q.docs.map((d) => FacilityModel.fromMap(d.data(), d.id)).toList(),
        );
  }

  Stream<FacilityModel?> watchFacility(String facilityId) {
    return _col.doc(facilityId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return FacilityModel.fromMap(data, snap.id);
    });
  }

  Future<FacilityModel?> getFacility(String facilityId) async {
    final snap = await _col.doc(facilityId).get();
    final data = snap.data();
    if (data == null) return null;
    return FacilityModel.fromMap(data, snap.id);
  }

  /// One-shot (non-listening) read of facilities matching [status], bounded by
  /// [limit]. Used by the chatbot tool layer, which must never hold a
  /// snapshot listener open. Kept alongside [watchFacilities] rather than
  /// replacing it since the map screen still needs live updates.
  Future<List<FacilityModel>> getFacilitiesByStatus(
    String status, {
    int limit = 25,
  }) async {
    final query = await _col
        .where('status', isEqualTo: status)
        .limit(limit)
        .get();
    return query.docs
        .map((d) => FacilityModel.fromMap(d.data(), d.id))
        .toList();
  }

  /// Denormalised status flip. `currentMatchId` is cleared (null) when freeing.
  Future<void> updateStatus({
    required String facilityId,
    required String status,
    String? currentMatchId,
  }) {
    return _col.doc(facilityId).update({
      'status': status,
      'currentMatchId': currentMatchId,
    });
  }
}
