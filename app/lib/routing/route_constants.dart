class RouteConstants {
  static const String splash = '/';
  static const String landing = '/landing';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String onboardingTutorial = '/onboarding/tutorial';
  static const String home = '/home';
  static const String map = '/map';
  static const String leaderboards = '/leaderboards';
  static const String profile = '/profile';

  /// Settings screen (feature/C-friends-settings). The profile gear only
  /// navigates here; the route + screen land with Vertical C.
  static const String settings = '/settings';
  static const String chatbot = '/chatbot';
  static const String qrScan = '/play/scan';

  /// Blind scanner locked to [sportId], used from an accepted challenge's "scan
  /// to play" so a table of the wrong sport is rejected.
  static String qrScanForSport(String sportId) => '/play/scan?sport=$sportId';

  static const String facilityPath = '/play/facility/:id';

  /// Builds the concrete facility deep-link location for [id]. The live-bracket
  /// screen appends `?tournamentId=…&round=…` so a tap on the player's own
  /// playable slot checks them into that bracket match.
  static String facility(String id) => '/play/facility/$id';

  static const String challengePath = '/challenge/:id';
  static const String chatbotSettings = '/chatbot/settings';

  /// Builds the concrete deep-link location for challenge [id] (push target /
  /// in-app navigation to the challenge detail screen).
  static String challenge(String id) => '/challenge/$id';

  /// Result-entry flow (feature/C-result-flow). The match flow only navigates
  /// here as a stub; result input/confirmation lives in Vertical C.
  static const String matchResultPath = '/match/:id/result';

  /// Public read-only profile of another player, opened from a leaderboard row.
  /// Lives outside the shell (a drill-in, not a tab).
  static const String publicProfilePath = '/profile/:uid';

  /// Builds the concrete public-profile location for [uid].
  static String publicProfile(String uid) => '/profile/$uid';

  /// Team (pair) profile, opened from a doubles leaderboard row. Lives outside
  /// the shell (a drill-in, not a tab); `pairId` is the deterministic sorted-uid
  /// join, `sportId` picks the initial doubles board.
  static const String teamProfilePath = '/team/:pairId';

  /// Builds the concrete team-profile location for [pairId], defaulting the view
  /// to [sportId].
  static String teamProfile(String pairId, {required String sportId}) =>
      '/team/$pairId?sportId=$sportId';

  /// Friends management (feature/C-friends-settings). Full-screen, outside the
  /// shell; reached from the leaderboard app-bar action.
  static const String friends = '/friends';

  static const String tournaments = '/tournaments';
  static const String tournamentCreate = '/tournaments/create';
  static const String tournamentDetailPath = '/tournaments/:id';
  static const String tournamentBracketPath = '/tournaments/:id/bracket';
  static String tournamentDetail(String id) => '/tournaments/$id';
  static String tournamentBracket(String id) => '/tournaments/$id/bracket';
}
