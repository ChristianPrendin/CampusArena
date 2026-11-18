import 'package:equatable/equatable.dart';

/// Read-only definition of one achievement badge (`achievementDefs/{id}`).
///
/// The doc id *is* the [achievementId]; the five stored fields are the locked
/// schema (`brain/firestore_schema.md` → achievementDefs). Deliberately free of
/// `cloud_firestore` — every field is a plain string or num — so the pure
/// [AchievementEvaluator] can consume it without pulling in Firestore.
class AchievementDefModel extends Equatable {
  const AchievementDefModel({
    required this.achievementId,
    required this.nameKey,
    required this.descriptionKey,
    required this.iconAsset,
    required this.condition,
    this.threshold,
  });

  /// Doc id, e.g. `first_victory`, `streak_5`, `workaholic`.
  final String achievementId;

  /// ARB localization key for the badge name.
  final String nameKey;

  /// ARB localization key for the description.
  final String descriptionKey;

  /// Asset path for the badge PNG, e.g. `assets/badges/first_victory.png`.
  final String iconAsset;

  /// Evaluation rule identifier the client evaluator branches on, e.g.
  /// `win_streak`, `giant_slayer`, `monthly_count`.
  final String condition;

  /// Numeric threshold for the condition (e.g. `5` streak, `200` ELO gap,
  /// `15` monthly). Null when the condition is boolean (`first_victory`).
  final int? threshold;

  Map<String, dynamic> toMap() {
    return {
      'nameKey': nameKey,
      'descriptionKey': descriptionKey,
      'iconAsset': iconAsset,
      'condition': condition,
      'threshold': threshold,
    };
  }

  factory AchievementDefModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return AchievementDefModel(
      achievementId: documentId,
      nameKey: map['nameKey'] as String? ?? '',
      descriptionKey: map['descriptionKey'] as String? ?? '',
      iconAsset: map['iconAsset'] as String? ?? '',
      condition: map['condition'] as String? ?? '',
      threshold: (map['threshold'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [
    achievementId,
    nameKey,
    descriptionKey,
    iconAsset,
    condition,
    threshold,
  ];
}
