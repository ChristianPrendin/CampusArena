import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/map/cubit/facility_cubit.dart';
import 'package:campus_arena/features/map/cubit/facility_state.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFacilityRepository extends Mock implements FacilityRepository {}

FacilityModel _facility(String id, {String status = FacilityStatus.free}) =>
    FacilityModel(
      facilityId: id,
      name: 'Table $id',
      sportId: SportIds.pingPong,
      coordinates: const Coordinates(latitude: 45.503, longitude: 9.158),
      qrCode: 'qr-$id',
      fallbackCode: 'fb-$id',
      isOutdoor: false,
      status: status,
      kingOfTableWins: 0,
      queueTailPosition: 0,
    );

void main() {
  late MockFacilityRepository repository;

  setUp(() {
    repository = MockFacilityRepository();
  });

  test('initial state is emitted synchronously by the constructor', () {
    final cubit = FacilityCubit(repository: repository);
    expect(cubit.state, const FacilityState());
    expect(cubit.state.status, FacilityLoadStatus.initial);
    cubit.close();
  });

  blocTest<FacilityCubit, FacilityState>(
    'emits [loading, loaded] when the stream delivers facilities',
    setUp: () {
      when(
        () => repository.watchFacilities(),
      ).thenAnswer((_) => Stream.value([_facility('f1')]));
    },
    build: () => FacilityCubit(repository: repository),
    act: (cubit) => cubit.subscribe(),
    expect: () => [
      const FacilityState(status: FacilityLoadStatus.loading),
      FacilityState(
        status: FacilityLoadStatus.loaded,
        facilities: [_facility('f1')],
      ),
    ],
  );

  group('with a controller-driven stream', () {
    late StreamController<List<FacilityModel>> controller;

    setUp(() {
      controller = StreamController<List<FacilityModel>>();
      when(
        () => repository.watchFacilities(),
      ).thenAnswer((_) => controller.stream);
    });

    tearDown(() => controller.close());

    blocTest<FacilityCubit, FacilityState>(
      're-emits loaded on a real-time status change',
      build: () => FacilityCubit(repository: repository),
      act: (cubit) async {
        cubit.subscribe();
        controller.add([_facility('f1')]);
        await Future<void>.delayed(Duration.zero);
        controller.add([_facility('f1', status: FacilityStatus.occupied)]);
      },
      expect: () => [
        const FacilityState(status: FacilityLoadStatus.loading),
        FacilityState(
          status: FacilityLoadStatus.loaded,
          facilities: [_facility('f1')],
        ),
        FacilityState(
          status: FacilityLoadStatus.loaded,
          facilities: [_facility('f1', status: FacilityStatus.occupied)],
        ),
      ],
    );

    blocTest<FacilityCubit, FacilityState>(
      'keeps the last facilities when the stream errors after data',
      build: () => FacilityCubit(repository: repository),
      act: (cubit) async {
        cubit.subscribe();
        controller.add([_facility('f1')]);
        await Future<void>.delayed(Duration.zero);
        controller.addError(Exception('firestore down'));
      },
      expect: () => [
        const FacilityState(status: FacilityLoadStatus.loading),
        FacilityState(
          status: FacilityLoadStatus.loaded,
          facilities: [_facility('f1')],
        ),
        FacilityState(
          status: FacilityLoadStatus.error,
          facilities: [_facility('f1')],
        ),
      ],
    );
  });

  blocTest<FacilityCubit, FacilityState>(
    'emits [loading, error] when the stream fails',
    setUp: () {
      when(
        () => repository.watchFacilities(),
      ).thenAnswer((_) => Stream.error(Exception('firestore down')));
    },
    build: () => FacilityCubit(repository: repository),
    act: (cubit) => cubit.subscribe(),
    expect: () => [
      const FacilityState(status: FacilityLoadStatus.loading),
      const FacilityState(status: FacilityLoadStatus.error),
    ],
  );

  blocTest<FacilityCubit, FacilityState>(
    'subscribe after an error resubscribes and recovers',
    setUp: () {
      var calls = 0;
      when(() => repository.watchFacilities()).thenAnswer((_) {
        calls++;
        if (calls == 1) return Stream.error(Exception('firestore down'));
        return Stream.value([_facility('f1')]);
      });
    },
    build: () => FacilityCubit(repository: repository),
    act: (cubit) async {
      cubit.subscribe();
      await Future<void>.delayed(Duration.zero);
      cubit.subscribe();
    },
    expect: () => [
      const FacilityState(status: FacilityLoadStatus.loading),
      const FacilityState(status: FacilityLoadStatus.error),
      const FacilityState(status: FacilityLoadStatus.loading),
      FacilityState(
        status: FacilityLoadStatus.loaded,
        facilities: [_facility('f1')],
      ),
    ],
    verify: (_) => verify(() => repository.watchFacilities()).called(2),
  );
}
