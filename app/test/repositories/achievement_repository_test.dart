import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/repositories/achievement_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AchievementRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = AchievementRepository(firestore: firestore);
  });

  Future<void> seedDef(String id, String condition, int? threshold) {
    return firestore
        .collection(FirestoreCollections.achievementDefs)
        .doc(id)
        .set({
          'nameKey': 'achievement_${id}_name',
          'descriptionKey': 'achievement_${id}_desc',
          'iconAsset': 'assets/badges/$id.png',
          'condition': condition,
          'threshold': threshold,
        });
  }

  test('getDefinitions reads every seeded definition', () async {
    await seedDef('first_victory', 'first_victory', null);
    await seedDef('streak_5', 'win_streak', 5);
    await seedDef('workaholic', 'monthly_count', 15);

    final defs = await repository.getDefinitions();

    expect(defs.map((d) => d.achievementId).toSet(), {
      'first_victory',
      'streak_5',
      'workaholic',
    });
    final workaholic = defs.firstWhere((d) => d.achievementId == 'workaholic');
    expect(workaholic.condition, 'monthly_count');
    expect(workaholic.threshold, 15);
    expect(workaholic.iconAsset, 'assets/badges/workaholic.png');
  });

  test('getDefinitions returns empty when nothing is seeded', () async {
    expect(await repository.getDefinitions(), isEmpty);
  });

  test('watchDefinitions emits the current set', () async {
    await seedDef('explorer', 'explorer', null);

    final defs = await repository.watchDefinitions().first;

    expect(defs.single.achievementId, 'explorer');
    expect(defs.single.threshold, isNull);
  });
}
