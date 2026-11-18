import 'package:equatable/equatable.dart';

import '../../../models/facility_model.dart';

/// Lifecycle of the facility stream subscription. Named to avoid clashing
/// with [FacilityStatus] (the schema's free/occupied/queued strings).
enum FacilityLoadStatus { initial, loading, loaded, error }

class FacilityState extends Equatable {
  const FacilityState({
    this.status = FacilityLoadStatus.initial,
    this.facilities = const [],
  });

  final FacilityLoadStatus status;

  /// All campus facilities, live-updated while subscribed. Kept across an
  /// error so the map can keep showing the last known markers.
  final List<FacilityModel> facilities;

  FacilityState copyWith({
    FacilityLoadStatus? status,
    List<FacilityModel>? facilities,
  }) {
    return FacilityState(
      status: status ?? this.status,
      facilities: facilities ?? this.facilities,
    );
  }

  @override
  List<Object?> get props => [status, facilities];
}
