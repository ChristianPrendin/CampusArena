import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

FacilityModel _facility(String id, {String status = FacilityStatus.free}) =>
    FacilityModel(
      facilityId: id,
      name: 'Table $id',
      sportId: SportIds.pingPong,
      coordinates: const Coordinates(latitude: 45.47, longitude: 9.22),
      qrCode: 'qr_$id',
      fallbackCode: 'FB$id',
      isOutdoor: false,
      status: status,
      kingOfTableWins: 0,
      queueTailPosition: 0,
    );

void main() {
  late FakeFirebaseFirestore firestore;
  late FacilityRepository repository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repository = FacilityRepository(firestore: firestore);
    await firestore
        .collection(FirestoreCollections.facilities)
        .doc('f1')
        .set(_facility('f1').toMap());
  });

  test('getFacility round-trips a stored facility', () async {
    final facility = await repository.getFacility('f1');

    expect(facility, isNotNull);
    expect(facility!.name, 'Table f1');
    expect(facility.status, FacilityStatus.free);
  });

  test('getFacility returns null for a missing doc', () async {
    expect(await repository.getFacility('nope'), isNull);
  });

  test('watchFacilities emits all facilities', () async {
    await firestore
        .collection(FirestoreCollections.facilities)
        .doc('f2')
        .set(_facility('f2').toMap());

    final facilities = await repository.watchFacilities().first;

    expect(facilities.map((f) => f.facilityId).toSet(), {'f1', 'f2'});
  });

  test('updateStatus flips status and writes currentMatchId', () async {
    await repository.updateStatus(
      facilityId: 'f1',
      status: FacilityStatus.occupied,
      currentMatchId: 'm1',
    );

    final facility = await repository.getFacility('f1');
    expect(facility!.status, FacilityStatus.occupied);
    expect(facility.currentMatchId, 'm1');
  });

  test('updateStatus clears currentMatchId when freeing', () async {
    await repository.updateStatus(
      facilityId: 'f1',
      status: FacilityStatus.occupied,
      currentMatchId: 'm1',
    );

    await repository.updateStatus(
      facilityId: 'f1',
      status: FacilityStatus.free,
    );

    final facility = await repository.getFacility('f1');
    expect(facility!.status, FacilityStatus.free);
    expect(facility.currentMatchId, isNull);
  });

  group('getFacilitiesByStatus', () {
    test('returns only facilities matching the given status', () async {
      await firestore
          .collection(FirestoreCollections.facilities)
          .doc('f2')
          .set(_facility('f2', status: FacilityStatus.occupied).toMap());
      await firestore
          .collection(FirestoreCollections.facilities)
          .doc('f3')
          .set(_facility('f3', status: FacilityStatus.free).toMap());

      final free = await repository.getFacilitiesByStatus(FacilityStatus.free);

      expect(free.map((f) => f.facilityId).toSet(), {'f1', 'f3'});
      expect(free.every((f) => f.status == FacilityStatus.free), isTrue);
    });

    test('is bounded by limit', () async {
      for (var i = 0; i < 5; i++) {
        await firestore
            .collection(FirestoreCollections.facilities)
            .doc('extra_$i')
            .set(_facility('extra_$i', status: FacilityStatus.free).toMap());
      }

      final free = await repository.getFacilitiesByStatus(
        FacilityStatus.free,
        limit: 2,
      );

      expect(free.length, 2);
    });

    test('returns an empty list when nothing matches', () async {
      final queued = await repository.getFacilitiesByStatus(
        FacilityStatus.queued,
      );

      expect(queued, isEmpty);
    });
  });
}
