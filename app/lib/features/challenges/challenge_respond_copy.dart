import 'package:campus_arena/l10n/app_localizations.dart';

import '../../repositories/challenge_repository.dart';

/// Localized accept/decline failure copy for a [ChallengeRespondError] — shared
/// by the dashboard challenge section and the deep-link challenge screen so both
/// surface the same distinct messages (expired vs offline/transient vs a raced
/// no-longer-pending challenge) instead of one blanket "may have expired".
String challengeRespondErrorMessage(
  AppLocalizations l10n,
  ChallengeRespondError reason,
) {
  return switch (reason) {
    ChallengeRespondError.expired => l10n.challengeActionExpired,
    ChallengeRespondError.noLongerPending =>
      l10n.challengeActionNoLongerAvailable,
    ChallengeRespondError.unavailable => l10n.challengeActionUnavailable,
  };
}
