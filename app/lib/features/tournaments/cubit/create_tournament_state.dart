import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants.dart';
import '../../../models/facility_model.dart';

enum CreateTournamentStatus { editing, submitting, success, failure }

/// Which validation guard (or the create call itself) rejected a submit — the
/// screen maps this to the localized SnackBar copy so the cubit stays free of
/// UI strings.
enum CreateTournamentError {
  name,
  facility,
  schedule,
  deadlineFuture,
  deadlineOrder,
  createFailed,
}

/// Form state for the create-tournament screen. [facilities] is already
/// filtered to the selected [sportId] (the dropdown's items). The initial
/// state is fully synchronous — facilities stream in via
/// `CreateTournamentCubit.loadFacilities`.
class CreateTournamentState extends Equatable {
  const CreateTournamentState({
    this.name = '',
    this.sportId = SportIds.pingPong,
    this.facilityId,
    this.maxParticipants = 16,
    this.registrationDeadline,
    this.scheduledAt,
    this.facilities = const [],
    this.status = CreateTournamentStatus.editing,
    this.error,
  });

  final String name;
  final String sportId;
  final String? facilityId;
  final int maxParticipants;
  final DateTime? registrationDeadline;
  final DateTime? scheduledAt;
  final List<FacilityModel> facilities;
  final CreateTournamentStatus status;
  final CreateTournamentError? error;

  CreateTournamentState copyWith({
    String? name,
    String? sportId,
    ValueGetter<String?>? facilityId,
    int? maxParticipants,
    DateTime? registrationDeadline,
    DateTime? scheduledAt,
    List<FacilityModel>? facilities,
    CreateTournamentStatus? status,
    ValueGetter<CreateTournamentError?>? error,
  }) {
    return CreateTournamentState(
      name: name ?? this.name,
      sportId: sportId ?? this.sportId,
      facilityId: facilityId != null ? facilityId() : this.facilityId,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      facilities: facilities ?? this.facilities,
      status: status ?? this.status,
      error: error != null ? error() : this.error,
    );
  }

  @override
  List<Object?> get props => [
    name,
    sportId,
    facilityId,
    maxParticipants,
    registrationDeadline,
    scheduledAt,
    facilities,
    status,
    error,
  ];
}
