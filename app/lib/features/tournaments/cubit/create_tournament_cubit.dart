import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants.dart';
import '../../../core/elo/elo_calculator.dart';
import '../../../models/facility_model.dart';
import '../../../models/tournament_model.dart';
import '../../../repositories/facility_repository.dart';
import '../../../repositories/tournament_repository.dart';
import 'create_tournament_state.dart';

/// Drives the create-tournament form: holds the editable fields, streams the
/// facility list (filtered to the selected sport for the dropdown), and writes
/// the `registering` tournament on submit.
///
/// Synchronous initial state; the facility subscription is started via
/// [loadFacilities] after construction (no constructor side effects).
class CreateTournamentCubit extends Cubit<CreateTournamentState> {
  CreateTournamentCubit({
    required this.organizerId,
    TournamentRepository? tournamentRepository,
    FacilityRepository? facilityRepository,
  }) : _tournamentRepository = tournamentRepository ?? TournamentRepository(),
       _facilityRepository = facilityRepository ?? FacilityRepository(),
       super(const CreateTournamentState());

  final String organizerId;
  final TournamentRepository _tournamentRepository;
  final FacilityRepository _facilityRepository;

  /// Stepper bounds (inclusive) for the participant cap.
  static const int participantsMin = 4;
  static const int participantsMax = 32;

  StreamSubscription<List<FacilityModel>>? _facilitiesSub;
  List<FacilityModel> _allFacilities = const [];

  /// Subscribes to the facility list; each emission re-filters to the current
  /// sport for the dropdown.
  void loadFacilities() {
    _facilitiesSub?.cancel();
    _facilitiesSub = _facilityRepository.watchFacilities().listen((all) {
      _allFacilities = all;
      emit(state.copyWith(facilities: _forSport(state.sportId)));
    });
  }

  List<FacilityModel> _forSport(String sportId) =>
      _allFacilities.where((f) => f.sportId == sportId).toList();

  void setName(String name) => emit(state.copyWith(name: name));

  void setSport(String sportId) {
    if (sportId == state.sportId) return;
    final facilities = _forSport(sportId);
    // Drop a facility that doesn't belong to the newly selected sport.
    final keep = facilities.any((f) => f.facilityId == state.facilityId);
    emit(
      state.copyWith(
        sportId: sportId,
        facilities: facilities,
        facilityId: () => keep ? state.facilityId : null,
      ),
    );
  }

  void setFacility(String facilityId) =>
      emit(state.copyWith(facilityId: () => facilityId));

  void incrementMax() {
    if (state.maxParticipants >= participantsMax) return;
    emit(state.copyWith(maxParticipants: state.maxParticipants + 1));
  }

  void decrementMax() {
    if (state.maxParticipants <= participantsMin) return;
    emit(state.copyWith(maxParticipants: state.maxParticipants - 1));
  }

  void setDeadline(DateTime deadline) =>
      emit(state.copyWith(registrationDeadline: deadline));

  void setScheduledAt(DateTime scheduledAt) =>
      emit(state.copyWith(scheduledAt: scheduledAt));

  /// Validates and, if the form is sound, writes the tournament as
  /// `registering` with an empty bracket and the default 1.5 ELO multiplier.
  /// Emits [CreateTournamentStatus.success] (the screen pops) or
  /// [CreateTournamentStatus.failure] carrying the offending
  /// [CreateTournamentError]. [now] is injectable for tests.
  Future<void> submit({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final error = _validate(effectiveNow);
    if (error != null) {
      emit(
        state.copyWith(
          status: CreateTournamentStatus.failure,
          error: () => error,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: CreateTournamentStatus.submitting,
        error: () => null,
      ),
    );
    try {
      await _tournamentRepository.createTournament(
        TournamentModel(
          tournamentId: '',
          name: state.name.trim(),
          sportId: state.sportId,
          facilityId: state.facilityId!,
          organizerId: organizerId,
          maxParticipants: state.maxParticipants,
          status: TournamentStatus.registering,
          bracket: const {},
          eloMultiplier: EloCalculator.defaultTournamentMultiplier,
          registrationDeadline: state.registrationDeadline!,
          scheduledAt: state.scheduledAt!,
          createdAt: effectiveNow,
        ),
      );
      if (isClosed) return;
      emit(state.copyWith(status: CreateTournamentStatus.success));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CreateTournamentStatus.failure,
          error: () => CreateTournamentError.createFailed,
        ),
      );
    }
  }

  CreateTournamentError? _validate(DateTime now) {
    if (state.name.trim().isEmpty) return CreateTournamentError.name;
    if (state.facilityId == null) return CreateTournamentError.facility;
    final deadline = state.registrationDeadline;
    final scheduled = state.scheduledAt;
    if (deadline == null || !deadline.isAfter(now)) {
      return CreateTournamentError.deadlineFuture;
    }
    if (scheduled == null) return CreateTournamentError.schedule;
    if (deadline.isAfter(scheduled)) return CreateTournamentError.deadlineOrder;
    return null;
  }

  @override
  Future<void> close() {
    _facilitiesSub?.cancel();
    return super.close();
  }
}
