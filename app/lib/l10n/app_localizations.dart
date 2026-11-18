import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// The application title shown in the app bar and OS task switcher
  ///
  /// In en, this message translates to:
  /// **'CampusArena'**
  String get appTitle;

  /// Label for the primary check-in play button
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playButtonLabel;

  /// Display name for the ping pong sport
  ///
  /// In en, this message translates to:
  /// **'Ping Pong'**
  String get sportPingPong;

  /// Display name for the foosball sport
  ///
  /// In en, this message translates to:
  /// **'Foosball'**
  String get sportFoosball;

  /// Caption under a rating's ELO figure on the dashboard card
  ///
  /// In en, this message translates to:
  /// **'ELO'**
  String get eloLabel;

  /// Shown in place of a rank while it is still being computed
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get rankPlaceholder;

  /// Number of matches played for a sport on the dashboard card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No matches yet} one{1 match played} other{{count} matches played}}'**
  String matchesPlayedCount(int count);

  /// Section header above the recent match history list
  ///
  /// In en, this message translates to:
  /// **'Recent Matches'**
  String get recentMatchesTitle;

  /// Empty state for the recent match history list
  ///
  /// In en, this message translates to:
  /// **'No matches yet — scan a facility QR code to play your first ranked match.'**
  String get noRecentMatches;

  /// Match history row title naming the opponent(s)
  ///
  /// In en, this message translates to:
  /// **'vs {opponents}'**
  String vsOpponents(String opponents);

  /// Result label on a confirmed match the user won
  ///
  /// In en, this message translates to:
  /// **'Won'**
  String get matchWon;

  /// Result label on a confirmed match the user lost
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get matchLost;

  /// Status label on a disputed match history row
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get matchStateDisputed;

  /// Status label on an unconfirmed match history row
  ///
  /// In en, this message translates to:
  /// **'Unconfirmed'**
  String get matchStateUnconfirmed;

  /// Status label on an abandoned match history row
  ///
  /// In en, this message translates to:
  /// **'Abandoned'**
  String get matchStateAbandoned;

  /// Error message shown when the dashboard fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your dashboard.'**
  String get dashboardLoadError;

  /// Button to retry a failed load
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButtonLabel;

  /// Uppercased label above the big ELO figure on the dashboard hero card
  ///
  /// In en, this message translates to:
  /// **'ELO Rating'**
  String get eloRatingLabel;

  /// Title of the Arena Assistant entry card on the dashboard
  ///
  /// In en, this message translates to:
  /// **'Arena Assistant'**
  String get assistantCardTitle;

  /// Subtitle of the Arena Assistant entry card on the dashboard
  ///
  /// In en, this message translates to:
  /// **'Ask about free tables, queues & ELO'**
  String get assistantCardSubtitle;

  /// App bar title for the Arena Assistant chat screen
  ///
  /// In en, this message translates to:
  /// **'Arena Assistant'**
  String get chatbotTitle;

  /// Placeholder body shown on the stubbed Arena Assistant screen
  ///
  /// In en, this message translates to:
  /// **'The Arena Assistant is coming soon.'**
  String get chatbotComingSoon;

  /// Label for the home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// Label for the map tab
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapTab;

  /// Label for the leaderboards tab
  ///
  /// In en, this message translates to:
  /// **'Leaderboards'**
  String get leaderboardsTab;

  /// Label for the profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTab;

  /// Tagline shown on the landing screen
  ///
  /// In en, this message translates to:
  /// **'Track your ELO, climb the campus ranks, and rule ping pong & foosball at PoliMi.'**
  String get landingTagline;

  /// Tagline shown on the splash screen
  ///
  /// In en, this message translates to:
  /// **'Own the table.'**
  String get splashTagline;

  /// Label for the log-in action / screen title
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// Label for the register action / screen title
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Primary submit button on the login screen
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Primary submit button on the registration screen
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// App-bar title of the registration screen when it is recreating a missing profile for an already-signed-in account
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get completeProfileTitle;

  /// Explanation shown when an authenticated account has no profile document and must recreate it
  ///
  /// In en, this message translates to:
  /// **'Your account doesn\'t have a profile yet. Pick a name and username to finish setting up.'**
  String get completeProfileMessage;

  /// Submit button that recreates the missing profile for an already-signed-in account
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get completeProfileButton;

  /// Label for the email input field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Label for the password input field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Icon button tooltip that shows/hides the password field's text
  ///
  /// In en, this message translates to:
  /// **'Toggle password visibility'**
  String get togglePasswordVisibility;

  /// Label for the full-name input field
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get nameLabel;

  /// Label for the username input field
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// Label for the degree-program dropdown
  ///
  /// In en, this message translates to:
  /// **'Degree Program'**
  String get degreeProgramLabel;

  /// Hint shown in the degree-program dropdown before selection
  ///
  /// In en, this message translates to:
  /// **'Select your degree program'**
  String get degreeProgramHint;

  /// Link from the login screen to the password-reset screen
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// Title of the forgot-password screen
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get forgotPasswordTitle;

  /// Instructional copy on the forgot-password screen
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a link to reset your password.'**
  String get forgotPasswordInstructions;

  /// Submit button on the forgot-password screen
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// Confirmation shown after requesting a password reset
  ///
  /// In en, this message translates to:
  /// **'If that email is registered, a reset link has been sent.'**
  String get passwordResetSent;

  /// Plain-text portion of the login screen's link to registration, immediately followed by the register action word
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccountPromptPrefix;

  /// Plain-text portion of the registration screen's link to login, immediately followed by the log-in action word
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccountPromptPrefix;

  /// Validation message for an empty required field
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// Validation message for a malformed email
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get invalidEmail;

  /// Validation message for a username with an invalid length or characters
  ///
  /// In en, this message translates to:
  /// **'3–20 lowercase letters, numbers or underscores'**
  String get invalidUsername;

  /// Validation message for a too-short password
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// Fallback auth error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorGeneric;

  /// Auth error for wrong credentials
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get authErrorInvalidCredentials;

  /// Auth error when registering an email already in use
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get authErrorEmailInUse;

  /// Auth error for a malformed email rejected by Firebase
  ///
  /// In en, this message translates to:
  /// **'That email address is invalid.'**
  String get authErrorInvalidEmail;

  /// Auth error for a weak password
  ///
  /// In en, this message translates to:
  /// **'Please choose a stronger password.'**
  String get authErrorWeakPassword;

  /// Auth error for a failed network request
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection.'**
  String get authErrorNetwork;

  /// Registration error when the chosen username is already claimed by another account
  ///
  /// In en, this message translates to:
  /// **'That username is already taken.'**
  String get authErrorUsernameTaken;

  /// Button to skip the walkthrough
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tutorialSkip;

  /// Button to advance to the next tutorial slide
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tutorialNext;

  /// Button on the last tutorial slide that finishes onboarding
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get tutorialDone;

  /// Title of the first tutorial slide
  ///
  /// In en, this message translates to:
  /// **'Play Ranked Matches'**
  String get tutorialSlide1Title;

  /// Body of the first tutorial slide
  ///
  /// In en, this message translates to:
  /// **'Scan a facility\'s QR code to check in and record your match.'**
  String get tutorialSlide1Body;

  /// Title of the second tutorial slide
  ///
  /// In en, this message translates to:
  /// **'Climb the Leaderboards'**
  String get tutorialSlide2Title;

  /// Body of the second tutorial slide
  ///
  /// In en, this message translates to:
  /// **'Every win updates your ELO. Compete across sports and degree programs.'**
  String get tutorialSlide2Body;

  /// Title of the third tutorial slide
  ///
  /// In en, this message translates to:
  /// **'Join the Queue'**
  String get tutorialSlide3Title;

  /// Body of the third tutorial slide
  ///
  /// In en, this message translates to:
  /// **'See live facility status on the map and reserve your spot in line.'**
  String get tutorialSlide3Body;

  /// No description provided for @degAerospace.
  ///
  /// In en, this message translates to:
  /// **'Aerospace Engineering'**
  String get degAerospace;

  /// No description provided for @degArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get degArchitecture;

  /// No description provided for @degBiomedical.
  ///
  /// In en, this message translates to:
  /// **'Biomedical Engineering'**
  String get degBiomedical;

  /// No description provided for @degChemical.
  ///
  /// In en, this message translates to:
  /// **'Chemical Engineering'**
  String get degChemical;

  /// No description provided for @degCivil.
  ///
  /// In en, this message translates to:
  /// **'Civil Engineering'**
  String get degCivil;

  /// No description provided for @degComputer.
  ///
  /// In en, this message translates to:
  /// **'Computer Science and Engineering'**
  String get degComputer;

  /// No description provided for @degDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get degDesign;

  /// No description provided for @degElectrical.
  ///
  /// In en, this message translates to:
  /// **'Electrical Engineering'**
  String get degElectrical;

  /// No description provided for @degElectronic.
  ///
  /// In en, this message translates to:
  /// **'Electronic Engineering'**
  String get degElectronic;

  /// No description provided for @degEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy Engineering'**
  String get degEnergy;

  /// No description provided for @degManagement.
  ///
  /// In en, this message translates to:
  /// **'Management Engineering'**
  String get degManagement;

  /// No description provided for @degMathematical.
  ///
  /// In en, this message translates to:
  /// **'Mathematical Engineering'**
  String get degMathematical;

  /// No description provided for @degMechanical.
  ///
  /// In en, this message translates to:
  /// **'Mechanical Engineering'**
  String get degMechanical;

  /// No description provided for @degTelecom.
  ///
  /// In en, this message translates to:
  /// **'Telecommunication Engineering'**
  String get degTelecom;

  /// No description provided for @degUrban.
  ///
  /// In en, this message translates to:
  /// **'Urban Planning'**
  String get degUrban;

  /// Label on the current-conditions snippet of an outdoor facility detail card
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weatherLabel;

  /// Temperature in degrees Celsius, pre-formatted for the locale
  ///
  /// In en, this message translates to:
  /// **'{value}°'**
  String weatherTemperature(String value);

  /// Precipitation in millimetres, pre-formatted for the locale
  ///
  /// In en, this message translates to:
  /// **'{value} mm'**
  String weatherPrecipitation(String value);

  /// Wind speed in km/h, pre-formatted for the locale
  ///
  /// In en, this message translates to:
  /// **'{value} km/h'**
  String weatherWind(String value);

  /// Error state of the weather snippet / forecast strip when the fetch fails
  ///
  /// In en, this message translates to:
  /// **'Weather unavailable'**
  String get weatherUnavailable;

  /// Action on the weather error state that retries the fetch
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get weatherRetry;

  /// Header of the hourly forecast strip on outdoor tournament views
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get forecastLabel;

  /// Primary button on the facility detail card that adds the user to the queue
  ///
  /// In en, this message translates to:
  /// **'Join Queue'**
  String get queueJoin;

  /// Button that removes the user from the queue they are currently in
  ///
  /// In en, this message translates to:
  /// **'Leave queue'**
  String get queueLeave;

  /// Action shown after a failed join/leave that retries the queue write
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get queueRetry;

  /// Live counter of the user's queue position and total queue length
  ///
  /// In en, this message translates to:
  /// **'You\'re #{position} of {total}'**
  String queuePositionCounter(int position, int total);

  /// Badge on the position counter when the user holds the front of the queue
  ///
  /// In en, this message translates to:
  /// **'You\'re next'**
  String get queueYoureNext;

  /// Inline error shown when a join or leave write fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the queue. Check your connection.'**
  String get queueError;

  /// Title of the in-app banner shown to the front-of-queue player when the table frees
  ///
  /// In en, this message translates to:
  /// **'Your table is ready'**
  String get queueTableReadyTitle;

  /// Body of the table-ready banner
  ///
  /// In en, this message translates to:
  /// **'You\'re first in line — head to the table now.'**
  String get queueTableReadyBody;

  /// Tooltip on the button that dismisses the table-ready banner
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get queueTableReadyDismiss;

  /// Mandatory short availability disclaimer (project_description.md §3.10) shown in card footers wherever facility availability is surfaced
  ///
  /// In en, this message translates to:
  /// **'Based on app activity only — the table may be in use by non-app players. Not a reservation.'**
  String get availabilityDisclaimerShort;

  /// Mandatory full availability disclaimer (project_description.md §3.10) shown in banners and info panels
  ///
  /// In en, this message translates to:
  /// **'Availability shows CampusArena activity only. A table marked as empty may still be in use by people who aren\'t playing through the app. CampusArena is not a booking service — spots can\'t be reserved.'**
  String get availabilityDisclaimerFull;

  /// Title of the soft priority-warning dialog shown when a non-front user tries to claim a table
  ///
  /// In en, this message translates to:
  /// **'Someone is ahead of you'**
  String get queuePriorityTitle;

  /// Body of the priority-warning dialog comparing the user's ticket to the front of the queue
  ///
  /// In en, this message translates to:
  /// **'You\'re #{position} in the queue and #{frontPosition} is next in line. Please let them play first.'**
  String queuePriorityBody(int position, int frontPosition);

  /// Action on the priority-warning dialog that proceeds despite not being first
  ///
  /// In en, this message translates to:
  /// **'Claim anyway'**
  String get queuePriorityProceed;

  /// Action on the priority-warning dialog that backs out of claiming the table
  ///
  /// In en, this message translates to:
  /// **'Wait my turn'**
  String get queuePriorityCancel;

  /// Chatbot first-open banner; carries the full availability disclaimer copy (project_description.md §3.10)
  ///
  /// In en, this message translates to:
  /// **'Availability shows CampusArena activity only. A table marked as empty may still be in use by people who aren\'t playing through the app. CampusArena is not a booking service — spots can\'t be reserved.'**
  String get chatbotIntroDisclaimer;

  /// OpenStreetMap tile attribution shown on the facility map
  ///
  /// In en, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get mapAttribution;

  /// Label for the List segment of the map/list view toggle (the Map segment reuses mapTab)
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get mapViewList;

  /// Header above the facility list when it is ordered by distance from the user
  ///
  /// In en, this message translates to:
  /// **'Sorted by proximity'**
  String get facilityListSortedByProximity;

  /// Distance in metres shown on a facility list row (under 1 km)
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String distanceMeters(int meters);

  /// Distance in kilometres shown on a facility list row (1 km or more)
  ///
  /// In en, this message translates to:
  /// **'{kilometers} km'**
  String distanceKilometers(double kilometers);

  /// Facility status label / map legend entry for a free facility
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get facilityStatusFree;

  /// Facility status label / map legend entry for an occupied facility
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get facilityStatusOccupied;

  /// Facility status label / map legend entry for a facility with a queue
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get facilityStatusQueued;

  /// Tag next to the status chip marking an outdoor facility
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get facilityOutdoorLabel;

  /// Caption of the current-players tile on the facility detail card
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get facilityPlayersLabel;

  /// Caption of the match-duration tile on the facility detail card
  ///
  /// In en, this message translates to:
  /// **'Match duration'**
  String get facilityMatchDurationLabel;

  /// Elapsed match duration in minutes on the facility detail card
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String facilityDurationMinutes(int minutes);

  /// Shown on a facility detail tile when there is no active match to read the value from
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get facilityValuePlaceholder;

  /// Caption of the reigning-champion row on the facility detail card
  ///
  /// In en, this message translates to:
  /// **'King of the Table'**
  String get facilityKingOfTable;

  /// Consecutive win count of the facility's King of the Table
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 win} other{{count} wins}}'**
  String facilityKingWins(int count);

  /// Empty state of the King of the Table row when nobody holds the title
  ///
  /// In en, this message translates to:
  /// **'No King of the Table yet'**
  String get facilityNoKing;

  /// Error state shown on the map when the facility stream fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load facilities.'**
  String get facilityLoadError;

  /// Empty state when the facility list has no entries
  ///
  /// In en, this message translates to:
  /// **'No facilities on campus yet.'**
  String get facilityListEmpty;

  /// Tooltip of the map button that recenters on the user's position
  ///
  /// In en, this message translates to:
  /// **'Center on my location'**
  String get mapRecenterTooltip;

  /// Snackbar shown when recentering fails (permission denied or location services off)
  ///
  /// In en, this message translates to:
  /// **'Location unavailable.'**
  String get locationUnavailable;

  /// Title under the QR viewfinder on the scan screen
  ///
  /// In en, this message translates to:
  /// **'Scan table QR'**
  String get qrScanTitle;

  /// Subtitle under the QR viewfinder guiding the user to aim the camera
  ///
  /// In en, this message translates to:
  /// **'Point your camera at the QR code on the table'**
  String get qrScanHint;

  /// Button that opens the manual fallback-code entry when the camera can't read the sticker
  ///
  /// In en, this message translates to:
  /// **'Enter code manually'**
  String get qrEnterManually;

  /// Title of the manual fallback-code entry sheet
  ///
  /// In en, this message translates to:
  /// **'Enter table code'**
  String get qrManualEntryTitle;

  /// Text-field label for the printed alphanumeric fallback code
  ///
  /// In en, this message translates to:
  /// **'Table code'**
  String get qrManualEntryLabel;

  /// Submit button on the manual fallback-code entry sheet
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get qrManualEntrySubmit;

  /// Soft, non-blocking GPS warning shown when the user is beyond the distance threshold from the facility
  ///
  /// In en, this message translates to:
  /// **'You seem far from this table — check-in still allowed'**
  String get qrGpsWarning;

  /// Confirm-check-in button shown when the facility is already known (deep link)
  ///
  /// In en, this message translates to:
  /// **'Check in to {facility}'**
  String qrCheckInButton(String facility);

  /// App-bar title of the match-setup screen where the creator picks singles/doubles and their side before checking in
  ///
  /// In en, this message translates to:
  /// **'Set up match'**
  String get matchSetupTitle;

  /// Guidance under the setup heading, naming the resolved facility
  ///
  /// In en, this message translates to:
  /// **'Choose the match type, then check in at {facility}.'**
  String matchSetupSubtitle(String facility);

  /// Label above the singles/doubles selector on the check-in screen
  ///
  /// In en, this message translates to:
  /// **'Match type'**
  String get matchModeLabel;

  /// Singles (1v1) option in the match-type selector
  ///
  /// In en, this message translates to:
  /// **'Singles'**
  String get matchModeSingles;

  /// Doubles (2v2) option in the match-type selector
  ///
  /// In en, this message translates to:
  /// **'Doubles'**
  String get matchModeDoubles;

  /// Label above the Team 1 / Team 2 side selector when creating or joining a doubles match
  ///
  /// In en, this message translates to:
  /// **'Your team'**
  String get matchTeamLabel;

  /// First side of a doubles match
  ///
  /// In en, this message translates to:
  /// **'Team 1'**
  String get matchTeam1;

  /// Second side of a doubles match
  ///
  /// In en, this message translates to:
  /// **'Team 2'**
  String get matchTeam2;

  /// Prompt shown to a doubles joiner who must choose a team before joining
  ///
  /// In en, this message translates to:
  /// **'Pick your side'**
  String get matchPickSideTitle;

  /// Guidance under the pick-your-side prompt for a doubles joiner
  ///
  /// In en, this message translates to:
  /// **'Choose a team to join this doubles match.'**
  String get matchPickSideBody;

  /// Badge on a doubles side that already has two players
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get matchSideFull;

  /// Guidance shown while a doubles roster is still filling
  ///
  /// In en, this message translates to:
  /// **'Ask the others to scan this table\'s QR and pick a side.'**
  String get matchWaitingPlayersBody;

  /// Error shown when a scanned or typed code resolves to no facility
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t match any table. Check it and try again.'**
  String get qrInvalidCode;

  /// Error shown when creating the match fails (e.g. offline, since ranked writes require connectivity)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the match. Check your connection and try again.'**
  String get qrCheckInError;

  /// Error shown when scanning a table whose live match is full or already awaiting confirmation, so there is no slot to join
  ///
  /// In en, this message translates to:
  /// **'This table already has a match in progress. Wait for it to finish.'**
  String get qrTableBusy;

  /// Error shown when scanning a table whose sport differs from the accepted challenge's sport
  ///
  /// In en, this message translates to:
  /// **'This table isn\'t for {sport}. Scan a {sport} table to play your challenge.'**
  String qrSportMismatch(String sport);

  /// Title of the confirmation dialog shown when backing out of a live match
  ///
  /// In en, this message translates to:
  /// **'Leave match?'**
  String get leaveMatchTitle;

  /// Body of the confirmation dialog shown when backing out of a live match
  ///
  /// In en, this message translates to:
  /// **'Leaving now abandons this match for both players and frees the table.'**
  String get leaveMatchMessage;

  /// Confirm button that abandons the match and leaves the screen
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveMatchConfirm;

  /// Cancel button that dismisses the leave-match dialog and stays in the match
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get leaveMatchCancel;

  /// Pulsing badge on the active-match screen indicating the session is in progress
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get matchLiveBadge;

  /// Separator between the two player cards on the active-match screen
  ///
  /// In en, this message translates to:
  /// **'VS'**
  String get matchVs;

  /// Primary button on the active-match screen that opens the result-entry flow
  ///
  /// In en, this message translates to:
  /// **'Record result'**
  String get matchRecordResult;

  /// A player's ELO under their name on the active-match screen
  ///
  /// In en, this message translates to:
  /// **'{elo} ELO'**
  String matchEloValue(int elo);

  /// Placeholder shown in the opponent slot before a second player has checked in
  ///
  /// In en, this message translates to:
  /// **'Waiting for opponent'**
  String get matchWaitingOpponentTitle;

  /// Guidance shown while waiting for the opponent to check in
  ///
  /// In en, this message translates to:
  /// **'Ask your opponent to scan this table\'s QR to join.'**
  String get matchWaitingOpponentBody;

  /// Status line shown on the active-match screen once a result was submitted and awaits opponent confirmation
  ///
  /// In en, this message translates to:
  /// **'Result submitted — waiting for confirmation'**
  String get matchResultSubmittedStatus;

  /// Status shown when the streamed match reaches the confirmed state
  ///
  /// In en, this message translates to:
  /// **'Result confirmed'**
  String get matchConfirmedStatus;

  /// Status shown when the streamed match reaches the disputed state
  ///
  /// In en, this message translates to:
  /// **'Result disputed'**
  String get matchDisputedStatus;

  /// Status shown when the streamed match ends without a confirmed result (unconfirmed/abandoned)
  ///
  /// In en, this message translates to:
  /// **'Match ended'**
  String get matchEndedStatus;

  /// Error state shown when the active match can't be loaded
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the match.'**
  String get matchLoadError;

  /// Button that leaves a terminal-state match screen
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get matchClose;

  /// Active-match CTA when the opponent submitted a result the user must review
  ///
  /// In en, this message translates to:
  /// **'Review result'**
  String get matchReviewResult;

  /// Active-match CTA when the user submitted a result and is awaiting the opponent
  ///
  /// In en, this message translates to:
  /// **'View status'**
  String get matchViewStatus;

  /// Active-match CTA when the match is confirmed, opening the result summary
  ///
  /// In en, this message translates to:
  /// **'View summary'**
  String get matchViewSummary;

  /// Title of the score-entry screen
  ///
  /// In en, this message translates to:
  /// **'Enter score'**
  String get resultEnterScoreTitle;

  /// Label under the current user's avatar on the score-entry and review screens
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get resultSideYou;

  /// Label under the opponent's avatar on the score-entry screen
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get resultSideOpponent;

  /// Label under the opposing pair on the doubles review screen
  ///
  /// In en, this message translates to:
  /// **'Opponents'**
  String get resultSideOpponents;

  /// Per-set row caption in the ping pong score entry
  ///
  /// In en, this message translates to:
  /// **'Set {number}'**
  String resultSetLabel(int number);

  /// Button that appends another set row in the ping pong score entry
  ///
  /// In en, this message translates to:
  /// **'Add set'**
  String get resultAddSet;

  /// Centre caption between the two goal steppers in the foosball score entry
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get resultGoalsLabel;

  /// Button that submits the entered score for opponent confirmation
  ///
  /// In en, this message translates to:
  /// **'Submit result'**
  String get resultSubmit;

  /// Helper shown under the disabled submit button while the score is incomplete or invalid
  ///
  /// In en, this message translates to:
  /// **'Enter a completed score to submit.'**
  String get resultInvalidHint;

  /// Title of the opponent confirmation / review screen
  ///
  /// In en, this message translates to:
  /// **'Confirm result'**
  String get resultConfirmTitle;

  /// Banner naming the player who entered the result
  ///
  /// In en, this message translates to:
  /// **'Submitted by {name}'**
  String resultSubmittedBy(String name);

  /// Caption between the two set-count totals on the review score card
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get resultSetsLabel;

  /// Footer shown to the submitter while the opponent has not yet confirmed
  ///
  /// In en, this message translates to:
  /// **'Waiting for opponent to confirm…'**
  String get resultWaitingConfirm;

  /// Button the opponent taps to dispute the submitted result
  ///
  /// In en, this message translates to:
  /// **'Dispute'**
  String get resultDispute;

  /// Button the opponent taps to confirm the submitted result
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get resultConfirm;

  /// Title of the dispute confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Dispute this result?'**
  String get resultDisputeDialogTitle;

  /// Body of the dispute confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'The match will be marked disputed with no rating change. This can\'t be undone.'**
  String get resultDisputeDialogBody;

  /// Cancel action in the dispute confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get resultDisputeDialogCancel;

  /// Summary header shown when the current user's side won
  ///
  /// In en, this message translates to:
  /// **'Victory!'**
  String get resultVictoryTitle;

  /// Summary header shown when the current user's side lost
  ///
  /// In en, this message translates to:
  /// **'Defeat'**
  String get resultDefeatTitle;

  /// Label above the updated campus rank on the summary screen
  ///
  /// In en, this message translates to:
  /// **'New campus rank'**
  String get resultNewRank;

  /// The campus rank number, prefixed with a hash
  ///
  /// In en, this message translates to:
  /// **'#{rank}'**
  String resultRankValue(int rank);

  /// Button that leaves the summary screen back to Home
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get resultDone;

  /// Title of the closed screen when the match was disputed
  ///
  /// In en, this message translates to:
  /// **'Result disputed'**
  String get resultClosedDisputedTitle;

  /// Body of the closed screen when the match was disputed
  ///
  /// In en, this message translates to:
  /// **'This result was disputed, so no rating change was applied.'**
  String get resultClosedDisputedBody;

  /// Title of the closed screen when the match expired unconfirmed
  ///
  /// In en, this message translates to:
  /// **'Not confirmed in time'**
  String get resultClosedUnconfirmedTitle;

  /// Body of the closed screen when the match expired unconfirmed
  ///
  /// In en, this message translates to:
  /// **'The opponent never confirmed, so the match expired with no rating change.'**
  String get resultClosedUnconfirmedBody;

  /// Title of the closed screen when the match was abandoned
  ///
  /// In en, this message translates to:
  /// **'Match abandoned'**
  String get resultClosedAbandonedTitle;

  /// Body of the closed screen when the match was abandoned
  ///
  /// In en, this message translates to:
  /// **'This match was abandoned before a result was recorded.'**
  String get resultClosedAbandonedBody;

  /// Title of the result-flow error state
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get resultErrorTitle;

  /// Body of the result-flow error state
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get resultErrorBody;

  /// Button that retries the failed result-flow action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get resultRetry;

  /// Placeholder for the leaderboard player-search field
  ///
  /// In en, this message translates to:
  /// **'Search players'**
  String get leaderboardSearchHint;

  /// Leaderboard scope segment for the unfiltered campus-wide board
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get leaderboardScopeGlobal;

  /// Leaderboard scope segment limiting the board to the user's friends
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get leaderboardScopeFriends;

  /// Leaderboard scope segment limiting the board to the user's degree program
  ///
  /// In en, this message translates to:
  /// **'My course'**
  String get leaderboardScopeMyCourse;

  /// Snackbar shown when the user taps their own leaderboard row (own profile drill-in is blocked)
  ///
  /// In en, this message translates to:
  /// **'This is you!'**
  String get leaderboardThisIsYou;

  /// Label on the pinned bar showing the current user's own ranking
  ///
  /// In en, this message translates to:
  /// **'Your rank'**
  String get leaderboardYourRank;

  /// Fallback name for the current user on the your-rank bar before their name resolves
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get leaderboardYou;

  /// Empty state when the leaderboard has no entries for the sport/scope
  ///
  /// In en, this message translates to:
  /// **'No ranked players yet — play a match to get on the board.'**
  String get leaderboardEmpty;

  /// Empty state when a player search returns no matches
  ///
  /// In en, this message translates to:
  /// **'No players found.'**
  String get leaderboardNoPlayers;

  /// Error message shown when the leaderboard fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the leaderboard.'**
  String get leaderboardLoadError;

  /// Tooltip of the settings gear in the profile app bar
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettingsTooltip;

  /// Username and degree program line under the display name on the profile header
  ///
  /// In en, this message translates to:
  /// **'@{username} · {degreeProgram}'**
  String profileIdentityLine(String username, String degreeProgram);

  /// Title of the ELO trend chart card on the profile screen
  ///
  /// In en, this message translates to:
  /// **'ELO trend'**
  String get profileEloTrendTitle;

  /// Empty state inside the trend card when the sport has fewer than two rated matches
  ///
  /// In en, this message translates to:
  /// **'Confirmed matches will chart your ELO here.'**
  String get profileTrendEmpty;

  /// Touch tooltip on a trend chart point: the ELO after that match and its date
  ///
  /// In en, this message translates to:
  /// **'{elo} · {date}'**
  String profileTrendTooltipPoint(int elo, String date);

  /// Caption of the total-games stat tile
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get profileStatGames;

  /// Caption of the wins stat tile
  ///
  /// In en, this message translates to:
  /// **'Wins'**
  String get profileStatWins;

  /// Caption of the losses stat tile
  ///
  /// In en, this message translates to:
  /// **'Losses'**
  String get profileStatLosses;

  /// Caption of the win-rate stat tile
  ///
  /// In en, this message translates to:
  /// **'Win rate'**
  String get profileStatWinRate;

  /// Caption of the current win-streak stat tile
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get profileStatStreak;

  /// Caption of the all-time best win-streak stat tile
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get profileStatBest;

  /// Win rate figure as a whole percentage
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String profileWinRateValue(int percent);

  /// Title of the fun-stat card naming the opponent who beat the user most
  ///
  /// In en, this message translates to:
  /// **'Black Beast'**
  String get profileBlackBeastTitle;

  /// Title of the fun-stat card naming the opponent the user beat most
  ///
  /// In en, this message translates to:
  /// **'Favorite Victim'**
  String get profileFavoriteVictimTitle;

  /// Head-to-head record on a fun-stat card, from the user's perspective
  ///
  /// In en, this message translates to:
  /// **'{wins}W–{losses}L'**
  String profileHeadToHeadTally(int wins, int losses);

  /// Section header above the full match history list on the profile screen
  ///
  /// In en, this message translates to:
  /// **'Match history'**
  String get profileMatchHistoryTitle;

  /// Empty state of the profile match history list
  ///
  /// In en, this message translates to:
  /// **'No matches yet — finished matches will appear here.'**
  String get profileHistoryEmpty;

  /// Error message shown when the profile fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this profile.'**
  String get profileLoadError;

  /// App bar title of the doubles team (pair) profile screen
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get teamProfileTitle;

  /// Error message shown when the team profile fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this team.'**
  String get teamProfileLoadError;

  /// App bar title of the settings screen
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Section header above the account settings group
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// Section header above the preferences settings group
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferencesSection;

  /// Account row that sends a password-reset email
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePassword;

  /// Account row opening the privacy info page
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// Preferences row toggling push notifications for this device
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// Subtitle shown on the disabled notifications row when no FCM token is available
  ///
  /// In en, this message translates to:
  /// **'Not available on this device'**
  String get settingsNotificationsUnavailable;

  /// Preferences row with the EN/IT language segmented control
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Short English language-code label on the language switcher segment; shown in its own form regardless of active locale
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get languageEnglishShort;

  /// Short Italian language-code label on the language switcher segment; shown in its own form regardless of active locale
  ///
  /// In en, this message translates to:
  /// **'IT'**
  String get languageItalianShort;

  /// Destructive button that signs the user out
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogout;

  /// Version footer line at the bottom of the settings screen
  ///
  /// In en, this message translates to:
  /// **'CampusArena · v{version}'**
  String settingsVersion(String version);

  /// Confirmation snackbar after requesting a password reset from settings
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent to {email}.'**
  String settingsPasswordResetSent(String email);

  /// Error snackbar when the password-reset request fails (offline / rate-limited)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the reset email. Check your connection and try again.'**
  String get settingsPasswordResetError;

  /// App bar title of the privacy info page
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacyTitle;

  /// Intro line on the privacy info page
  ///
  /// In en, this message translates to:
  /// **'Here\'s what CampusArena stores about you.'**
  String get settingsPrivacyIntro;

  /// Privacy page bullet describing stored profile data
  ///
  /// In en, this message translates to:
  /// **'Profile: your name, username, email and degree program.'**
  String get settingsPrivacyProfile;

  /// Privacy page bullet describing stored match data
  ///
  /// In en, this message translates to:
  /// **'Match results: scores and opponents of the ranked matches you play.'**
  String get settingsPrivacyMatches;

  /// Privacy page bullet describing stored rating data
  ///
  /// In en, this message translates to:
  /// **'Ratings: your ELO and campus ranking per sport.'**
  String get settingsPrivacyRatings;

  /// Privacy page bullet describing the GPS distance audit
  ///
  /// In en, this message translates to:
  /// **'Location: a one-off distance check when you check in to a facility — never continuous tracking.'**
  String get settingsPrivacyLocation;

  /// Privacy page line stating there is no third-party data sharing
  ///
  /// In en, this message translates to:
  /// **'CampusArena does not share your data with third parties.'**
  String get settingsPrivacySharing;

  /// App bar title of the friends screen
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTitle;

  /// Heading above the add-friend username field
  ///
  /// In en, this message translates to:
  /// **'Add a friend'**
  String get friendsAddSectionTitle;

  /// Hint of the add-friend search field
  ///
  /// In en, this message translates to:
  /// **'Search by username'**
  String get friendsSearchHint;

  /// Helper text under the add-friend search field
  ///
  /// In en, this message translates to:
  /// **'Search players by username, then tap Add.'**
  String get friendsSearchHelper;

  /// Button on a search-result row that adds that player as a friend
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get friendsAddButton;

  /// Label on a search-result row for a player who is already a friend
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get friendsAddedLabel;

  /// Label on the search-result row that is the signed-in user themselves
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get friendsYouLabel;

  /// A player's username rendered as an @-handle
  ///
  /// In en, this message translates to:
  /// **'@{username}'**
  String friendsHandle(String username);

  /// Title of the empty friends list
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get friendsEmptyTitle;

  /// Body of the empty friends list
  ///
  /// In en, this message translates to:
  /// **'Search for a player by username above to start your private leaderboard.'**
  String get friendsEmptyBody;

  /// Error state shown when the friends stream fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your friends.'**
  String get friendsLoadError;

  /// Tooltip on the remove-friend affordance in a friend row
  ///
  /// In en, this message translates to:
  /// **'Remove friend'**
  String get friendsRemoveTooltip;

  /// Title of the remove-friend confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Remove friend?'**
  String get friendsRemoveTitle;

  /// Body of the remove-friend confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from your friends?'**
  String friendsRemoveMessage(String name);

  /// Confirm action of the remove-friend dialog
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get friendsRemoveConfirm;

  /// Cancel action of the remove-friend dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get friendsRemoveCancel;

  /// Confirmation snackbar after adding a friend
  ///
  /// In en, this message translates to:
  /// **'{username} added to your friends.'**
  String friendsAddedSnack(String username);

  /// Empty state when the add-friend search returns no players
  ///
  /// In en, this message translates to:
  /// **'No players match “{query}”.'**
  String friendsSearchEmpty(String query);

  /// Shown when the add-friend search query itself fails (offline / permission)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t search right now. Try again.'**
  String get friendsSearchFailed;

  /// Snackbar shown when adding a friend fails to write
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add that friend. Try again.'**
  String get friendsAddFailedSnack;

  /// App bar title of the create-tournament form
  ///
  /// In en, this message translates to:
  /// **'Create tournament'**
  String get tournamentCreateTitle;

  /// Label for the tournament name field on the create form
  ///
  /// In en, this message translates to:
  /// **'Tournament name'**
  String get tournamentNameLabel;

  /// Label above the sport selector on the create-tournament form
  ///
  /// In en, this message translates to:
  /// **'Sport'**
  String get tournamentSportLabel;

  /// Label for the facility dropdown on the create-tournament form
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get tournamentFacilityLabel;

  /// Label for the max-participants stepper on the create-tournament form
  ///
  /// In en, this message translates to:
  /// **'Max participants'**
  String get tournamentMaxLabel;

  /// Label for the registration-deadline picker on the create-tournament form
  ///
  /// In en, this message translates to:
  /// **'Registration deadline'**
  String get tournamentDeadlineLabel;

  /// Label for the scheduled-time picker on the create-tournament form
  ///
  /// In en, this message translates to:
  /// **'Scheduled time'**
  String get tournamentScheduleLabel;

  /// Placeholder shown in a date/time field before a value is picked
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get tournamentPickPrompt;

  /// Submit button on the create-tournament form
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get tournamentCreateButton;

  /// Validation error when the tournament name is empty
  ///
  /// In en, this message translates to:
  /// **'Enter a tournament name'**
  String get tournamentNameRequired;

  /// Facility dropdown placeholder and validation error when none is chosen
  ///
  /// In en, this message translates to:
  /// **'Select a facility'**
  String get tournamentFacilityRequired;

  /// Validation error when no scheduled time is chosen
  ///
  /// In en, this message translates to:
  /// **'Select a scheduled time'**
  String get tournamentScheduleRequired;

  /// Validation error when the registration deadline is not in the future
  ///
  /// In en, this message translates to:
  /// **'The deadline must be in the future'**
  String get tournamentDeadlineFuture;

  /// Validation error when the deadline is after the scheduled time
  ///
  /// In en, this message translates to:
  /// **'The deadline must be on or before the scheduled time'**
  String get tournamentDeadlineBeforeSchedule;

  /// SnackBar error shown when creating a tournament fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the tournament. Try again.'**
  String get tournamentCreateError;

  /// Error message shown when the bracket screen fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the tournament.'**
  String get tournamentLoadError;

  /// Title of the bracket placeholder shown while a tournament is still registering
  ///
  /// In en, this message translates to:
  /// **'Registration open'**
  String get tournamentRegistrationOpenTitle;

  /// Body of the bracket placeholder shown while a tournament is still registering
  ///
  /// In en, this message translates to:
  /// **'The bracket appears once seeding closes at the registration deadline, or sooner if it fills first.'**
  String get tournamentRegistrationOpenBody;

  /// Title of the bracket placeholder shown when a tournament was cancelled
  ///
  /// In en, this message translates to:
  /// **'Tournament cancelled'**
  String get tournamentCancelledTitle;

  /// Body of the bracket placeholder shown when a tournament was cancelled
  ///
  /// In en, this message translates to:
  /// **'Not enough players joined before the registration deadline.'**
  String get tournamentCancelledBody;

  /// Banner announcing the champion on a completed tournament's bracket
  ///
  /// In en, this message translates to:
  /// **'{name} won the tournament!'**
  String tournamentCompletedBanner(String name);

  /// Label for an empty bracket position the opponent advances past
  ///
  /// In en, this message translates to:
  /// **'BYE'**
  String get bracketBye;

  /// Bracket column header for a 32-player round
  ///
  /// In en, this message translates to:
  /// **'Round of 32'**
  String get roundOf32;

  /// Bracket column header for a 16-player round
  ///
  /// In en, this message translates to:
  /// **'Round of 16'**
  String get roundOf16;

  /// Bracket column header for the quarterfinal round
  ///
  /// In en, this message translates to:
  /// **'Quarterfinals'**
  String get roundQuarterfinal;

  /// Bracket column header for the semifinal round
  ///
  /// In en, this message translates to:
  /// **'Semifinals'**
  String get roundSemifinal;

  /// Bracket column header for the final round
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get roundFinal;

  /// Tournaments browser app-bar title
  ///
  /// In en, this message translates to:
  /// **'Tournaments'**
  String get tournamentsTitle;

  /// Tooltip for the trophy entry-point button in the Home app bar
  ///
  /// In en, this message translates to:
  /// **'Tournaments'**
  String get tournamentsTooltip;

  /// Section header for registering/seeded tournaments
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tournamentsUpcoming;

  /// Section header for active tournaments
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get tournamentsOngoing;

  /// Empty-state title on the tournaments browser
  ///
  /// In en, this message translates to:
  /// **'No tournaments yet'**
  String get tournamentsEmptyTitle;

  /// Empty-state body on the tournaments browser
  ///
  /// In en, this message translates to:
  /// **'New tournaments for this sport will show up here.'**
  String get tournamentsEmptyBody;

  /// Error state on the tournaments browser
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load tournaments.'**
  String get tournamentsLoadError;

  /// Schedule-line label for a tournament scheduled today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tournamentToday;

  /// Schedule-line label for a tournament scheduled tomorrow
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tournamentTomorrow;

  /// Register button on a tournament card
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get tournamentRegister;

  /// Disabled button state once the user has registered
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get tournamentRegistered;

  /// Disabled button state when the tournament is at capacity
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get tournamentFull;

  /// Status pill: open for registration
  ///
  /// In en, this message translates to:
  /// **'Registering'**
  String get tournamentStatusRegistering;

  /// Status pill: bracket drawn, ready to play
  ///
  /// In en, this message translates to:
  /// **'Seeded'**
  String get tournamentStatusSeeded;

  /// Status pill: tournament underway
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tournamentStatusActive;

  /// Status pill: tournament finished
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tournamentStatusCompleted;

  /// Status pill: tournament called off
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get tournamentStatusCancelled;

  /// Confirmation snackbar after registering
  ///
  /// In en, this message translates to:
  /// **'You\'re registered.'**
  String get tournamentRegisteredSnack;

  /// Error snackbar when registration fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t register right now. Try again.'**
  String get tournamentRegisterError;

  /// Standings section header on the tournament detail
  ///
  /// In en, this message translates to:
  /// **'Standings'**
  String get tournamentStandings;

  /// Organizer controls section header
  ///
  /// In en, this message translates to:
  /// **'Organizer controls'**
  String get tournamentOrganizerControls;

  /// Organizer button: pick the winner of a playable slot
  ///
  /// In en, this message translates to:
  /// **'Advance slot'**
  String get tournamentAdvanceSlot;

  /// Organizer button: mark a player as forfeited
  ///
  /// In en, this message translates to:
  /// **'Mark forfeit'**
  String get tournamentMarkForfeit;

  /// Button opening the live bracket screen
  ///
  /// In en, this message translates to:
  /// **'Bracket'**
  String get tournamentBracket;

  /// Error state on the tournament detail screen
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this tournament.'**
  String get tournamentDetailError;

  /// Overflow-menu item to cancel a tournament (organizer, registering only)
  ///
  /// In en, this message translates to:
  /// **'Cancel tournament'**
  String get tournamentCancelAction;

  /// Cancel-tournament confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Cancel this tournament?'**
  String get tournamentCancelTitle;

  /// Cancel-tournament confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'Registered players will be notified it\'s off. This can\'t be undone.'**
  String get tournamentCancelBody;

  /// Confirm action of the cancel-tournament dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel tournament'**
  String get tournamentCancelConfirm;

  /// Dismiss action of the cancel-tournament dialog
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get tournamentCancelDismiss;

  /// Title of the mark-forfeit bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Mark a player as forfeited'**
  String get tournamentForfeitTitle;

  /// Title of the advance-slot bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Advance a slot'**
  String get tournamentAdvanceTitle;

  /// Prompt to pick the winner of a chosen slot
  ///
  /// In en, this message translates to:
  /// **'Who won {slot}?'**
  String tournamentAdvancePickWinner(String slot);

  /// A bracket slot pairing label
  ///
  /// In en, this message translates to:
  /// **'{playerA} vs {playerB}'**
  String tournamentSlotVs(String playerA, String playerB);

  /// Empty state of the advance-slot sheet
  ///
  /// In en, this message translates to:
  /// **'No slots are ready to advance yet.'**
  String get tournamentNoPlayableSlots;

  /// Empty state of the mark-forfeit sheet
  ///
  /// In en, this message translates to:
  /// **'No active players to forfeit.'**
  String get tournamentNoAliveParticipants;

  /// Title/label for a pending direct challenge (design 'pending')
  ///
  /// In en, this message translates to:
  /// **'Pending challenge'**
  String get challengePendingTitle;

  /// Subtitle on an incoming challenge card: who challenged the user and to which sport
  ///
  /// In en, this message translates to:
  /// **'challenged you to {sport}'**
  String challengeChallengedYou(String sport);

  /// Accept button on an incoming challenge card
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get challengeAccept;

  /// Decline button on an incoming challenge card
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get challengeDecline;

  /// Tooltip for the round accept (check) icon button
  ///
  /// In en, this message translates to:
  /// **'Accept challenge'**
  String get challengeAcceptTooltip;

  /// Tooltip for the round decline (close) icon button
  ///
  /// In en, this message translates to:
  /// **'Decline challenge'**
  String get challengeDeclineTooltip;

  /// Tooltip for the challenge action on a friends-list row
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get challengeButtonTooltip;

  /// Title of the send-challenge bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Challenge {name}'**
  String challengeSheetTitle(String name);

  /// Prompt above the sport chips in the send-challenge sheet
  ///
  /// In en, this message translates to:
  /// **'Choose a sport'**
  String get challengeSheetPickSport;

  /// Send button in the send-challenge sheet
  ///
  /// In en, this message translates to:
  /// **'Send challenge'**
  String get challengeSheetSend;

  /// Confirmation snackbar after sending a challenge
  ///
  /// In en, this message translates to:
  /// **'Challenge sent to {name}.'**
  String challengeSentSnack(String name);

  /// Send error when a pending challenge for the same friend and sport already exists
  ///
  /// In en, this message translates to:
  /// **'You already have a pending challenge with them for this sport.'**
  String get challengeErrorDuplicate;

  /// Send error when the recipient is not in the user's friends
  ///
  /// In en, this message translates to:
  /// **'You can only challenge friends.'**
  String get challengeErrorNotFriends;

  /// Generic send-challenge failure
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the challenge. Try again.'**
  String get challengeErrorGeneric;

  /// Error shown when accepting/declining a challenge that had already lapsed past its timeout (it leaves the inbox)
  ///
  /// In en, this message translates to:
  /// **'This challenge has expired.'**
  String get challengeActionExpired;

  /// Error shown when accepting/declining a challenge fails to write (offline or a transient error) — the action is retryable
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t respond right now. Check your connection and try again.'**
  String get challengeActionUnavailable;

  /// Error shown when accepting/declining a challenge that was already resolved by the other side or removed (a race)
  ///
  /// In en, this message translates to:
  /// **'This challenge is no longer available.'**
  String get challengeActionNoLongerAvailable;

  /// In-app alert when a new incoming challenge arrives while foregrounded
  ///
  /// In en, this message translates to:
  /// **'New challenge from {name}.'**
  String challengeReceivedSnack(String name);

  /// Small header above the list of challenges the user has sent
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get challengeOutgoingSectionTitle;

  /// Counterpart label on an outgoing challenge row
  ///
  /// In en, this message translates to:
  /// **'vs {name}'**
  String challengeOutgoingLabel(String name);

  /// Status chip for an outgoing challenge still pending a response
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get challengeStatusWaiting;

  /// Status chip for an accepted challenge
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get challengeStatusAccepted;

  /// Status chip for a declined challenge
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get challengeStatusDeclined;

  /// Status chip for an expired challenge
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get challengeStatusExpired;

  /// Fallback name when a challenge counterpart's profile can't be resolved
  ///
  /// In en, this message translates to:
  /// **'A player'**
  String get challengePlayerFallback;

  /// App bar title of the challenge detail screen
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get challengeScreenTitle;

  /// Sender's waiting state on the challenge detail screen
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name}'**
  String challengeWaitingTitle(String name);

  /// Body of the sender's waiting state
  ///
  /// In en, this message translates to:
  /// **'They\'ll see your challenge in the app.'**
  String get challengeWaitingBody;

  /// CTA that opens the QR scanner after a challenge is accepted
  ///
  /// In en, this message translates to:
  /// **'Scan to play'**
  String get challengeScanToPlay;

  /// Inline message after accepting, prompting the standard QR check-in
  ///
  /// In en, this message translates to:
  /// **'Challenge accepted — scan the table QR to start.'**
  String get challengeAcceptedCta;

  /// Empty state when a challenge deep-link resolves to no document
  ///
  /// In en, this message translates to:
  /// **'Challenge not found.'**
  String get challengeNotFound;

  /// Error state on the challenge detail screen
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this challenge.'**
  String get challengeLoadError;

  /// Name of the first-victory achievement badge
  ///
  /// In en, this message translates to:
  /// **'First Victory'**
  String get achievement_first_victory_name;

  /// Description of the first-victory achievement badge
  ///
  /// In en, this message translates to:
  /// **'Win your first ranked match.'**
  String get achievement_first_victory_desc;

  /// Name of the 5-win-streak achievement badge
  ///
  /// In en, this message translates to:
  /// **'On Fire'**
  String get achievement_streak_5_name;

  /// Description of the 5-win-streak achievement badge
  ///
  /// In en, this message translates to:
  /// **'Win 5 ranked matches in a row.'**
  String get achievement_streak_5_desc;

  /// Name of the giant-slayer achievement badge
  ///
  /// In en, this message translates to:
  /// **'Giant Slayer'**
  String get achievement_giant_slayer_name;

  /// Description of the giant-slayer achievement badge
  ///
  /// In en, this message translates to:
  /// **'Beat an opponent rated 200+ ELO above you.'**
  String get achievement_giant_slayer_desc;

  /// Name of the explorer achievement badge
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get achievement_explorer_name;

  /// Description of the explorer achievement badge
  ///
  /// In en, this message translates to:
  /// **'Play at least once at every facility on campus.'**
  String get achievement_explorer_desc;

  /// Name of the tournament-champion achievement badge
  ///
  /// In en, this message translates to:
  /// **'Champion'**
  String get achievement_tournament_champion_name;

  /// Description of the tournament-champion achievement badge
  ///
  /// In en, this message translates to:
  /// **'Win an official tournament.'**
  String get achievement_tournament_champion_desc;

  /// Name of the workaholic achievement badge
  ///
  /// In en, this message translates to:
  /// **'Workaholic'**
  String get achievement_workaholic_name;

  /// Description of the workaholic achievement badge
  ///
  /// In en, this message translates to:
  /// **'Play 15 matches in a single month.'**
  String get achievement_workaholic_desc;

  /// Section header for the achievement badge grid on the profile
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get profileAchievementsTitle;

  /// System message shown when tapping an earned badge in the profile grid
  ///
  /// In en, this message translates to:
  /// **'Unlocked {date}'**
  String achievementUnlockedOn(String date);

  /// System message shown when tapping a locked badge in the profile grid
  ///
  /// In en, this message translates to:
  /// **'Unlock by: {description}'**
  String achievementUnlockHint(String description);

  /// Headline of the in-app badge reveal on the match summary
  ///
  /// In en, this message translates to:
  /// **'Achievement unlocked!'**
  String get achievementUnlockHeadline;

  /// Overflow menu action that clears the current chat session
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get chatbotClearChat;

  /// Tooltip for the settings (gear) icon button on the chat app bar
  ///
  /// In en, this message translates to:
  /// **'Assistant settings'**
  String get chatbotSettingsTooltip;

  /// Greeting bubble shown when the chat is first opened
  ///
  /// In en, this message translates to:
  /// **'Hi! Ask me about empty tables, today\'s tournaments, ELO, or your queue position.'**
  String get chatbotGreeting;

  /// Placeholder text in the chat input field
  ///
  /// In en, this message translates to:
  /// **'Ask Arena Assistant...'**
  String get chatbotInputHint;

  /// Accessibility label for the send button
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatbotSend;

  /// Pill shown under the app bar when no API key is configured or the device is offline
  ///
  /// In en, this message translates to:
  /// **'Limited mode - basic answers only'**
  String get chatbotLimitedModeBadge;

  /// Error bubble text shown when the assistant fails to respond
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t reach the assistant — showing basic answers.'**
  String get chatbotErrorMessage;

  /// Retry button on an error bubble
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get chatbotRetry;

  /// Suggested-question chip label
  ///
  /// In en, this message translates to:
  /// **'What tables are empty?'**
  String get chatbotChipEmptyTables;

  /// Suggested-question chip label
  ///
  /// In en, this message translates to:
  /// **'Tournaments today'**
  String get chatbotChipTournamentsToday;

  /// Suggested-question chip label
  ///
  /// In en, this message translates to:
  /// **'How does ELO work?'**
  String get chatbotChipHowElo;

  /// Suggested-question chip label
  ///
  /// In en, this message translates to:
  /// **'Where am I in the queue?'**
  String get chatbotChipQueuePosition;

  /// Button on a facility availability card that deep-links to the map
  ///
  /// In en, this message translates to:
  /// **'Open Map'**
  String get chatbotOpenMap;

  /// Button on a tournament card that opens the tournament detail
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get chatbotViewTournament;

  /// Button that dismisses the first-open disclaimer info banner
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get chatbotDismissBanner;

  /// Title of the Home tab entry point card/button that opens the chatbot
  ///
  /// In en, this message translates to:
  /// **'Arena Assistant'**
  String get chatbotHomeEntryTitle;

  /// Subtitle of the Home tab entry point card that opens the chatbot
  ///
  /// In en, this message translates to:
  /// **'Ask about tables, tournaments, and ELO'**
  String get chatbotHomeEntrySubtitle;

  /// One-line disclaimer appended to the mini-tutorial's map/queue step
  ///
  /// In en, this message translates to:
  /// **'Availability reflects app activity only — not a live guarantee, and not a reservation.'**
  String get tutorialSlide3Disclaimer;

  /// App bar title on the Assistant Settings screen
  ///
  /// In en, this message translates to:
  /// **'Assistant Settings'**
  String get chatbotSettingsTitle;

  /// Label for the LLM provider dropdown
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get chatbotSettingsProviderLabel;

  /// Label for the API key text field
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get chatbotSettingsApiKeyLabel;

  /// Label for the model id text field
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get chatbotSettingsModelLabel;

  /// Tooltip for the icon that reveals the obscured API key field
  ///
  /// In en, this message translates to:
  /// **'Show API key'**
  String get chatbotSettingsShowKey;

  /// Tooltip for the icon that re-obscures the API key field
  ///
  /// In en, this message translates to:
  /// **'Hide API key'**
  String get chatbotSettingsHideKey;

  /// Button that fires a minimal request to verify the API key
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get chatbotSettingsTestConnection;

  /// Button that persists the assistant settings
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get chatbotSettingsSave;

  /// Confirmation snackbar/message after saving assistant settings
  ///
  /// In en, this message translates to:
  /// **'Assistant settings saved'**
  String get chatbotSettingsSaved;

  /// Feedback shown when testConnection succeeds
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get chatbotSettingsTestSuccess;

  /// Prefix shown before the mapped error reason when testConnection fails
  ///
  /// In en, this message translates to:
  /// **'Connection failed:'**
  String get chatbotSettingsTestFailurePrefix;

  /// Banner/pill in the chat screen linking to Assistant Settings when unconfigured
  ///
  /// In en, this message translates to:
  /// **'No API key configured — the assistant answers in limited mode. Add a key to enable full AI answers.'**
  String get chatbotSettingsNoKeyBanner;

  /// Prompt shown when the user switches provider and had a custom model value
  ///
  /// In en, this message translates to:
  /// **'Reset the model field to this provider\'s default?'**
  String get chatbotSettingsResetModelPrompt;

  /// Confirms resetting the model field to the new provider's default
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get chatbotSettingsResetModelYes;

  /// Keeps the current model field value after switching provider
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get chatbotSettingsResetModelNo;

  /// Localized error text for an HTTP 401/403 from the LLM provider
  ///
  /// In en, this message translates to:
  /// **'That API key was rejected. Double-check it and try again.'**
  String get chatbotErrorInvalidApiKey;

  /// Localized error text for an HTTP 429 from the LLM provider
  ///
  /// In en, this message translates to:
  /// **'The provider is rate-limiting requests right now. Try again shortly.'**
  String get chatbotErrorRateLimited;

  /// Localized error text for a network/socket failure calling the LLM provider
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the network. Check your connection and try again.'**
  String get chatbotErrorNetwork;

  /// Localized error text when Test Connection is tapped with no API key entered
  ///
  /// In en, this message translates to:
  /// **'Add an API key first.'**
  String get chatbotErrorMissingApiKey;

  /// Fallback localized error text for any other assistant/provider failure
  ///
  /// In en, this message translates to:
  /// **'Something went wrong reaching the assistant.'**
  String get chatbotErrorGeneric;

  /// Localized error text when the LLM request times out
  ///
  /// In en, this message translates to:
  /// **'The assistant took too long to respond. Try again.'**
  String get chatbotErrorTimeout;

  /// Rule-based (limited-mode) answer when no facilities are free
  ///
  /// In en, this message translates to:
  /// **'No tables are currently free based on app activity.'**
  String get chatbotAnswerNoFreeTables;

  /// Rule-based (limited-mode) answer listing the free tables
  ///
  /// In en, this message translates to:
  /// **'Free right now: {names}.'**
  String chatbotAnswerFreeTables(String names);

  /// Rule-based (limited-mode) answer when no tournaments are scheduled today
  ///
  /// In en, this message translates to:
  /// **'There are no tournaments scheduled for today.'**
  String get chatbotAnswerNoTournaments;

  /// Rule-based (limited-mode) answer listing today's tournaments (each item already formatted as 'Name (count/max)')
  ///
  /// In en, this message translates to:
  /// **'Today\'s tournaments: {names}.'**
  String chatbotAnswerTournamentsToday(String names);

  /// Rule-based (limited-mode) answer when the user is not queued anywhere
  ///
  /// In en, this message translates to:
  /// **'You\'re not currently in any queue.'**
  String get chatbotAnswerQueueNone;

  /// Rule-based (limited-mode) answer giving the user's queue position
  ///
  /// In en, this message translates to:
  /// **'You\'re at position {position} in the queue for {facility}.'**
  String chatbotAnswerQueuePosition(int position, String facility);

  /// Rule-based (limited-mode) explanation of how ELO works
  ///
  /// In en, this message translates to:
  /// **'CampusArena ELO starts every player at 1200. After each confirmed match, the winner gains points and the loser loses points based on the ELO difference between the two players (beating a higher-rated opponent earns more than beating a lower-rated one). The K-factor (how much a single match can move your rating) is 32 for your first 10 matches in a sport, then drops to 16 once you are established. Ratings are tracked separately per sport (Ping Pong, Foosball). Ratings can also lazily decay after long inactivity.'**
  String get chatbotAnswerEloExplainer;

  /// Rule-based (limited-mode) line stating the user's current Ping Pong ELO and match count
  ///
  /// In en, this message translates to:
  /// **'Your current Ping Pong ELO is {elo} after {matches} matches.'**
  String chatbotAnswerYourElo(int elo, int matches);

  /// Rule-based (limited-mode) line stating the user's current Ping Pong ELO, leaderboard rank, and match count
  ///
  /// In en, this message translates to:
  /// **'Your current Ping Pong ELO is {elo}, ranked #{rank}, after {matches} matches.'**
  String chatbotAnswerYourEloRanked(int elo, int rank, int matches);

  /// Rule-based (limited-mode) fallback answer for an unrecognized question
  ///
  /// In en, this message translates to:
  /// **'I can help with empty tables, today\'s tournaments, ELO, and your queue position. Try one of the suggested questions below, or ask me directly.'**
  String get chatbotAnswerGeneral;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
