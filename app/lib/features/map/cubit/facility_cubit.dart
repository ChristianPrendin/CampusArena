import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/facility_model.dart';
import '../../../repositories/facility_repository.dart';
import 'facility_state.dart';

/// Streams all campus facilities for the map, re-emitting on every real-time
/// status change. Read-only listener on the facility-status shared contract —
/// the match vertical is the canonical writer of `status`/`currentMatchId`.
class FacilityCubit extends Cubit<FacilityState> {
  FacilityCubit({FacilityRepository? repository})
    : _repository = repository ?? FacilityRepository(),
      super(const FacilityState());

  final FacilityRepository _repository;

  StreamSubscription<List<FacilityModel>>? _subscription;

  /// Subscribes to [FacilityRepository.watchFacilities]. Calling it again
  /// (e.g. retry after an error) replaces the previous subscription.
  void subscribe() {
    emit(state.copyWith(status: FacilityLoadStatus.loading));
    _subscription?.cancel();
    _subscription = _repository.watchFacilities().listen(
      (facilities) => emit(
        state.copyWith(
          status: FacilityLoadStatus.loaded,
          facilities: facilities,
        ),
      ),
      onError: (Object _) =>
          emit(state.copyWith(status: FacilityLoadStatus.error)),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
