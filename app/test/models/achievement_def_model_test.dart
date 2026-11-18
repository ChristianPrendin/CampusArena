import 'package:campus_arena/models/achievement_def_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AchievementDefModel', () {
    final rawMap = {
      'nameKey': 'achievement_streak_5_name',
      'descriptionKey': 'achievement_streak_5_desc',
      'iconAsset': 'assets/badges/streak_5.png',
      'condition': 'win_streak',
      'threshold': 5,
    };

    test('parses fromMap with the doc id as achievementId', () {
      final def = AchievementDefModel.fromMap(rawMap, 'streak_5');

      expect(def.achievementId, 'streak_5');
      expect(def.nameKey, 'achievement_streak_5_name');
      expect(def.descriptionKey, 'achievement_streak_5_desc');
      expect(def.iconAsset, 'assets/badges/streak_5.png');
      expect(def.condition, 'win_streak');
      expect(def.threshold, 5);
    });

    test('parses a null threshold (boolean condition)', () {
      final def = AchievementDefModel.fromMap({
        ...rawMap,
        'threshold': null,
        'condition': 'first_victory',
      }, 'first_victory');

      expect(def.threshold, isNull);
      expect(def.condition, 'first_victory');
    });

    test('falls back to defaults on an empty map', () {
      final def = AchievementDefModel.fromMap(const {}, 'x');

      expect(def.achievementId, 'x');
      expect(def.nameKey, '');
      expect(def.descriptionKey, '');
      expect(def.iconAsset, '');
      expect(def.condition, '');
      expect(def.threshold, isNull);
    });

    test('serializes toMap without the doc id', () {
      const def = AchievementDefModel(
        achievementId: 'streak_5',
        nameKey: 'achievement_streak_5_name',
        descriptionKey: 'achievement_streak_5_desc',
        iconAsset: 'assets/badges/streak_5.png',
        condition: 'win_streak',
        threshold: 5,
      );

      final map = def.toMap();

      expect(map, {
        'nameKey': 'achievement_streak_5_name',
        'descriptionKey': 'achievement_streak_5_desc',
        'iconAsset': 'assets/badges/streak_5.png',
        'condition': 'win_streak',
        'threshold': 5,
      });
      expect(map.containsKey('achievementId'), isFalse);
    });

    test('coerces a numeric threshold to int', () {
      final def = AchievementDefModel.fromMap({
        ...rawMap,
        'threshold': 200.0,
      }, 'giant_slayer');

      expect(def.threshold, 200);
    });
  });
}
