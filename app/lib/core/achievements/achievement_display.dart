import '../../l10n/app_localizations.dart';
import 'achievement_evaluator.dart';

/// Localized badge name for an achievement id. Mirrors [localizedSportName]:
/// a switch over the fixed, seeded id set, falling back to the raw id. Keeps
/// the ARB keys (`achievement_<id>_name`) resolved in one place for both the
/// profile grid and the unlock reveal.
String localizedAchievementName(AppLocalizations l10n, String achievementId) {
  switch (achievementId) {
    case AchievementIds.firstVictory:
      return l10n.achievement_first_victory_name;
    case AchievementIds.streak5:
      return l10n.achievement_streak_5_name;
    case AchievementIds.giantSlayer:
      return l10n.achievement_giant_slayer_name;
    case AchievementIds.explorer:
      return l10n.achievement_explorer_name;
    case AchievementIds.tournamentChampion:
      return l10n.achievement_tournament_champion_name;
    case AchievementIds.workaholic:
      return l10n.achievement_workaholic_name;
    default:
      return achievementId;
  }
}

/// Localized badge description for an achievement id.
String localizedAchievementDescription(
  AppLocalizations l10n,
  String achievementId,
) {
  switch (achievementId) {
    case AchievementIds.firstVictory:
      return l10n.achievement_first_victory_desc;
    case AchievementIds.streak5:
      return l10n.achievement_streak_5_desc;
    case AchievementIds.giantSlayer:
      return l10n.achievement_giant_slayer_desc;
    case AchievementIds.explorer:
      return l10n.achievement_explorer_desc;
    case AchievementIds.tournamentChampion:
      return l10n.achievement_tournament_champion_desc;
    case AchievementIds.workaholic:
      return l10n.achievement_workaholic_desc;
    default:
      return '';
  }
}
