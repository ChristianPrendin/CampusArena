import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/tournaments/cubit/tournament_detail_cubit.dart';
import 'package:campus_arena/features/tournaments/tournament_detail_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/tournament_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/tournament_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTournamentRepository extends Mock implements TournamentRepository {}

class MockMatchRepository extends Mock implements MatchRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

const _tid = 't1';
const _organizer = 'org';

TournamentModel _tournament({
  String status = TournamentStatus.active,
  String organizerId = _organizer,
  int maxParticipants = 8,
}) => TournamentModel(
  tournamentId: _tid,
  name: 'Friday Night Smash',
  sportId: SportIds.pingPong,
  facilityId: 'f1',
  organizerId: organizerId,
  maxParticipants: maxParticipants,
  status: status,
  bracket: const {},
  eloMultiplier: 1.5,
  registrationDeadline: DateTime(2026, 7, 5),
  scheduledAt: DateTime(2026, 7, 6),
  createdAt: DateTime(2026, 6, 30),
);

TournamentParticipantModel _p(String uid, int seed) =>
    TournamentParticipantModel(uid: uid, seed: seed, eliminated: false);

UserModel _user(String uid) => UserModel(
  uid: uid,
  name: uid.toUpperCase(),
  username: uid,
  email: '$uid@polimi.it',
  degreeProgram: 'CS',
  language: 'en',
  pushTokens: const [],
  friendUids: const [],
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

void main() {
  late MockTournamentRepository tournamentRepository;
  late MockMatchRepository matchRepository;
  late MockUserRepository userRepository;
  late MockRatingRepository ratingRepository;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    tournamentRepository = MockTournamentRepository();
    matchRepository = MockMatchRepository();
    userRepository = MockUserRepository();
    ratingRepository = MockRatingRepository();

    when(
      () => matchRepository.watchTournamentMatches(
        any(),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => Stream.value(const <MatchModel>[]));
    when(() => userRepository.getUsersByIds(any())).thenAnswer((
      invocation,
    ) async {
      final uids = invocation.positionalArguments.first as List<String>;
      return uids.map(_user).toList();
    });
    when(
      () => ratingRepository.getUserRating(any(), any()),
    ).thenAnswer((_) async => null);
    when(
      () => tournamentRepository.watchParticipants(_tid),
    ).thenAnswer((_) => Stream.value([_p('u1', 1), _p('u2', 2)]));
  });

  void streamTournament(TournamentModel t) {
    when(
      () => tournamentRepository.watchTournament(_tid),
    ).thenAnswer((_) => Stream.value(t));
  }

  TournamentDetailCubit cubit({String uid = _organizer}) =>
      TournamentDetailCubit(
        tournamentId: _tid,
        uid: uid,
        tournamentRepository: tournamentRepository,
        matchRepository: matchRepository,
        userRepository: userRepository,
        ratingRepository: ratingRepository,
      )..init();

  Widget wrap(TournamentDetailCubit c, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(value: c, child: const TournamentDetailView()),
    );
  }

  testWidgets('organizer controls hidden for a non-organizer', (tester) async {
    streamTournament(_tournament());
    final c = cubit(uid: 'someone_else');
    addTearDown(c.close);
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    expect(find.text('Organizer controls'), findsNothing);
    expect(find.text('Standings'), findsOneWidget);
  });

  testWidgets('organizer controls shown for the organizer while active', (
    tester,
  ) async {
    streamTournament(_tournament());
    final c = cubit();
    addTearDown(c.close);
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    expect(find.text('Organizer controls'), findsOneWidget);
    expect(find.text('Advance slot'), findsOneWidget);
    expect(find.text('Mark forfeit'), findsOneWidget);
  });

  testWidgets(
    'organizer controls hidden while registering (Register instead)',
    (tester) async {
      streamTournament(_tournament(status: TournamentStatus.registering));
      final c = cubit();
      addTearDown(c.close);
      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      expect(find.text('Organizer controls'), findsNothing);
      expect(find.text('Register'), findsOneWidget);
    },
  );

  testWidgets('mark-forfeit sheet flags the tapped player', (tester) async {
    streamTournament(_tournament());
    when(
      () => tournamentRepository.updateParticipant(any(), any(), any()),
    ).thenAnswer((_) async {});
    final c = cubit();
    addTearDown(c.close);
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark forfeit'));
    await tester.pumpAndSettle();

    // The sheet lists alive players by resolved name.
    expect(find.text('Mark a player as forfeited'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'U1'));
    await tester.pumpAndSettle();

    verify(
      () => tournamentRepository.updateParticipant(_tid, 'u1', {
        'eliminated': true,
        'eliminationReason': EliminationReason.forfeit,
      }),
    ).called(1);
  });

  testWidgets('renders Italian copy under the it locale', (tester) async {
    streamTournament(_tournament());
    final c = cubit(uid: 'someone_else');
    addTearDown(c.close);
    await tester.pumpWidget(wrap(c, locale: const Locale('it')));
    await tester.pumpAndSettle();

    expect(find.text('Classifica'), findsOneWidget);
  });

  testWidgets('a stream error shows the retry view and re-subscribes', (
    tester,
  ) async {
    when(
      () => tournamentRepository.watchTournament(_tid),
    ).thenAnswer((_) => Stream.error(Exception('boom')));

    final c = cubit(uid: 'someone_else');
    addTearDown(c.close);
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    verify(
      () => tournamentRepository.watchTournament(_tid),
    ).called(greaterThanOrEqualTo(2));
  });

  testWidgets('the register bar reads "registered" for a joined player', (
    tester,
  ) async {
    streamTournament(_tournament(status: TournamentStatus.registering));
    // uid 'u1' is one of the streamed participants.
    final c = cubit(uid: 'u1');
    addTearDown(c.close);
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    expect(find.text('Registered'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Registered'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('the register bar reads "full" when the cap is reached', (
    tester,
  ) async {
    streamTournament(
      _tournament(status: TournamentStatus.registering, maxParticipants: 2),
    );
    // Not a participant, and the two streamed participants fill the 2 slots.
    final c = cubit(uid: 'outsider');
    addTearDown(c.close);
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Full'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('the organizer can open the cancel menu while registering', (
    tester,
  ) async {
    streamTournament(_tournament(status: TournamentStatus.registering));
    final c = cubit();
    addTearDown(c.close);
    await tester.pumpWidget(wrap(c));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    expect(find.text('Cancel tournament'), findsOneWidget);

    // Choosing it prompts for confirmation; dismissing leaves it uncancelled.
    await tester.tap(find.text('Cancel tournament'));
    await tester.pumpAndSettle();
    expect(find.text('Keep it'), findsOneWidget);
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    // Dismissed — still on the detail screen, tournament not cancelled.
    expect(find.text('Standings'), findsOneWidget);
  });
}
