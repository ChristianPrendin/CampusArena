import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/queue_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockQueueRepository extends Mock implements QueueRepository {}

class MockFacilityRepository extends Mock implements FacilityRepository {}

const queueFacilityId = 'fac1';
const queueUid = 'me';

/// A queue entry for [uid] at the given ticket [position] in the shared test
/// facility.
QueueEntryModel queueEntry(String uid, int position) => QueueEntryModel(
  uid: uid,
  facilityId: queueFacilityId,
  position: position,
  joinedAt: DateTime(2026, 7, 4, 9),
);

/// The shared test facility, parameterised on the two fields the queue flow
/// reacts to: [status] and [freedAt].
FacilityModel queueFacility({required String status, DateTime? freedAt}) =>
    FacilityModel(
      facilityId: queueFacilityId,
      name: 'Table 2',
      sportId: 'ping_pong',
      coordinates: const Coordinates(latitude: 45.5, longitude: 9.15),
      qrCode: 'qr',
      fallbackCode: 'ABC',
      isOutdoor: false,
      status: status,
      kingOfTableWins: 0,
      queueTailPosition: 0,
      freedAt: freedAt,
    );
