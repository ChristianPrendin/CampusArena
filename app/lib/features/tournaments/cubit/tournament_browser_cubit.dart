import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants.dart';
import '../../../models/tournament_model.dart';
import '../../../repositories/facility_repository.dart';
import '../../../repositories/tournament_repository.dart';
import 'tournament_browser_state.dart';

/// Drives the tournament browser: streams the feed for the selected sport,
/// splits it into UPCOMING (`registering`/`seeded`) and ONGOING (`active`)
/// sorted by `scheduledAt`, and resolves per-card enrichment (participant
/// count, whether the user registered, facility outdoor flag) behind an in-cubit
/// cache. Enrichment is fire-and-forget: its failures never move to `error`.
///
/// The constructor is side-effect free (synchronous initial state); [init]
/// starts the subscription.
class TournamentBrowserCubit extends Cubit<TournamentBrowserState> {
  TournamentBrowserCubit({
    TournamentRepository? tournamentRepository,
    FacilityRepository? facilityRepository,
  }) : _tournamentRepo = tournamentRepository ?? TournamentRepository(),
       _facilityRepo = facilityRepository ?? FacilityRepository(),
       super(TournamentBrowserState());

  final TournamentRepository _tournamentRepo;
  final FacilityRepository _facilityRepo;

  /// Statuses that make up the UPCOMING section (registering + seeded).
  static const List<String> _upcomingStatuses = <String>[
    TournamentStatus.registering,
    TournamentStatus.seeded,
  ];

  /// Statuses shown in the browser (UPCOMING + ONGOING). Kept in one `whereIn`
  /// so a single bounded query feeds both sections.
  static const List<String> _browserStatuses = <String>[
    ..._upcomingStatuses,
    TournamentStatus.active,
  ];

  StreamSubscription<List<TournamentModel>>? _sub;
  final Map<String, bool> _outdoorCache = {};

  void init() => _subscribe();

  void _subscribe() {
    _sub?.cancel();
    _sub = _tournamentRepo
        .watchTournaments(
          sportId: state.selectedSportId,
          statuses: _browserStatuses,
        )
        .listen(_onTournaments, onError: (_) => _onError());
  }

  void _onTournaments(List<TournamentModel> all) {
    int bySchedule(TournamentModel a, TournamentModel b) =>
        a.scheduledAt.compareTo(b.scheduledAt);

    final upcoming =
        all.where((t) => _upcomingStatuses.contains(t.status)).toList()
          ..sort(bySchedule);
    final ongoing =
        all.where((t) => t.status == TournamentStatus.active).toList()
          ..sort(bySchedule);

    emit(
      state.copyWith(
        status: TournamentBrowserStatus.ready,
        upcoming: upcoming,
        ongoing: ongoing,
      ),
    );
    _enrich([...upcoming, ...ongoing]);
  }

  /// Resolves the facility outdoor flag for each card (the participant count now
  /// rides the feed as `TournamentModel.participantCount`, so no subcollection
  /// fan-out). The outdoor flag is memoised per facility across cards and sports.
  Future<void> _enrich(List<TournamentModel> tournaments) async {
    for (final t in tournaments) {
      unawaited(_enrichOne(t));
    }
  }

  Future<void> _enrichOne(TournamentModel t) async {
    bool? outdoor = _outdoorCache[t.facilityId];
    if (outdoor == null) {
      try {
        outdoor = (await _facilityRepo.getFacility(t.facilityId))?.isOutdoor;
        if (outdoor != null) _outdoorCache[t.facilityId] = outdoor;
      } catch (_) {
        // Decorative.
      }
    }

    if (outdoor == null || isClosed) return;
    final current = state.infoFor(t.tournamentId);
    final next = current.copyWith(outdoor: outdoor);
    if (next == current) return;
    emit(state.copyWith(cardInfo: {...state.cardInfo, t.tournamentId: next}));
  }

  /// Switches the browser to [sportId]; re-subscribes the feed. No-op if already
  /// selected.
  void selectSport(String sportId) {
    if (sportId == state.selectedSportId) return;
    emit(
      state.copyWith(
        selectedSportId: sportId,
        status: TournamentBrowserStatus.loading,
        upcoming: const [],
        ongoing: const [],
      ),
    );
    _subscribe();
  }

  void _onError() =>
      emit(state.copyWith(status: TournamentBrowserStatus.error));

  void retry() {
    emit(state.copyWith(status: TournamentBrowserStatus.loading));
    _subscribe();
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
