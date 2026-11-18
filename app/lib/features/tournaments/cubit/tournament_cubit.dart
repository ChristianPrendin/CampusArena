import '../../../models/tournament_model.dart';
import '../../../repositories/facility_repository.dart';
import '../../../repositories/match_repository.dart';
import '../../../repositories/tournament_repository.dart';
import '../../../repositories/user_repository.dart';
import 'tournament_bracket_cubit_base.dart';
import 'tournament_state.dart';

/// Per-tournament lifecycle for the live-bracket screen. Adds, on top of the
/// shared [TournamentBracketCubitBase] streams + lazy healings, the facility
/// (for the forecast strip) and a uid → display-name cache.
///
/// Synchronous initial state; the streams are started via [load] after
/// construction (no constructor side effects — see `MatchFlowPage`).
class TournamentCubit extends TournamentBracketCubitBase<TournamentState> {
  TournamentCubit({
    required super.tournamentId,
    required this.uid,
    TournamentRepository? tournamentRepository,
    MatchRepository? matchRepository,
    UserRepository? userRepository,
    FacilityRepository? facilityRepository,
  }) : _userRepository = userRepository ?? UserRepository(),
       _facilityRepository = facilityRepository ?? FacilityRepository(),
       super(
         tournamentRepository: tournamentRepository ?? TournamentRepository(),
         matchRepository: matchRepository ?? MatchRepository(),
         initialState: const TournamentState(),
       );

  /// The signed-in user — a tap on their own playable slot deep-links into the
  /// bracket match check-in.
  final String uid;

  final UserRepository _userRepository;
  final FacilityRepository _facilityRepository;

  bool _facilityRequested = false;

  /// Starts the streams and fires the one-shot lazy seeding. [now] is injectable
  /// so tests can drive the deadline-based `seedIfDue` transition.
  void load({DateTime? now}) => start(now: now);

  @override
  void project() {
    if (hasStreamError) {
      emit(state.copyWith(status: BracketStatus.error));
      return;
    }
    emit(
      state.copyWith(
        tournament: tournamentData,
        participants: participantsData,
        matches: matchesData,
        tree: treeData,
        status: coreLoaded ? BracketStatus.ready : BracketStatus.loading,
      ),
    );
  }

  @override
  void onTournamentData(TournamentModel tournament) {
    if (!_facilityRequested) {
      _facilityRequested = true;
      _loadFacility(tournament.facilityId);
    }
  }

  @override
  void onParticipantsData(List<TournamentParticipantModel> participants) {
    _resolveNames(participants.map((p) => p.uid));
  }

  @override
  void onReset() {
    _facilityRequested = false;
  }

  Future<void> _loadFacility(String facilityId) async {
    try {
      final facility = await _facilityRepository.getFacility(facilityId);
      if (isClosed || facility == null) return;
      emit(state.copyWith(facility: facility));
    } catch (_) {
      // The forecast strip simply stays hidden if the facility can't load.
    }
  }

  Future<void> _resolveNames(Iterable<String> uids) async {
    final unknown = uids.toSet()..removeWhere(state.names.containsKey);
    if (unknown.isEmpty) return;
    try {
      final users = await _userRepository.getUsersByIds(unknown.toList());
      if (isClosed) return;
      final resolved = {for (final u in users) u.uid: u.name};
      if (resolved.isEmpty) return;
      emit(state.copyWith(names: {...state.names, ...resolved}));
    } catch (_) {
      // Names are decorative; slots fall back to a short id until resolved.
    }
  }
}
