import 'dart:async';

import 'package:campus_arena/core/constants.dart' as fs;
import 'package:campus_arena/features/result/cubit/result_cubit.dart';
import 'package:campus_arena/features/result/cubit/result_state.dart';
import 'package:campus_arena/models/achievement_def_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/achievement_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMatchRepository extends Mock implements MatchRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockAchievementRepository extends Mock implements AchievementRepository {}

const _me = 'me';
const _opp = 'opp';

MatchModel _match({
  required String state,
  String? submittedByUid,
  MatchResult? result,
  Map<String, int>? eloBefore,
  Map<String, int>? eloDeltas,
  DateTime? startedAt,
  DateTime? confirmedAt,
}) => MatchModel(
  matchId: 'm1',
  facilityId: 'f1',
  sportId: fs.SportIds.pingPong,
  mode: 'singles',
  playerUids: const [_me, _opp],
  state: state,
  submittedByUid: submittedByUid,
  result: result,
  eloBefore: eloBefore,
  eloDeltas: eloDeltas,
  startedAt: startedAt ?? DateTime(2026, 7, 5, 10),
  confirmedAt: confirmedAt,
);

const _validResult = PingPongResult(
  winnerIds: [_me],
  sets: [11],
  opponentSets: [5],
);

void main() {
  late MockMatchRepository matchRepo;
  late MockRatingRepository ratingRepo;
  late MockUserRepository userRepo;
  late MockAchievementRepository achievementRepo;
  late StreamController<MatchModel?> matchStream;

  setUpAll(() {
    registerFallbackValue(_match(state: fs.MatchStates.occupied));
    registerFallbackValue(_validResult);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    matchRepo = MockMatchRepository();
    ratingRepo = MockRatingRepository();
    userRepo = MockUserRepository();
    achievementRepo = MockAchievementRepository();
    matchStream = StreamController<MatchModel?>.broadcast();
    when(
      () => achievementRepo.getDefinitions(),
    ).thenAnswer((_) async => const []);

    when(
      () => matchRepo.watchMatch(any()),
    ).thenAnswer((_) => matchStream.stream);
    when(
      () => matchRepo.submitResult(
        matchId: any(named: 'matchId'),
        result: any(named: 'result'),
        submittedByUid: any(named: 'submittedByUid'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => matchRepo.confirmResult(
        matchId: any(named: 'matchId'),
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) async => <String, Set<String>>{});
    when(
      () => matchRepo.disputeResult(
        matchId: any(named: 'matchId'),
        disputingUid: any(named: 'disputingUid'),
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => matchRepo.resolveTimeout(any(), now: any(named: 'now')),
    ).thenAnswer((_) async {});
    when(() => userRepo.getUser(any())).thenAnswer((_) async => null);
    when(
      () => ratingRepo.getUserRank(
        sportId: any(named: 'sportId'),
        elo: any(named: 'elo'),
      ),
    ).thenAnswer((_) async => 12);
  });

  tearDown(() => matchStream.close());

  ResultCubit build({DateTime Function()? now}) => ResultCubit(
    uid: _me,
    matchId: 'm1',
    matchRepository: matchRepo,
    ratingRepository: ratingRepo,
    userRepository: userRepo,
    achievementRepository: achievementRepo,
    now: now,
  );

  test('load derives scoreEntry from an occupied match', () async {
    final cubit = build();
    final phases = <ResultPhase>[];
    final sub = cubit.stream.listen((s) => phases.add(s.phase));

    cubit.load();
    matchStream.add(_match(state: fs.MatchStates.occupied));
    await pumpEventQueue();

    expect(phases, contains(ResultPhase.scoreEntry));
    await sub.cancel();
    await cubit.close();
  });

  test('an opponent-submitted result derives the review phase', () async {
    final cubit = build();
    cubit.load();
    matchStream.add(
      _match(
        state: fs.MatchStates.awaitingConfirmation,
        submittedByUid: _opp,
        result: _validResult,
      ),
    );
    await pumpEventQueue();

    expect(cubit.state.phase, ResultPhase.review);
    await cubit.close();
  });

  test('my own submitted result derives awaitingOpponent', () async {
    final cubit = build();
    cubit.load();
    matchStream.add(
      _match(
        state: fs.MatchStates.awaitingConfirmation,
        submittedByUid: _me,
        result: _validResult,
      ),
    );
    await pumpEventQueue();

    expect(cubit.state.phase, ResultPhase.awaitingOpponent);
    await cubit.close();
  });

  test('submit(valid): scoreEntry → submitting → awaitingOpponent', () async {
    final cubit = build();
    final phases = <ResultPhase>[];
    final sub = cubit.stream.listen((s) => phases.add(s.phase));

    cubit.load();
    matchStream.add(_match(state: fs.MatchStates.occupied));
    await pumpEventQueue();
    await cubit.submit(_validResult);
    matchStream.add(
      _match(
        state: fs.MatchStates.awaitingConfirmation,
        submittedByUid: _me,
        result: _validResult,
      ),
    );
    await pumpEventQueue();

    expect(
      phases,
      containsAllInOrder([
        ResultPhase.scoreEntry,
        ResultPhase.submitting,
        ResultPhase.awaitingOpponent,
      ]),
    );
    verify(
      () => matchRepo.submitResult(
        matchId: 'm1',
        result: _validResult,
        submittedByUid: _me,
      ),
    ).called(1);
    await sub.cancel();
    await cubit.close();
  });

  test('submit(invalid) never writes and stays in scoreEntry', () async {
    final cubit = build();
    cubit.load();
    matchStream.add(_match(state: fs.MatchStates.occupied));
    await pumpEventQueue();

    // 11-10 is not a decisive set → strategy rejects it.
    await cubit.submit(
      const PingPongResult(winnerIds: [_me], sets: [11], opponentSets: [10]),
    );
    await pumpEventQueue();

    expect(cubit.state.phase, ResultPhase.scoreEntry);
    verifyNever(
      () => matchRepo.submitResult(
        matchId: any(named: 'matchId'),
        result: any(named: 'result'),
        submittedByUid: any(named: 'submittedByUid'),
      ),
    );
    await cubit.close();
  });

  test('confirm: review → confirming → summary with rank', () async {
    final cubit = build();
    final phases = <ResultPhase>[];
    final sub = cubit.stream.listen((s) => phases.add(s.phase));

    cubit.load();
    matchStream.add(
      _match(
        state: fs.MatchStates.awaitingConfirmation,
        submittedByUid: _opp,
        result: _validResult,
      ),
    );
    await pumpEventQueue();
    await cubit.confirm();
    matchStream.add(
      _match(
        state: fs.MatchStates.confirmed,
        submittedByUid: _opp,
        result: _validResult,
        eloBefore: const {_me: 1200, _opp: 1200},
        eloDeltas: const {_me: 16, _opp: -16},
      ),
    );
    await pumpEventQueue();

    expect(
      phases,
      containsAllInOrder([
        ResultPhase.review,
        ResultPhase.confirming,
        ResultPhase.summary,
      ]),
    );
    verify(
      () => matchRepo.confirmResult(
        matchId: 'm1',
        now: any(named: 'now'),
      ),
    ).called(1);

    final summary = cubit.state.summary!;
    expect(summary.isWin, isTrue);
    expect(summary.oldElo, 1200);
    expect(summary.newElo, 1216);
    expect(summary.delta, 16);
    expect(summary.rank, 12);
    await sub.cancel();
    await cubit.close();
  });

  test('summary reached via the stream reveals THIS user\'s just-earned badges '
      '(the non-confirming player)', () async {
    final confirmedAt = DateTime(2026, 7, 5, 11);
    when(() => achievementRepo.getDefinitions()).thenAnswer(
      (_) async => const [
        AchievementDefModel(
          achievementId: 'first_victory',
          nameKey: 'n',
          descriptionKey: 'd',
          iconAsset: 'assets/badges/first_victory.png',
          condition: 'first_victory',
        ),
        AchievementDefModel(
          achievementId: 'explorer',
          nameKey: 'n',
          descriptionKey: 'd',
          iconAsset: 'assets/badges/explorer.png',
          condition: 'explorer',
        ),
      ],
    );
    // Our own doc: one badge stamped at this match's confirmedAt (just earned by
    // the opponent's confirm transaction), one stamped earlier (a prior match).
    when(() => userRepo.getUser(_me)).thenAnswer(
      (_) async => UserModel(
        uid: _me,
        name: '',
        username: '',
        email: '',
        degreeProgram: '',
        language: 'en',
        pushTokens: const [],
        friendUids: const [],
        badges: {
          'first_victory': confirmedAt,
          'explorer': DateTime(2026, 7, 1),
        },
        onboardingComplete: true,
        createdAt: DateTime(2026),
      ),
    );

    final cubit = build();
    cubit.load();
    // The opponent confirmed: our device only ever sees the stream advance to
    // `confirmed` — confirm() is never called here.
    matchStream.add(
      _match(
        state: fs.MatchStates.confirmed,
        submittedByUid: _opp,
        result: _validResult,
        eloBefore: const {_me: 1200, _opp: 1200},
        eloDeltas: const {_me: 16, _opp: -16},
        confirmedAt: confirmedAt,
      ),
    );
    await pumpEventQueue();

    expect(cubit.state.phase, ResultPhase.summary);
    // Only the badge earned by THIS match is revealed; the older one is excluded.
    expect(cubit.state.newBadges.map((d) => d.achievementId), [
      'first_victory',
    ]);
    verifyNever(
      () => matchRepo.confirmResult(
        matchId: any(named: 'matchId'),
        now: any(named: 'now'),
      ),
    );
    await cubit.close();
  });

  test('confirm reveals the badges returned by the transaction '
      '(the confirming player)', () async {
    when(
      () => matchRepo.confirmResult(
        matchId: any(named: 'matchId'),
        now: any(named: 'now'),
      ),
    ).thenAnswer(
      (_) async => {
        _me: {'first_victory'},
      },
    );
    when(() => achievementRepo.getDefinitions()).thenAnswer(
      (_) async => const [
        AchievementDefModel(
          achievementId: 'first_victory',
          nameKey: 'n',
          descriptionKey: 'd',
          iconAsset: 'assets/badges/first_victory.png',
          condition: 'first_victory',
        ),
      ],
    );

    final cubit = build();
    cubit.load();
    matchStream.add(
      _match(
        state: fs.MatchStates.awaitingConfirmation,
        submittedByUid: _opp,
        result: _validResult,
      ),
    );
    await pumpEventQueue();
    await cubit.confirm();
    await pumpEventQueue();

    expect(cubit.state.newBadges.map((d) => d.achievementId), [
      'first_victory',
    ]);
    await cubit.close();
  });

  test('dispute: review → disputing → closed(disputed)', () async {
    final cubit = build();
    final phases = <ResultPhase>[];
    final sub = cubit.stream.listen((s) => phases.add(s.phase));

    cubit.load();
    matchStream.add(
      _match(
        state: fs.MatchStates.awaitingConfirmation,
        submittedByUid: _opp,
        result: _validResult,
      ),
    );
    await pumpEventQueue();
    await cubit.dispute();
    matchStream.add(
      _match(
        state: fs.MatchStates.disputed,
        submittedByUid: _opp,
        result: _validResult,
      ),
    );
    await pumpEventQueue();

    expect(
      phases,
      containsAllInOrder([
        ResultPhase.review,
        ResultPhase.disputing,
        ResultPhase.closed,
      ]),
    );
    expect(cubit.state.closedKind, ResultClosedKind.disputed);
    verify(
      () => matchRepo.disputeResult(
        matchId: 'm1',
        disputingUid: _me,
        now: any(named: 'now'),
      ),
    ).called(1);
    await sub.cancel();
    await cubit.close();
  });

  test('lost submit race: error self-heals to review when the doc '
      'arrives after the failed write', () async {
    when(
      () => matchRepo.submitResult(
        matchId: any(named: 'matchId'),
        result: any(named: 'result'),
        submittedByUid: any(named: 'submittedByUid'),
      ),
    ).thenThrow(StateError('state != occupied'));

    final cubit = build();
    cubit.load();
    matchStream.add(_match(state: fs.MatchStates.occupied));
    await pumpEventQueue();

    await cubit.submit(_validResult);
    expect(cubit.state.phase, ResultPhase.error);

    // The opponent's winning submission streams in → review, no retry needed.
    matchStream.add(
      _match(
        state: fs.MatchStates.awaitingConfirmation,
        submittedByUid: _opp,
        result: _validResult,
      ),
    );
    await pumpEventQueue();

    expect(cubit.state.phase, ResultPhase.review);
    await cubit.close();
  });

  test('lost submit race: no error when the doc advanced before '
      'the failed write returned', () async {
    final gate = Completer<void>();
    when(
      () => matchRepo.submitResult(
        matchId: any(named: 'matchId'),
        result: any(named: 'result'),
        submittedByUid: any(named: 'submittedByUid'),
      ),
    ).thenAnswer((_) async {
      await gate.future;
      throw StateError('state != occupied');
    });

    final cubit = build();
    cubit.load();
    matchStream.add(_match(state: fs.MatchStates.occupied));
    await pumpEventQueue();

    final submit = cubit.submit(_validResult);
    // The opponent's submission streams in while ours is still in flight.
    matchStream.add(
      _match(
        state: fs.MatchStates.awaitingConfirmation,
        submittedByUid: _opp,
        result: _validResult,
      ),
    );
    await pumpEventQueue();
    gate.complete();
    await submit;

    expect(cubit.state.phase, ResultPhase.review);
    expect(cubit.state.errorKind, isNot(ResultErrorKind.submit));
    await cubit.close();
  });

  test('confirm failure → error, then retry re-derives review', () async {
    when(
      () => matchRepo.confirmResult(
        matchId: any(named: 'matchId'),
        now: any(named: 'now'),
      ),
    ).thenThrow(StateError('offline'));

    final cubit = build();
    cubit.load();
    matchStream.add(
      _match(
        state: fs.MatchStates.awaitingConfirmation,
        submittedByUid: _opp,
        result: _validResult,
      ),
    );
    await pumpEventQueue();
    await cubit.confirm();
    await pumpEventQueue();

    expect(cubit.state.phase, ResultPhase.error);
    expect(cubit.state.errorKind, ResultErrorKind.confirm);

    cubit.retry();
    await pumpEventQueue();
    expect(cubit.state.phase, ResultPhase.review);
    await cubit.close();
  });

  test('closed states carry distinct kinds', () async {
    final cubit = build();
    cubit.load();
    matchStream.add(_match(state: fs.MatchStates.unconfirmed));
    await pumpEventQueue();
    expect(cubit.state.phase, ResultPhase.closed);
    expect(cubit.state.closedKind, ResultClosedKind.unconfirmed);

    matchStream.add(_match(state: fs.MatchStates.abandoned));
    await pumpEventQueue();
    expect(cubit.state.closedKind, ResultClosedKind.abandoned);
    await cubit.close();
  });

  test('a stale occupied match triggers a lazy timeout resolution', () async {
    final cubit = build(now: () => DateTime(2026, 7, 5, 20)); // 10h after start
    cubit.load();
    matchStream.add(_match(state: fs.MatchStates.occupied));
    await pumpEventQueue();

    verify(
      () => matchRepo.resolveTimeout(any(), now: any(named: 'now')),
    ).called(greaterThanOrEqualTo(1));
    await cubit.close();
  });

  test('a null match doc surfaces the load error', () async {
    final cubit = build();
    cubit.load();
    matchStream.add(null);
    await pumpEventQueue();

    expect(cubit.state.phase, ResultPhase.error);
    expect(cubit.state.errorKind, ResultErrorKind.load);
    await cubit.close();
  });
}
