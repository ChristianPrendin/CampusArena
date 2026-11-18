// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CampusArena';

  @override
  String get playButtonLabel => 'Play';

  @override
  String get sportPingPong => 'Ping Pong';

  @override
  String get sportFoosball => 'Foosball';

  @override
  String get eloLabel => 'ELO';

  @override
  String get rankPlaceholder => '—';

  @override
  String matchesPlayedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches played',
      one: '1 match played',
      zero: 'No matches yet',
    );
    return '$_temp0';
  }

  @override
  String get recentMatchesTitle => 'Recent Matches';

  @override
  String get noRecentMatches =>
      'No matches yet — scan a facility QR code to play your first ranked match.';

  @override
  String vsOpponents(String opponents) {
    return 'vs $opponents';
  }

  @override
  String get matchWon => 'Won';

  @override
  String get matchLost => 'Lost';

  @override
  String get matchStateDisputed => 'Disputed';

  @override
  String get matchStateUnconfirmed => 'Unconfirmed';

  @override
  String get matchStateAbandoned => 'Abandoned';

  @override
  String get dashboardLoadError => 'Couldn\'t load your dashboard.';

  @override
  String get retryButtonLabel => 'Retry';

  @override
  String get eloRatingLabel => 'ELO Rating';

  @override
  String get assistantCardTitle => 'Arena Assistant';

  @override
  String get assistantCardSubtitle => 'Ask about free tables, queues & ELO';

  @override
  String get chatbotTitle => 'Arena Assistant';

  @override
  String get chatbotComingSoon => 'The Arena Assistant is coming soon.';

  @override
  String get homeTab => 'Home';

  @override
  String get mapTab => 'Map';

  @override
  String get leaderboardsTab => 'Leaderboards';

  @override
  String get profileTab => 'Profile';

  @override
  String get landingTagline =>
      'Track your ELO, climb the campus ranks, and rule ping pong & foosball at PoliMi.';

  @override
  String get splashTagline => 'Own the table.';

  @override
  String get logIn => 'Log In';

  @override
  String get register => 'Register';

  @override
  String get signIn => 'Sign In';

  @override
  String get createAccount => 'Create Account';

  @override
  String get completeProfileTitle => 'Complete your profile';

  @override
  String get completeProfileMessage =>
      'Your account doesn\'t have a profile yet. Pick a name and username to finish setting up.';

  @override
  String get completeProfileButton => 'Finish setup';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get togglePasswordVisibility => 'Toggle password visibility';

  @override
  String get nameLabel => 'Full Name';

  @override
  String get usernameLabel => 'Username';

  @override
  String get degreeProgramLabel => 'Degree Program';

  @override
  String get degreeProgramHint => 'Select your degree program';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get forgotPasswordTitle => 'Reset Password';

  @override
  String get forgotPasswordInstructions =>
      'Enter your email and we\'ll send you a link to reset your password.';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get passwordResetSent =>
      'If that email is registered, a reset link has been sent.';

  @override
  String get noAccountPromptPrefix => 'Don\'t have an account?';

  @override
  String get haveAccountPromptPrefix => 'Already have an account?';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get invalidEmail => 'Enter a valid email address';

  @override
  String get invalidUsername =>
      '3–20 lowercase letters, numbers or underscores';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get authErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get authErrorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get authErrorEmailInUse =>
      'An account with this email already exists.';

  @override
  String get authErrorInvalidEmail => 'That email address is invalid.';

  @override
  String get authErrorWeakPassword => 'Please choose a stronger password.';

  @override
  String get authErrorNetwork => 'Network error. Check your connection.';

  @override
  String get authErrorUsernameTaken => 'That username is already taken.';

  @override
  String get tutorialSkip => 'Skip';

  @override
  String get tutorialNext => 'Next';

  @override
  String get tutorialDone => 'Get Started';

  @override
  String get tutorialSlide1Title => 'Play Ranked Matches';

  @override
  String get tutorialSlide1Body =>
      'Scan a facility\'s QR code to check in and record your match.';

  @override
  String get tutorialSlide2Title => 'Climb the Leaderboards';

  @override
  String get tutorialSlide2Body =>
      'Every win updates your ELO. Compete across sports and degree programs.';

  @override
  String get tutorialSlide3Title => 'Join the Queue';

  @override
  String get tutorialSlide3Body =>
      'See live facility status on the map and reserve your spot in line.';

  @override
  String get degAerospace => 'Aerospace Engineering';

  @override
  String get degArchitecture => 'Architecture';

  @override
  String get degBiomedical => 'Biomedical Engineering';

  @override
  String get degChemical => 'Chemical Engineering';

  @override
  String get degCivil => 'Civil Engineering';

  @override
  String get degComputer => 'Computer Science and Engineering';

  @override
  String get degDesign => 'Design';

  @override
  String get degElectrical => 'Electrical Engineering';

  @override
  String get degElectronic => 'Electronic Engineering';

  @override
  String get degEnergy => 'Energy Engineering';

  @override
  String get degManagement => 'Management Engineering';

  @override
  String get degMathematical => 'Mathematical Engineering';

  @override
  String get degMechanical => 'Mechanical Engineering';

  @override
  String get degTelecom => 'Telecommunication Engineering';

  @override
  String get degUrban => 'Urban Planning';

  @override
  String get weatherLabel => 'Weather';

  @override
  String weatherTemperature(String value) {
    return '$value°';
  }

  @override
  String weatherPrecipitation(String value) {
    return '$value mm';
  }

  @override
  String weatherWind(String value) {
    return '$value km/h';
  }

  @override
  String get weatherUnavailable => 'Weather unavailable';

  @override
  String get weatherRetry => 'Retry';

  @override
  String get forecastLabel => 'Forecast';

  @override
  String get queueJoin => 'Join Queue';

  @override
  String get queueLeave => 'Leave queue';

  @override
  String get queueRetry => 'Retry';

  @override
  String queuePositionCounter(int position, int total) {
    return 'You\'re #$position of $total';
  }

  @override
  String get queueYoureNext => 'You\'re next';

  @override
  String get queueError => 'Couldn\'t update the queue. Check your connection.';

  @override
  String get queueTableReadyTitle => 'Your table is ready';

  @override
  String get queueTableReadyBody =>
      'You\'re first in line — head to the table now.';

  @override
  String get queueTableReadyDismiss => 'Dismiss';

  @override
  String get availabilityDisclaimerShort =>
      'Based on app activity only — the table may be in use by non-app players. Not a reservation.';

  @override
  String get availabilityDisclaimerFull =>
      'Availability shows CampusArena activity only. A table marked as empty may still be in use by people who aren\'t playing through the app. CampusArena is not a booking service — spots can\'t be reserved.';

  @override
  String get queuePriorityTitle => 'Someone is ahead of you';

  @override
  String queuePriorityBody(int position, int frontPosition) {
    return 'You\'re #$position in the queue and #$frontPosition is next in line. Please let them play first.';
  }

  @override
  String get queuePriorityProceed => 'Claim anyway';

  @override
  String get queuePriorityCancel => 'Wait my turn';

  @override
  String get chatbotIntroDisclaimer =>
      'Availability shows CampusArena activity only. A table marked as empty may still be in use by people who aren\'t playing through the app. CampusArena is not a booking service — spots can\'t be reserved.';

  @override
  String get mapAttribution => '© OpenStreetMap contributors';

  @override
  String get mapViewList => 'List';

  @override
  String get facilityListSortedByProximity => 'Sorted by proximity';

  @override
  String distanceMeters(int meters) {
    return '$meters m';
  }

  @override
  String distanceKilometers(double kilometers) {
    final intl.NumberFormat kilometersNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String kilometersString = kilometersNumberFormat.format(kilometers);

    return '$kilometersString km';
  }

  @override
  String get facilityStatusFree => 'Free';

  @override
  String get facilityStatusOccupied => 'Occupied';

  @override
  String get facilityStatusQueued => 'Queued';

  @override
  String get facilityOutdoorLabel => 'Outdoor';

  @override
  String get facilityPlayersLabel => 'Players';

  @override
  String get facilityMatchDurationLabel => 'Match duration';

  @override
  String facilityDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get facilityValuePlaceholder => '—';

  @override
  String get facilityKingOfTable => 'King of the Table';

  @override
  String facilityKingWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wins',
      one: '1 win',
    );
    return '$_temp0';
  }

  @override
  String get facilityNoKing => 'No King of the Table yet';

  @override
  String get facilityLoadError => 'Couldn\'t load facilities.';

  @override
  String get facilityListEmpty => 'No facilities on campus yet.';

  @override
  String get mapRecenterTooltip => 'Center on my location';

  @override
  String get locationUnavailable => 'Location unavailable.';

  @override
  String get qrScanTitle => 'Scan table QR';

  @override
  String get qrScanHint => 'Point your camera at the QR code on the table';

  @override
  String get qrEnterManually => 'Enter code manually';

  @override
  String get qrManualEntryTitle => 'Enter table code';

  @override
  String get qrManualEntryLabel => 'Table code';

  @override
  String get qrManualEntrySubmit => 'Check in';

  @override
  String get qrGpsWarning =>
      'You seem far from this table — check-in still allowed';

  @override
  String qrCheckInButton(String facility) {
    return 'Check in to $facility';
  }

  @override
  String get matchSetupTitle => 'Set up match';

  @override
  String matchSetupSubtitle(String facility) {
    return 'Choose the match type, then check in at $facility.';
  }

  @override
  String get matchModeLabel => 'Match type';

  @override
  String get matchModeSingles => 'Singles';

  @override
  String get matchModeDoubles => 'Doubles';

  @override
  String get matchTeamLabel => 'Your team';

  @override
  String get matchTeam1 => 'Team 1';

  @override
  String get matchTeam2 => 'Team 2';

  @override
  String get matchPickSideTitle => 'Pick your side';

  @override
  String get matchPickSideBody => 'Choose a team to join this doubles match.';

  @override
  String get matchSideFull => 'Full';

  @override
  String get matchWaitingPlayersBody =>
      'Ask the others to scan this table\'s QR and pick a side.';

  @override
  String get qrInvalidCode =>
      'That code doesn\'t match any table. Check it and try again.';

  @override
  String get qrCheckInError =>
      'Couldn\'t start the match. Check your connection and try again.';

  @override
  String get qrTableBusy =>
      'This table already has a match in progress. Wait for it to finish.';

  @override
  String qrSportMismatch(String sport) {
    return 'This table isn\'t for $sport. Scan a $sport table to play your challenge.';
  }

  @override
  String get leaveMatchTitle => 'Leave match?';

  @override
  String get leaveMatchMessage =>
      'Leaving now abandons this match for both players and frees the table.';

  @override
  String get leaveMatchConfirm => 'Leave';

  @override
  String get leaveMatchCancel => 'Stay';

  @override
  String get matchLiveBadge => 'Live';

  @override
  String get matchVs => 'VS';

  @override
  String get matchRecordResult => 'Record result';

  @override
  String matchEloValue(int elo) {
    return '$elo ELO';
  }

  @override
  String get matchWaitingOpponentTitle => 'Waiting for opponent';

  @override
  String get matchWaitingOpponentBody =>
      'Ask your opponent to scan this table\'s QR to join.';

  @override
  String get matchResultSubmittedStatus =>
      'Result submitted — waiting for confirmation';

  @override
  String get matchConfirmedStatus => 'Result confirmed';

  @override
  String get matchDisputedStatus => 'Result disputed';

  @override
  String get matchEndedStatus => 'Match ended';

  @override
  String get matchLoadError => 'Couldn\'t load the match.';

  @override
  String get matchClose => 'Close';

  @override
  String get matchReviewResult => 'Review result';

  @override
  String get matchViewStatus => 'View status';

  @override
  String get matchViewSummary => 'View summary';

  @override
  String get resultEnterScoreTitle => 'Enter score';

  @override
  String get resultSideYou => 'You';

  @override
  String get resultSideOpponent => 'Opponent';

  @override
  String get resultSideOpponents => 'Opponents';

  @override
  String resultSetLabel(int number) {
    return 'Set $number';
  }

  @override
  String get resultAddSet => 'Add set';

  @override
  String get resultGoalsLabel => 'Goals';

  @override
  String get resultSubmit => 'Submit result';

  @override
  String get resultInvalidHint => 'Enter a completed score to submit.';

  @override
  String get resultConfirmTitle => 'Confirm result';

  @override
  String resultSubmittedBy(String name) {
    return 'Submitted by $name';
  }

  @override
  String get resultSetsLabel => 'Sets';

  @override
  String get resultWaitingConfirm => 'Waiting for opponent to confirm…';

  @override
  String get resultDispute => 'Dispute';

  @override
  String get resultConfirm => 'Confirm';

  @override
  String get resultDisputeDialogTitle => 'Dispute this result?';

  @override
  String get resultDisputeDialogBody =>
      'The match will be marked disputed with no rating change. This can\'t be undone.';

  @override
  String get resultDisputeDialogCancel => 'Cancel';

  @override
  String get resultVictoryTitle => 'Victory!';

  @override
  String get resultDefeatTitle => 'Defeat';

  @override
  String get resultNewRank => 'New campus rank';

  @override
  String resultRankValue(int rank) {
    return '#$rank';
  }

  @override
  String get resultDone => 'Done';

  @override
  String get resultClosedDisputedTitle => 'Result disputed';

  @override
  String get resultClosedDisputedBody =>
      'This result was disputed, so no rating change was applied.';

  @override
  String get resultClosedUnconfirmedTitle => 'Not confirmed in time';

  @override
  String get resultClosedUnconfirmedBody =>
      'The opponent never confirmed, so the match expired with no rating change.';

  @override
  String get resultClosedAbandonedTitle => 'Match abandoned';

  @override
  String get resultClosedAbandonedBody =>
      'This match was abandoned before a result was recorded.';

  @override
  String get resultErrorTitle => 'Something went wrong';

  @override
  String get resultErrorBody => 'Check your connection and try again.';

  @override
  String get resultRetry => 'Retry';

  @override
  String get leaderboardSearchHint => 'Search players';

  @override
  String get leaderboardScopeGlobal => 'Global';

  @override
  String get leaderboardScopeFriends => 'Friends';

  @override
  String get leaderboardScopeMyCourse => 'My course';

  @override
  String get leaderboardThisIsYou => 'This is you!';

  @override
  String get leaderboardYourRank => 'Your rank';

  @override
  String get leaderboardYou => 'You';

  @override
  String get leaderboardEmpty =>
      'No ranked players yet — play a match to get on the board.';

  @override
  String get leaderboardNoPlayers => 'No players found.';

  @override
  String get leaderboardLoadError => 'Couldn\'t load the leaderboard.';

  @override
  String get profileSettingsTooltip => 'Settings';

  @override
  String profileIdentityLine(String username, String degreeProgram) {
    return '@$username · $degreeProgram';
  }

  @override
  String get profileEloTrendTitle => 'ELO trend';

  @override
  String get profileTrendEmpty => 'Confirmed matches will chart your ELO here.';

  @override
  String profileTrendTooltipPoint(int elo, String date) {
    return '$elo · $date';
  }

  @override
  String get profileStatGames => 'Games';

  @override
  String get profileStatWins => 'Wins';

  @override
  String get profileStatLosses => 'Losses';

  @override
  String get profileStatWinRate => 'Win rate';

  @override
  String get profileStatStreak => 'Streak';

  @override
  String get profileStatBest => 'Best';

  @override
  String profileWinRateValue(int percent) {
    return '$percent%';
  }

  @override
  String get profileBlackBeastTitle => 'Black Beast';

  @override
  String get profileFavoriteVictimTitle => 'Favorite Victim';

  @override
  String profileHeadToHeadTally(int wins, int losses) {
    return '${wins}W–${losses}L';
  }

  @override
  String get profileMatchHistoryTitle => 'Match history';

  @override
  String get profileHistoryEmpty =>
      'No matches yet — finished matches will appear here.';

  @override
  String get profileLoadError => 'Couldn\'t load this profile.';

  @override
  String get teamProfileTitle => 'Team';

  @override
  String get teamProfileLoadError => 'Couldn\'t load this team.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsPreferencesSection => 'Preferences';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsUnavailable => 'Not available on this device';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageEnglishShort => 'EN';

  @override
  String get languageItalianShort => 'IT';

  @override
  String get settingsLogout => 'Log out';

  @override
  String settingsVersion(String version) {
    return 'CampusArena · v$version';
  }

  @override
  String settingsPasswordResetSent(String email) {
    return 'Password reset email sent to $email.';
  }

  @override
  String get settingsPasswordResetError =>
      'Couldn\'t send the reset email. Check your connection and try again.';

  @override
  String get settingsPrivacyTitle => 'Privacy';

  @override
  String get settingsPrivacyIntro =>
      'Here\'s what CampusArena stores about you.';

  @override
  String get settingsPrivacyProfile =>
      'Profile: your name, username, email and degree program.';

  @override
  String get settingsPrivacyMatches =>
      'Match results: scores and opponents of the ranked matches you play.';

  @override
  String get settingsPrivacyRatings =>
      'Ratings: your ELO and campus ranking per sport.';

  @override
  String get settingsPrivacyLocation =>
      'Location: a one-off distance check when you check in to a facility — never continuous tracking.';

  @override
  String get settingsPrivacySharing =>
      'CampusArena does not share your data with third parties.';

  @override
  String get friendsTitle => 'Friends';

  @override
  String get friendsAddSectionTitle => 'Add a friend';

  @override
  String get friendsSearchHint => 'Search by username';

  @override
  String get friendsSearchHelper => 'Search players by username, then tap Add.';

  @override
  String get friendsAddButton => 'Add';

  @override
  String get friendsAddedLabel => 'Added';

  @override
  String get friendsYouLabel => 'You';

  @override
  String friendsHandle(String username) {
    return '@$username';
  }

  @override
  String get friendsEmptyTitle => 'No friends yet';

  @override
  String get friendsEmptyBody =>
      'Search for a player by username above to start your private leaderboard.';

  @override
  String get friendsLoadError => 'Couldn\'t load your friends.';

  @override
  String get friendsRemoveTooltip => 'Remove friend';

  @override
  String get friendsRemoveTitle => 'Remove friend?';

  @override
  String friendsRemoveMessage(String name) {
    return 'Remove $name from your friends?';
  }

  @override
  String get friendsRemoveConfirm => 'Remove';

  @override
  String get friendsRemoveCancel => 'Cancel';

  @override
  String friendsAddedSnack(String username) {
    return '$username added to your friends.';
  }

  @override
  String friendsSearchEmpty(String query) {
    return 'No players match “$query”.';
  }

  @override
  String get friendsSearchFailed => 'Couldn\'t search right now. Try again.';

  @override
  String get friendsAddFailedSnack => 'Couldn\'t add that friend. Try again.';

  @override
  String get tournamentCreateTitle => 'Create tournament';

  @override
  String get tournamentNameLabel => 'Tournament name';

  @override
  String get tournamentSportLabel => 'Sport';

  @override
  String get tournamentFacilityLabel => 'Facility';

  @override
  String get tournamentMaxLabel => 'Max participants';

  @override
  String get tournamentDeadlineLabel => 'Registration deadline';

  @override
  String get tournamentScheduleLabel => 'Scheduled time';

  @override
  String get tournamentPickPrompt => 'Select';

  @override
  String get tournamentCreateButton => 'Create';

  @override
  String get tournamentNameRequired => 'Enter a tournament name';

  @override
  String get tournamentFacilityRequired => 'Select a facility';

  @override
  String get tournamentScheduleRequired => 'Select a scheduled time';

  @override
  String get tournamentDeadlineFuture => 'The deadline must be in the future';

  @override
  String get tournamentDeadlineBeforeSchedule =>
      'The deadline must be on or before the scheduled time';

  @override
  String get tournamentCreateError =>
      'Couldn\'t create the tournament. Try again.';

  @override
  String get tournamentLoadError => 'Couldn\'t load the tournament.';

  @override
  String get tournamentRegistrationOpenTitle => 'Registration open';

  @override
  String get tournamentRegistrationOpenBody =>
      'The bracket appears once seeding closes at the registration deadline, or sooner if it fills first.';

  @override
  String get tournamentCancelledTitle => 'Tournament cancelled';

  @override
  String get tournamentCancelledBody =>
      'Not enough players joined before the registration deadline.';

  @override
  String tournamentCompletedBanner(String name) {
    return '$name won the tournament!';
  }

  @override
  String get bracketBye => 'BYE';

  @override
  String get roundOf32 => 'Round of 32';

  @override
  String get roundOf16 => 'Round of 16';

  @override
  String get roundQuarterfinal => 'Quarterfinals';

  @override
  String get roundSemifinal => 'Semifinals';

  @override
  String get roundFinal => 'Final';

  @override
  String get tournamentsTitle => 'Tournaments';

  @override
  String get tournamentsTooltip => 'Tournaments';

  @override
  String get tournamentsUpcoming => 'Upcoming';

  @override
  String get tournamentsOngoing => 'Ongoing';

  @override
  String get tournamentsEmptyTitle => 'No tournaments yet';

  @override
  String get tournamentsEmptyBody =>
      'New tournaments for this sport will show up here.';

  @override
  String get tournamentsLoadError => 'Couldn\'t load tournaments.';

  @override
  String get tournamentToday => 'Today';

  @override
  String get tournamentTomorrow => 'Tomorrow';

  @override
  String get tournamentRegister => 'Register';

  @override
  String get tournamentRegistered => 'Registered';

  @override
  String get tournamentFull => 'Full';

  @override
  String get tournamentStatusRegistering => 'Registering';

  @override
  String get tournamentStatusSeeded => 'Seeded';

  @override
  String get tournamentStatusActive => 'Active';

  @override
  String get tournamentStatusCompleted => 'Completed';

  @override
  String get tournamentStatusCancelled => 'Cancelled';

  @override
  String get tournamentRegisteredSnack => 'You\'re registered.';

  @override
  String get tournamentRegisterError =>
      'Couldn\'t register right now. Try again.';

  @override
  String get tournamentStandings => 'Standings';

  @override
  String get tournamentOrganizerControls => 'Organizer controls';

  @override
  String get tournamentAdvanceSlot => 'Advance slot';

  @override
  String get tournamentMarkForfeit => 'Mark forfeit';

  @override
  String get tournamentBracket => 'Bracket';

  @override
  String get tournamentDetailError => 'Couldn\'t load this tournament.';

  @override
  String get tournamentCancelAction => 'Cancel tournament';

  @override
  String get tournamentCancelTitle => 'Cancel this tournament?';

  @override
  String get tournamentCancelBody =>
      'Registered players will be notified it\'s off. This can\'t be undone.';

  @override
  String get tournamentCancelConfirm => 'Cancel tournament';

  @override
  String get tournamentCancelDismiss => 'Keep it';

  @override
  String get tournamentForfeitTitle => 'Mark a player as forfeited';

  @override
  String get tournamentAdvanceTitle => 'Advance a slot';

  @override
  String tournamentAdvancePickWinner(String slot) {
    return 'Who won $slot?';
  }

  @override
  String tournamentSlotVs(String playerA, String playerB) {
    return '$playerA vs $playerB';
  }

  @override
  String get tournamentNoPlayableSlots => 'No slots are ready to advance yet.';

  @override
  String get tournamentNoAliveParticipants => 'No active players to forfeit.';

  @override
  String get challengePendingTitle => 'Pending challenge';

  @override
  String challengeChallengedYou(String sport) {
    return 'challenged you to $sport';
  }

  @override
  String get challengeAccept => 'Accept';

  @override
  String get challengeDecline => 'Decline';

  @override
  String get challengeAcceptTooltip => 'Accept challenge';

  @override
  String get challengeDeclineTooltip => 'Decline challenge';

  @override
  String get challengeButtonTooltip => 'Challenge';

  @override
  String challengeSheetTitle(String name) {
    return 'Challenge $name';
  }

  @override
  String get challengeSheetPickSport => 'Choose a sport';

  @override
  String get challengeSheetSend => 'Send challenge';

  @override
  String challengeSentSnack(String name) {
    return 'Challenge sent to $name.';
  }

  @override
  String get challengeErrorDuplicate =>
      'You already have a pending challenge with them for this sport.';

  @override
  String get challengeErrorNotFriends => 'You can only challenge friends.';

  @override
  String get challengeErrorGeneric =>
      'Couldn\'t send the challenge. Try again.';

  @override
  String get challengeActionExpired => 'This challenge has expired.';

  @override
  String get challengeActionUnavailable =>
      'Couldn\'t respond right now. Check your connection and try again.';

  @override
  String get challengeActionNoLongerAvailable =>
      'This challenge is no longer available.';

  @override
  String challengeReceivedSnack(String name) {
    return 'New challenge from $name.';
  }

  @override
  String get challengeOutgoingSectionTitle => 'Sent';

  @override
  String challengeOutgoingLabel(String name) {
    return 'vs $name';
  }

  @override
  String get challengeStatusWaiting => 'Waiting';

  @override
  String get challengeStatusAccepted => 'Accepted';

  @override
  String get challengeStatusDeclined => 'Declined';

  @override
  String get challengeStatusExpired => 'Expired';

  @override
  String get challengePlayerFallback => 'A player';

  @override
  String get challengeScreenTitle => 'Challenge';

  @override
  String challengeWaitingTitle(String name) {
    return 'Waiting for $name';
  }

  @override
  String get challengeWaitingBody => 'They\'ll see your challenge in the app.';

  @override
  String get challengeScanToPlay => 'Scan to play';

  @override
  String get challengeAcceptedCta =>
      'Challenge accepted — scan the table QR to start.';

  @override
  String get challengeNotFound => 'Challenge not found.';

  @override
  String get challengeLoadError => 'Couldn\'t load this challenge.';

  @override
  String get achievement_first_victory_name => 'First Victory';

  @override
  String get achievement_first_victory_desc => 'Win your first ranked match.';

  @override
  String get achievement_streak_5_name => 'On Fire';

  @override
  String get achievement_streak_5_desc => 'Win 5 ranked matches in a row.';

  @override
  String get achievement_giant_slayer_name => 'Giant Slayer';

  @override
  String get achievement_giant_slayer_desc =>
      'Beat an opponent rated 200+ ELO above you.';

  @override
  String get achievement_explorer_name => 'Explorer';

  @override
  String get achievement_explorer_desc =>
      'Play at least once at every facility on campus.';

  @override
  String get achievement_tournament_champion_name => 'Champion';

  @override
  String get achievement_tournament_champion_desc =>
      'Win an official tournament.';

  @override
  String get achievement_workaholic_name => 'Workaholic';

  @override
  String get achievement_workaholic_desc =>
      'Play 15 matches in a single month.';

  @override
  String get profileAchievementsTitle => 'Achievements';

  @override
  String achievementUnlockedOn(String date) {
    return 'Unlocked $date';
  }

  @override
  String achievementUnlockHint(String description) {
    return 'Unlock by: $description';
  }

  @override
  String get achievementUnlockHeadline => 'Achievement unlocked!';

  @override
  String get chatbotClearChat => 'Clear chat';

  @override
  String get chatbotSettingsTooltip => 'Assistant settings';

  @override
  String get chatbotGreeting =>
      'Hi! Ask me about empty tables, today\'s tournaments, ELO, or your queue position.';

  @override
  String get chatbotInputHint => 'Ask Arena Assistant...';

  @override
  String get chatbotSend => 'Send';

  @override
  String get chatbotLimitedModeBadge => 'Limited mode - basic answers only';

  @override
  String get chatbotErrorMessage =>
      'I couldn\'t reach the assistant — showing basic answers.';

  @override
  String get chatbotRetry => 'Retry';

  @override
  String get chatbotChipEmptyTables => 'What tables are empty?';

  @override
  String get chatbotChipTournamentsToday => 'Tournaments today';

  @override
  String get chatbotChipHowElo => 'How does ELO work?';

  @override
  String get chatbotChipQueuePosition => 'Where am I in the queue?';

  @override
  String get chatbotOpenMap => 'Open Map';

  @override
  String get chatbotViewTournament => 'View';

  @override
  String get chatbotDismissBanner => 'Dismiss';

  @override
  String get chatbotHomeEntryTitle => 'Arena Assistant';

  @override
  String get chatbotHomeEntrySubtitle =>
      'Ask about tables, tournaments, and ELO';

  @override
  String get tutorialSlide3Disclaimer =>
      'Availability reflects app activity only — not a live guarantee, and not a reservation.';

  @override
  String get chatbotSettingsTitle => 'Assistant Settings';

  @override
  String get chatbotSettingsProviderLabel => 'Provider';

  @override
  String get chatbotSettingsApiKeyLabel => 'API Key';

  @override
  String get chatbotSettingsModelLabel => 'Model';

  @override
  String get chatbotSettingsShowKey => 'Show API key';

  @override
  String get chatbotSettingsHideKey => 'Hide API key';

  @override
  String get chatbotSettingsTestConnection => 'Test Connection';

  @override
  String get chatbotSettingsSave => 'Save';

  @override
  String get chatbotSettingsSaved => 'Assistant settings saved';

  @override
  String get chatbotSettingsTestSuccess => 'Connection successful';

  @override
  String get chatbotSettingsTestFailurePrefix => 'Connection failed:';

  @override
  String get chatbotSettingsNoKeyBanner =>
      'No API key configured — the assistant answers in limited mode. Add a key to enable full AI answers.';

  @override
  String get chatbotSettingsResetModelPrompt =>
      'Reset the model field to this provider\'s default?';

  @override
  String get chatbotSettingsResetModelYes => 'Reset';

  @override
  String get chatbotSettingsResetModelNo => 'Keep';

  @override
  String get chatbotErrorInvalidApiKey =>
      'That API key was rejected. Double-check it and try again.';

  @override
  String get chatbotErrorRateLimited =>
      'The provider is rate-limiting requests right now. Try again shortly.';

  @override
  String get chatbotErrorNetwork =>
      'Couldn\'t reach the network. Check your connection and try again.';

  @override
  String get chatbotErrorMissingApiKey => 'Add an API key first.';

  @override
  String get chatbotErrorGeneric =>
      'Something went wrong reaching the assistant.';

  @override
  String get chatbotErrorTimeout =>
      'The assistant took too long to respond. Try again.';

  @override
  String get chatbotAnswerNoFreeTables =>
      'No tables are currently free based on app activity.';

  @override
  String chatbotAnswerFreeTables(String names) {
    return 'Free right now: $names.';
  }

  @override
  String get chatbotAnswerNoTournaments =>
      'There are no tournaments scheduled for today.';

  @override
  String chatbotAnswerTournamentsToday(String names) {
    return 'Today\'s tournaments: $names.';
  }

  @override
  String get chatbotAnswerQueueNone => 'You\'re not currently in any queue.';

  @override
  String chatbotAnswerQueuePosition(int position, String facility) {
    return 'You\'re at position $position in the queue for $facility.';
  }

  @override
  String get chatbotAnswerEloExplainer =>
      'CampusArena ELO starts every player at 1200. After each confirmed match, the winner gains points and the loser loses points based on the ELO difference between the two players (beating a higher-rated opponent earns more than beating a lower-rated one). The K-factor (how much a single match can move your rating) is 32 for your first 10 matches in a sport, then drops to 16 once you are established. Ratings are tracked separately per sport (Ping Pong, Foosball). Ratings can also lazily decay after long inactivity.';

  @override
  String chatbotAnswerYourElo(int elo, int matches) {
    return 'Your current Ping Pong ELO is $elo after $matches matches.';
  }

  @override
  String chatbotAnswerYourEloRanked(int elo, int rank, int matches) {
    return 'Your current Ping Pong ELO is $elo, ranked #$rank, after $matches matches.';
  }

  @override
  String get chatbotAnswerGeneral =>
      'I can help with empty tables, today\'s tournaments, ELO, and your queue position. Try one of the suggested questions below, or ask me directly.';
}
