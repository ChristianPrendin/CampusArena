import 'dart:async';

import 'package:campus_arena/features/queue/cubit/queue_cubit.dart';
import 'package:campus_arena/features/queue/widgets/priority_warning_dialog.dart';
import 'package:campus_arena/features/queue/widgets/queue_section.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/queue_test_helpers.dart';

void main() {
  late MockQueueRepository queueRepo;
  late MockFacilityRepository facilityRepo;
  late StreamController<List<QueueEntryModel>> queueStream;
  late StreamController<FacilityModel?> facilityStream;
  QueueCubit? cubit;

  setUp(() {
    queueRepo = MockQueueRepository();
    facilityRepo = MockFacilityRepository();
    queueStream = StreamController<List<QueueEntryModel>>();
    facilityStream = StreamController<FacilityModel?>();

    when(
      () => queueRepo.watchQueue(any()),
    ).thenAnswer((_) => queueStream.stream);
    when(
      () => facilityRepo.watchFacility(any()),
    ).thenAnswer((_) => facilityStream.stream);
    // Default: not queued on open. "Already in queue" tests override this.
    when(
      () => queueRepo.getPosition(
        facilityId: any(named: 'facilityId'),
        uid: any(named: 'uid'),
      ),
    ).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await cubit?.close();
    // Fire-and-forget: an unlistened single-subscription controller's `close()`
    // future never completes (no listener to receive the done event), so the
    // dialog-only tests — which never spin up a cubit — must not await it.
    unawaited(queueStream.close());
    unawaited(facilityStream.close());
  });

  /// Stubs the membership probe so the cubit attaches its live listeners on open.
  void stubAlreadyQueued(int position) {
    when(
      () => queueRepo.getPosition(
        facilityId: any(named: 'facilityId'),
        uid: any(named: 'uid'),
      ),
    ).thenAnswer((_) async => position);
  }

  // The cubit is created here — inside the test body's async zone — so its
  // stream-subscription callbacks are delivered by `tester.pump`. Creating it
  // in `setUp` would bind the subscription to the outer zone and events added
  // during the test would never reach it.
  Widget wrap({Locale locale = const Locale('en')}) {
    final built = QueueCubit(
      facilityId: queueFacilityId,
      uid: queueUid,
      queueRepository: queueRepo,
      facilityRepository: facilityRepo,
    );
    cubit = built;
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider.value(value: built, child: const QueueSectionView()),
      ),
    );
  }

  testWidgets('shows Join Queue by default and joining spinner on tap', (
    tester,
  ) async {
    final gate = Completer<int>();
    when(
      () => queueRepo.joinQueue(
        facilityId: any(named: 'facilityId'),
        uid: any(named: 'uid'),
      ),
    ).thenAnswer((_) => gate.future);

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('Join Queue'), findsOneWidget);

    await tester.tap(find.text('Join Queue'));
    await tester.pump();

    // joining: spinner in the disabled button, label gone.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Join Queue'), findsNothing);

    gate.complete(1);
  });

  testWidgets('renders the live position counter when in queue', (
    tester,
  ) async {
    stubAlreadyQueued(2);
    await tester.pumpWidget(wrap());
    queueStream.add([queueEntry('other', 1), queueEntry(queueUid, 2)]);
    await tester.pumpAndSettle();

    expect(find.text("You're #2 of 2"), findsOneWidget);
    expect(find.text('Leave queue'), findsOneWidget);
  });

  testWidgets(
    'surfaces the table-ready banner with the availability disclaimer on a '
    'front-of-queue freed event',
    (tester) async {
      stubAlreadyQueued(1);
      await tester.pumpWidget(wrap());
      queueStream.add([queueEntry(queueUid, 1)]);
      await tester.pumpAndSettle();
      facilityStream.add(queueFacility(status: 'occupied'));
      await tester.pumpAndSettle();
      facilityStream.add(
        queueFacility(status: 'free', freedAt: DateTime(2026, 7, 4, 10)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your table is ready'), findsOneWidget);
      expect(find.textContaining('Based on app activity only'), findsOneWidget);
    },
  );

  testWidgets('renders the position counter in Italian', (tester) async {
    stubAlreadyQueued(1);
    await tester.pumpWidget(wrap(locale: const Locale('it')));
    queueStream.add([queueEntry(queueUid, 1)]);
    await tester.pumpAndSettle();

    expect(find.text('Sei il #1 di 1'), findsOneWidget);
    expect(find.text('Entra in coda'), findsNothing); // in queue → leave shown
    expect(find.text('Esci dalla coda'), findsOneWidget);
  });

  testWidgets('Retry after a failed leave re-issues leave, not join', (
    tester,
  ) async {
    stubAlreadyQueued(1);
    when(
      () => queueRepo.leaveQueue(
        facilityId: any(named: 'facilityId'),
        uid: any(named: 'uid'),
      ),
    ).thenThrow(Exception('offline'));

    await tester.pumpWidget(wrap());
    queueStream.add([queueEntry(queueUid, 1)]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leave queue'));
    await tester.pumpAndSettle();

    // Error surface with a Retry affordance.
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    verify(
      () => queueRepo.leaveQueue(facilityId: queueFacilityId, uid: queueUid),
    ).called(2);
    verifyNever(
      () => queueRepo.joinQueue(
        facilityId: any(named: 'facilityId'),
        uid: any(named: 'uid'),
      ),
    );
  });

  group('priority warning dialog', () {
    Widget wrapDialog(Locale locale) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => PriorityWarningDialog.show(
                context: context,
                position: 3,
                frontPosition: 1,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the warning with proceed/cancel actions (EN)', (
      tester,
    ) async {
      await tester.pumpWidget(wrapDialog(const Locale('en')));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Someone is ahead of you'), findsOneWidget);
      expect(find.text('Claim anyway'), findsOneWidget);
      expect(find.text('Wait my turn'), findsOneWidget);

      // Dismiss so the showDialog future completes before teardown.
      await tester.tap(find.text('Wait my turn'));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('renders the warning in Italian', (tester) async {
      await tester.pumpWidget(wrapDialog(const Locale('it')));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text("C'è qualcuno prima di te"), findsOneWidget);
      expect(find.text('Prendi comunque'), findsOneWidget);

      await tester.tap(find.text('Aspetta il turno'));
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
