import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/tournaments/create_tournament_screen.dart';
import 'package:campus_arena/features/tournaments/cubit/create_tournament_cubit.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/tournament_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/tournament_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTournamentRepository extends Mock implements TournamentRepository {}

class MockFacilityRepository extends Mock implements FacilityRepository {}

class FakeTournamentModel extends Fake implements TournamentModel {}

FacilityModel _facility(String id) => FacilityModel(
  facilityId: id,
  name: 'Table $id',
  sportId: SportIds.pingPong,
  coordinates: const Coordinates(latitude: 45, longitude: 9),
  qrCode: 'qr',
  fallbackCode: 'fb',
  isOutdoor: false,
  status: FacilityStatus.free,
  kingOfTableWins: 0,
  queueTailPosition: 0,
);

void main() {
  late MockTournamentRepository tournamentRepo;
  late MockFacilityRepository facilityRepo;

  setUpAll(() => registerFallbackValue(FakeTournamentModel()));

  setUp(() {
    tournamentRepo = MockTournamentRepository();
    facilityRepo = MockFacilityRepository();
    when(
      () => facilityRepo.watchFacilities(),
    ).thenAnswer((_) => Stream.value([_facility('pp1')]));
    when(
      () => tournamentRepo.createTournament(any()),
    ).thenAnswer((_) async => 'tid');
  });

  Widget wrap(CreateTournamentCubit cubit) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider.value(value: cubit, child: const CreateTournamentView()),
  );

  testWidgets('tapping Create with a bad deadline order blocks the write', (
    tester,
  ) async {
    final cubit = CreateTournamentCubit(
      organizerId: 'org',
      tournamentRepository: tournamentRepo,
      facilityRepository: facilityRepo,
    )..loadFacilities();
    addTearDown(cubit.close);
    cubit
      ..setName('Bad Order')
      // Far-future dates so the "in the future" guard always passes regardless
      // of the machine clock; the deadline is deliberately AFTER the schedule.
      ..setDeadline(DateTime(2099, 1, 1, 18))
      ..setScheduledAt(DateTime(2099, 1, 1, 17));

    await tester.pumpWidget(wrap(cubit));
    await tester.pump(); // facilities stream emits → dropdown gains its item
    cubit.setFacility('pp1');
    await tester.pump();

    await tester.tap(find.text('Create'));
    await tester.pump();
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.tournamentDeadlineBeforeSchedule), findsOneWidget);
    verifyNever(() => tournamentRepo.createTournament(any()));
  });

  testWidgets(
    'a second validation failure with a different error still shows its '
    'SnackBar (regression: both failures share the same status)',
    (tester) async {
      final cubit = CreateTournamentCubit(
        organizerId: 'org',
        tournamentRepository: tournamentRepo,
        facilityRepository: facilityRepo,
      )..loadFacilities();
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.pump(); // facilities stream emits → dropdown gains its item

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // First submit: no name set → name-required error.
      await tester.tap(find.text('Create'));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.tournamentNameRequired), findsOneWidget);

      // Second submit: name and facility now set but no deadline → a
      // different error, even though `state.status` stays `failure` both
      // times.
      cubit
        ..setName('Bovisa Open')
        ..setFacility('pp1');
      await tester.tap(find.text('Create'));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.tournamentDeadlineFuture), findsOneWidget);
    },
  );
}
