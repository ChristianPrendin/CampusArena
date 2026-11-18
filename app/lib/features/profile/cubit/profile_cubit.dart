import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants.dart';
import '../../../core/match_display.dart';
import '../../../models/match_model.dart';
import '../../../models/rating_model.dart';
import '../../../models/user_model.dart';
import '../../../repositories/achievement_repository.dart';
import '../../../repositories/facility_repository.dart';
import '../../../repositories/match_repository.dart';
import '../../../repositories/rating_repository.dart';
import '../../../repositories/user_repository.dart';
import '../profile_stats.dart';
import 'profile_state.dart';

/// Signature of the stats-derivation runner — injectable so tests can bypass
/// the isolate; production uses [ProfileCubit.computeDerivation].
typedef DeriveProfileStats =
    Future<ProfileDerivation> Function(ProfileDerivationInput input);

/// Drives the Profile tab for [uid] (the signed-in user, or a foreign uid for
/// the Phase 5/A public-profile reuse): streams the per-sport ratings, the
/// bounded match window, and the user document itself, and ships the heavy
/// stats/trend derivation to a real isolate via `compute()`.
///
/// Opponent/facility name lookups are fire-and-forget decorations layered onto
/// the streams (the DashboardCubit pattern); their failures never move the
/// profile to `error`. A derivation failure keeps the previous figures for the
/// same reason.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required this.uid,
    RatingRepository? ratingRepository,
    MatchRepository? matchRepository,
    UserRepository? userRepository,
    FacilityRepository? facilityRepository,
    AchievementRepository? achievementRepository,
    DeriveProfileStats? derive,
  }) : _ratingRepository = ratingRepository ?? RatingRepository(),
       _matchRepository = matchRepository ?? MatchRepository(),
       _userRepository = userRepository ?? UserRepository(),
       _facilityRepository = facilityRepository ?? FacilityRepository(),
       _achievementRepository =
           achievementRepository ?? AchievementRepository(),
       _derive = derive ?? computeDerivation,
       super(ProfileState()) {
    _subscribe();
  }

  final String uid;
  final RatingRepository _ratingRepository;
  final MatchRepository _matchRepository;
  final UserRepository _userRepository;
  final FacilityRepository _facilityRepository;
  final AchievementRepository _achievementRepository;
  final DeriveProfileStats _derive;

  /// Spark-tier bound on the history window, served by the existing
  /// `(playerUids, startedAt)` composite index.
  static const int _historyFetchLimit = 100;

  static const Set<String> _terminalStates = {
    MatchStates.confirmed,
    MatchStates.disputed,
    MatchStates.unconfirmed,
    MatchStates.abandoned,
  };

  /// Production derivation runner: a real isolate. `deriveProfileStats` is
  /// top-level and pure, as `compute` requires.
  static Future<ProfileDerivation> computeDerivation(
    ProfileDerivationInput input,
  ) => compute(deriveProfileStats, input);

  StreamSubscription<List<RatingModel>>? _ratingsSub;
  StreamSubscription<List<MatchModel>>? _matchesSub;
  StreamSubscription<UserModel?>? _userSub;

  bool _userLoaded = false;
  bool _ratingsLoaded = false;
  bool _matchesLoaded = false;

  /// Monotonic guard so a slow derivation for an older window can never
  /// clobber a newer one.
  int _deriveSeq = 0;

  void _subscribe() {
    _userSub = _userRepository
        .watchUser(uid)
        .listen(_onUser, onError: _onError);
    _loadAchievementDefs();
    _ratingsSub = _ratingRepository
        .watchUserRatings(uid)
        .listen(_onRatings, onError: _onError);
    _matchesSub = _matchRepository
        .watchUserMatches(uid, limit: _historyFetchLimit)
        .listen(_onMatches, onError: _onError);
  }

  /// Best-effort load of the badge grid definitions. Decorative and independent
  /// of [ProfileStatus]: a failure just leaves the grid hidden, never errors the
  /// profile (the decorative-lookup rule).
  Future<void> _loadAchievementDefs() async {
    try {
      final defs = await _achievementRepository.getDefinitions();
      if (isClosed || defs.isEmpty) return;
      emit(state.copyWith(achievementDefs: defs));
    } catch (_) {
      // Grid stays hidden.
    }
  }

  ProfileStatus get _computedStatus {
    if (state.status == ProfileStatus.error) return ProfileStatus.error;
    return (_userLoaded && _ratingsLoaded && _matchesLoaded)
        ? ProfileStatus.ready
        : ProfileStatus.loading;
  }

  /// Live, not one-shot: the Profile tab's cubit survives tab switches under
  /// `StatefulShellRoute` (its branch Navigator is kept alive, not rebuilt), so
  /// a one-shot fetch would only ever reflect the doc as of cubit creation —
  /// newly-earned badges (or any other user-doc change) wouldn't appear until
  /// the app itself restarted. Streaming keeps `state.user.badges` current.
  void _onUser(UserModel? user) {
    if (user == null) {
      emit(state.copyWith(status: ProfileStatus.error));
      return;
    }
    _userLoaded = true;
    emit(state.copyWith(user: user, status: _computedStatus));
  }

  void _onRatings(List<RatingModel> ratings) {
    final ordered = [
      for (final sportId in SportIds.supported)
        ...ratings.where((r) => r.sportId == sportId),
    ];
    _ratingsLoaded = true;
    emit(state.copyWith(ratings: ordered, status: _computedStatus));
  }

  Future<void> _onMatches(List<MatchModel> all) async {
    final seq = ++_deriveSeq;
    var derivation = state.derivation;
    try {
      derivation = await _derive(
        ProfileDerivationInput(uid: uid, matches: all),
      );
    } catch (_) {
      // Keep the previous figures; the history list below still refreshes.
    }
    if (isClosed || seq != _deriveSeq) return;

    final history = all
        .where((m) => _terminalStates.contains(m.state))
        .toList();
    _matchesLoaded = true;
    emit(
      state.copyWith(
        matches: history,
        derivation: derivation,
        status: _computedStatus,
      ),
    );
    _resolveOpponentNames(history);
    _resolveFacilityNames(history);
  }

  Future<void> _resolveOpponentNames(List<MatchModel> matches) async {
    final unknown = <String>{for (final m in matches) ...opponentUids(m, uid)}
      ..removeWhere(state.opponentNames.containsKey);
    if (unknown.isEmpty) return;
    try {
      final users = await Future.wait(unknown.map(_userRepository.getUser));
      if (isClosed) return;
      final resolved = {
        for (final u in users)
          if (u != null) u.uid: u.username,
      };
      if (resolved.isEmpty) return;
      emit(
        state.copyWith(opponentNames: {...state.opponentNames, ...resolved}),
      );
    } catch (_) {
      // Names are decorative: rows fall back to the sport-name title.
    }
  }

  Future<void> _resolveFacilityNames(List<MatchModel> matches) async {
    final unknown = <String>{for (final m in matches) m.facilityId}
      ..removeWhere(state.facilityNames.containsKey);
    if (unknown.isEmpty) return;
    try {
      final facilities = await Future.wait(
        unknown.map(_facilityRepository.getFacility),
      );
      if (isClosed) return;
      final resolved = {
        for (final f in facilities)
          if (f != null) f.facilityId: f.name,
      };
      if (resolved.isEmpty) return;
      emit(
        state.copyWith(facilityNames: {...state.facilityNames, ...resolved}),
      );
    } catch (_) {
      // Facility names are decorative: rows omit them until resolved.
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    emit(state.copyWith(status: ProfileStatus.error));
  }

  /// Focuses the trend card, stat tiles, and fun-stat cards on [sportId].
  /// No-op if already selected; all sports are pre-derived, so switching is
  /// instant with no refetch.
  void selectSport(String sportId) {
    if (sportId == state.selectedSportId) return;
    emit(state.copyWith(selectedSportId: sportId));
  }

  /// Tears down and re-establishes the streams and the user fetch after an
  /// error.
  void retry() {
    _userSub?.cancel();
    _ratingsSub?.cancel();
    _matchesSub?.cancel();
    _userLoaded = false;
    _ratingsLoaded = false;
    _matchesLoaded = false;
    // Preserve the sport the user was viewing across the reload.
    emit(ProfileState(selectedSportId: state.selectedSportId));
    _subscribe();
  }

  @override
  Future<void> close() {
    _userSub?.cancel();
    _ratingsSub?.cancel();
    _matchesSub?.cancel();
    return super.close();
  }
}
