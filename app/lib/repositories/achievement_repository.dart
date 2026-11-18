import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/achievement_def_model.dart';

/// Reads the read-only `achievementDefs` reference collection: the 6 seeded
/// badge definitions the client evaluates against and the profile grid renders.
/// Never writes — badge *state* lives in `users/{uid}.badges`, written by the
/// match-confirmation and tournament-completion transactions.
class AchievementRepository {
  AchievementRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Spark-tier bound: the definition set is tiny and fixed, so the read is
  /// capped — a runaway collection can never blow the quota.
  static const int maxDefinitions = 50;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreCollections.achievementDefs);

  /// One-shot bounded fetch of every badge definition. Used by the confirm path
  /// (achievement evaluation) and to hydrate the profile grid.
  Future<List<AchievementDefModel>> getDefinitions() async {
    final snap = await _col.limit(maxDefinitions).get();
    return snap.docs
        .map((d) => AchievementDefModel.fromMap(d.data(), d.id))
        .toList();
  }

  /// Live bounded view of the definitions, for the profile grid.
  Stream<List<AchievementDefModel>> watchDefinitions() {
    return _col
        .limit(maxDefinitions)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AchievementDefModel.fromMap(d.data(), d.id))
              .toList(),
        );
  }
}
