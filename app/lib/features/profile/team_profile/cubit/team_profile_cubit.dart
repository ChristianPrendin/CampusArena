import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants.dart';
import '../../../../core/match_display.dart';
import '../../../../models/match_model.dart';
import '../../../../models/rating_model.dart';
import '../../../../repositories/facility_repository.dart';
import '../../../../repositories/match_repository.dart';
import '../../../../repositories/rating_repository.dart';
import '../../../../repositories/user_repository.dart';
import '../../profile_stats.dart';
import 'team_profile_state.dart';

/// Signature of the team-stats runner — injectable so tests can bypass the
/// isolate; production uses [TeamProfileCubit.computeDerivation].
typedef DeriveTeamStats =
    Future<ProfileDerivation> Function(TeamDerivationInput input);

/// Drives the team (pair) profile for [pairId]: streams the pair's per-sport
/// ratings and its match history, resolves the two members + opponent/facility
/// names, and ships the stats/trend derivation to an isolate. Mirrors
/// [ProfileCubit]; the members come free from splitting the deterministic
/// pairId, so no lookup is needed to know who the team is.
class TeamProfileCubit extends Cubit<TeamProfileState> {
  TeamProfileCubit({
    required this.pairId,
    String? initialSportId,
    RatingRepository? ratingRepository,
    MatchRepository? matchRepository,
    UserRepository? userRepository,
    FacilityRepository? facilityRepository,
    DeriveTeamStats? derive,
  }) : _memberUids = pairId.split('_'),
       _ratingRepository = ratingRepository ?? RatingRepository(),
       _matchRepository = matchRepository ?? MatchRepository(),
       _userRepository = userRepository ?? UserRepository(),
       _facilityRepository = facilityRepository ?? FacilityRepository(),
       _derive = derive ?? computeDerivation,
       super(
         TeamProfileState(pairId: pairId, selectedSportId: initialSportId),
       ) {
    _subscribe();
  }

  final String pairId;
  final List<String> _memberUids;
  final RatingRepository _ratingRepository;
  final MatchRepository _matchRepository;
  final UserRepository _userRepository;
  final FacilityRepository _facilityRepository;
  final DeriveTeamStats _derive;

  static const int _historyFetchLimit = 100;

  static const Set<String> _terminalStates = {
    MatchStates.confirmed,
    MatchStates.disputed,
    MatchStates.unconfirmed,
    MatchStates.abandoned,
  };

  static Future<ProfileDerivation> computeDerivation(
    TeamDerivationInput input,
  ) => compute(deriveTeamStats, input);

  StreamSubscription<List<RatingModel>>? _ratingsSub;
  StreamSubscription<List<MatchModel>>? _matchesSub;

  bool _membersLoaded = false;
  bool _ratingsLoaded = false;
  bool _matchesLoaded = false;
  int _deriveSeq = 0;

  void _subscribe() {
    _loadMembers();
    _ratingsSub = _ratingRepository
        .watchPairRatings(pairId)
        .listen(_onRatings, onError: _onError);
    // The pair is a subset of either member's history, so query one member and
    // filter to this pair (no new index) — see watchPairMatches.
    _matchesSub = _matchRepository
        .watchPairMatches(pairId, _memberUids.first, limit: _historyFetchLimit)
        .listen(_onMatches, onError: _onError);
  }

  TeamProfileStatus get _computedStatus {
    if (state.status == TeamProfileStatus.error) return TeamProfileStatus.error;
    return (_membersLoaded && _ratingsLoaded && _matchesLoaded)
        ? TeamProfileStatus.ready
        : TeamProfileStatus.loading;
  }

  Future<void> _loadMembers() async {
    try {
      final users = await Future.wait(_memberUids.map(_userRepository.getUser));
      if (isClosed) return;
      final members = [for (final u in users) ?u];
      _membersLoaded = true;
      emit(state.copyWith(members: members, status: _computedStatus));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(status: TeamProfileStatus.error));
    }
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
        TeamDerivationInput(
          pairId: pairId,
          memberUids: _memberUids,
          matches: all,
        ),
      );
    } catch (_) {
      // Keep the previous figures; the history list still refreshes.
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
    // History is rendered from one member's perspective, so opponents are the
    // opposing pair for each match.
    final me = _memberUids.first;
    final unknown = <String>{for (final m in matches) ...opponentUids(m, me)}
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
      // Names are decorative.
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
      // Facility names are decorative.
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    emit(state.copyWith(status: TeamProfileStatus.error));
  }

  /// Focuses the trend card and stat tiles on [sportId]. All sports are
  /// pre-derived, so switching is instant with no refetch.
  void selectSport(String sportId) {
    if (sportId == state.selectedSportId) return;
    emit(state.copyWith(selectedSportId: sportId));
  }

  void retry() {
    _ratingsSub?.cancel();
    _matchesSub?.cancel();
    _membersLoaded = false;
    _ratingsLoaded = false;
    _matchesLoaded = false;
    emit(
      TeamProfileState(pairId: pairId, selectedSportId: state.selectedSportId),
    );
    _subscribe();
  }

  @override
  Future<void> close() {
    _ratingsSub?.cancel();
    _matchesSub?.cancel();
    return super.close();
  }
}
