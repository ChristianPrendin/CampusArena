import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/challenges/cubit/challenge_cubit.dart';
import 'package:campus_arena/features/challenges/cubit/challenge_state.dart';
import 'package:campus_arena/models/challenge_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/challenge_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockChallengeRepository extends Mock implements ChallengeRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockMatchRepository extends Mock implements MatchRepository {}

const _me = 'me';

ChallengeModel _challenge(
  String id, {
  String from = 'other',
  String to = _me,
  String sportId = SportIds.pingPong,
  String status = ChallengeStatus.pending,
  DateTime? createdAt,
  DateTime? respondedAt,
}) => ChallengeModel(
  challengeId: id,
  fromUserId: from,
  toUserId: to,
  sportId: sportId,
  status: status,
  createdAt: createdAt ?? DateTime(2026, 7, 6, 10),
  respondedAt: respondedAt,
);

MatchModel _match(
  String id, {
  required List<String> playerUids,
  String sportId = SportIds.pingPong,
  String state = MatchStates.confirmed,
  DateTime? startedAt,
  DateTime? confirmedAt,
}) => MatchModel(
  matchId: id,
  facilityId: 'f1',
  sportId: sportId,
  mode: MatchModes.singles,
  playerUids: playerUids,
  state: state,
  startedAt: startedAt ?? DateTime(2026, 7, 6, 12),
  confirmedAt: confirmedAt,
);

UserModel _user(String uid, String name) => UserModel(
  uid: uid,
  name: name,
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

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MockChallengeRepository challengeRepository;
  late MockUserRepository userRepository;
  late MockMatchRepository matchRepository;
  late StreamController<List<ChallengeModel>> incoming;
  late StreamController<List<ChallengeModel>> outgoing;
  late StreamController<List<MatchModel>> matches;

  // Names resolved by uid for the getUsersByIds stub.
  const names = {'alice': 'Alice', 'bob': 'Bob', 'other': 'Other'};

  setUpAll(() {
    registerFallbackValue(_challenge('fallback'));
  });

  setUp(() {
    challengeRepository = MockChallengeRepository();
    userRepository = MockUserRepository();
    matchRepository = MockMatchRepository();
    incoming = StreamController<List<ChallengeModel>>();
    outgoing = StreamController<List<ChallengeModel>>();
    matches = StreamController<List<MatchModel>>();

    when(
      () => challengeRepository.watchIncomingPending(_me),
    ).thenAnswer((_) => incoming.stream);
    when(
      () => challengeRepository.watchOutgoingRecent(_me),
    ).thenAnswer((_) => outgoing.stream);
    when(
      () => matchRepository.watchUserMatches(_me, limit: any(named: 'limit')),
    ).thenAnswer((_) => matches.stream);
    when(() => userRepository.getUsersByIds(any())).thenAnswer((inv) async {
      final ids = inv.positionalArguments[0] as List<String>;
      return ids.map((id) => _user(id, names[id] ?? id)).toList();
    });
    when(
      () => challengeRepository.expireIfDue(any(), now: any(named: 'now')),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    incoming.close();
    outgoing.close();
    matches.close();
  });

  ChallengeCubit build() => ChallengeCubit(
    uid: _me,
    challengeRepository: challengeRepository,
    userRepository: userRepository,
    matchRepository: matchRepository,
  );

  test('initial state is loading, emitted synchronously', () {
    final cubit = build();
    expect(cubit.state.status, ChallengeStreamStatus.loading);
    expect(cubit.state.isEmpty, isTrue);
    cubit.close();
  });

  test('sender constructor opens no stream listeners', () {
    final cubit = ChallengeCubit.sender(
      uid: _me,
      challengeRepository: challengeRepository,
      userRepository: userRepository,
    );
    verifyNever(() => challengeRepository.watchIncomingPending(any()));
    verifyNever(() => challengeRepository.watchOutgoingRecent(any()));
    expect(cubit.state.status, ChallengeStreamStatus.loading);
    cubit.close();
  });

  test('incoming snapshot resolves challenger names', () async {
    final cubit = build();
    incoming.add([_challenge('c1', from: 'alice')]);
    await _flush();

    expect(cubit.state.status, ChallengeStreamStatus.ready);
    expect(cubit.state.incoming.map((c) => c.challengeId), ['c1']);
    expect(cubit.state.nameOf('alice'), 'Alice');
    await cubit.close();
  });

  test(
    'outgoing snapshot resolves counterpart names across statuses',
    () async {
      final cubit = build();
      outgoing.add([
        _challenge(
          'o1',
          from: _me,
          to: 'bob',
          status: ChallengeStatus.declined,
        ),
      ]);
      await _flush();

      expect(cubit.state.outgoing.single.status, ChallengeStatus.declined);
      expect(cubit.state.nameOf('bob'), 'Bob');
      await cubit.close();
    },
  );

  group('played-challenge completion (outbox)', () {
    ChallengeModel accepted(String id, {String to = 'bob', DateTime? at}) =>
        _challenge(
          id,
          from: _me,
          to: to,
          status: ChallengeStatus.accepted,
          respondedAt: at ?? DateTime(2026, 7, 6, 11),
        );

    test('hides an accepted challenge once its match is confirmed', () async {
      final cubit = build();
      outgoing.add([accepted('o1')]);
      await _flush();
      expect(cubit.state.outgoing.map((c) => c.challengeId), ['o1']);

      // A confirmed match with the same opponent + sport, played after the
      // accept, streams in: the challenge has been played and drops off.
      matches.add([
        _match(
          'm1',
          playerUids: [_me, 'bob'],
          confirmedAt: DateTime(2026, 7, 6, 12),
        ),
      ]);
      await _flush();
      expect(cubit.state.outgoing, isEmpty);
      await cubit.close();
    });

    test('completion survives regardless of stream arrival order', () async {
      final cubit = build();
      // Matches arrive first, challenge second.
      matches.add([
        _match(
          'm1',
          playerUids: [_me, 'bob'],
          confirmedAt: DateTime(2026, 7, 6, 12),
        ),
      ]);
      await _flush();
      outgoing.add([accepted('o1')]);
      await _flush();
      expect(cubit.state.outgoing, isEmpty);
      await cubit.close();
    });

    test('keeps an accepted challenge with no matching match', () async {
      final cubit = build();
      outgoing.add([accepted('o1', to: 'bob')]);
      await _flush();
      // Wrong opponent, and a different sport — neither completes o1.
      matches.add([
        _match(
          'm1',
          playerUids: [_me, 'carol'],
          confirmedAt: DateTime(2026, 7, 6, 12),
        ),
        _match(
          'm2',
          playerUids: [_me, 'bob'],
          sportId: SportIds.foosball,
          confirmedAt: DateTime(2026, 7, 6, 12),
        ),
      ]);
      await _flush();
      expect(cubit.state.outgoing.map((c) => c.challengeId), ['o1']);
      await cubit.close();
    });

    test('a match played before the accept does not complete it', () async {
      final cubit = build();
      outgoing.add([accepted('o1', at: DateTime(2026, 7, 6, 11))]);
      await _flush();
      // An earlier confirmed match between the two must not be mistaken for
      // this challenge being played.
      matches.add([
        _match(
          'm1',
          playerUids: [_me, 'bob'],
          confirmedAt: DateTime(2026, 7, 6, 9),
        ),
      ]);
      await _flush();
      expect(cubit.state.outgoing.map((c) => c.challengeId), ['o1']);
      await cubit.close();
    });

    test('an unconfirmed match does not complete the challenge', () async {
      final cubit = build();
      outgoing.add([accepted('o1')]);
      await _flush();
      matches.add([
        _match(
          'm1',
          playerUids: [_me, 'bob'],
          state: MatchStates.awaitingConfirmation,
          startedAt: DateTime(2026, 7, 6, 12),
        ),
      ]);
      await _flush();
      expect(cubit.state.outgoing.map((c) => c.challengeId), ['o1']);
      await cubit.close();
    });
  });

  test(
    'alert fires only on a later incoming snapshot, not the first',
    () async {
      final cubit = build();

      incoming.add([_challenge('c1', from: 'alice')]);
      await _flush();
      expect(cubit.state.alertNonce, 0); // First snapshot never alerts.

      incoming.add([
        _challenge('c2', from: 'bob', createdAt: DateTime(2026, 7, 6, 11)),
        _challenge('c1', from: 'alice'),
      ]);
      await _flush();
      expect(cubit.state.alertNonce, 1);
      expect(cubit.state.alertName, 'Bob');
      await cubit.close();
    },
  );

  test('alert still fires when the challenger name fails to resolve', () async {
    // The name lookup throws: names are decorative and degrade to a UI
    // fallback, but the functional alert must not be swallowed with them.
    when(
      () => userRepository.getUsersByIds(any()),
    ).thenThrow(Exception('offline'));
    final cubit = build();

    incoming.add([_challenge('c1', from: 'alice')]);
    await _flush();
    expect(cubit.state.alertNonce, 0); // First snapshot never alerts.

    incoming.add([
      _challenge('c2', from: 'ghost', createdAt: DateTime(2026, 7, 6, 11)),
      _challenge('c1', from: 'alice'),
    ]);
    await _flush();
    expect(cubit.state.alertNonce, 1); // Arrival tracked independently.
    expect(cubit.state.alertName, isNull); // Unresolved → UI fallback.
    await cubit.close();
  });

  test(
    'a new arrival with an unresolved name clears a prior resolved alertName',
    () async {
      final cubit = build();

      // First real alert resolves "Bob".
      incoming.add([_challenge('c1', from: 'alice')]);
      await _flush();
      incoming.add([
        _challenge('c2', from: 'bob', createdAt: DateTime(2026, 7, 6, 11)),
        _challenge('c1', from: 'alice'),
      ]);
      await _flush();
      expect(cubit.state.alertName, 'Bob');

      // A later arrival whose name misses must not carry "Bob" forward.
      when(
        () => userRepository.getUsersByIds(any()),
      ).thenThrow(Exception('offline'));
      incoming.add([
        _challenge('c3', from: 'ghost', createdAt: DateTime(2026, 7, 6, 12)),
        _challenge('c2', from: 'bob', createdAt: DateTime(2026, 7, 6, 11)),
        _challenge('c1', from: 'alice'),
      ]);
      await _flush();
      expect(cubit.state.alertNonce, 2);
      expect(cubit.state.alertName, isNull);
      await cubit.close();
    },
  );

  test('fires expireIfDue for a stale pending streamed item', () async {
    final cubit = build();
    final stale = _challenge('old', from: 'alice', createdAt: DateTime(2020));
    incoming.add([stale]);
    await _flush();

    verify(
      () => challengeRepository.expireIfDue(stale, now: any(named: 'now')),
    ).called(1);
    await cubit.close();
  });

  test('does not expire a fresh pending item', () async {
    final cubit = build();
    incoming.add([
      _challenge('fresh', from: 'alice', createdAt: DateTime.now()),
    ]);
    await _flush();

    verifyNever(
      () => challengeRepository.expireIfDue(any(), now: any(named: 'now')),
    );
    await cubit.close();
  });

  blocTest<ChallengeCubit, ChallengeState>(
    'send success: emits sending then sent',
    setUp: () {
      when(
        () => challengeRepository.sendChallenge(
          fromUserId: _me,
          toUserId: 'bob',
          sportId: SportIds.pingPong,
        ),
      ).thenAnswer((_) async {});
    },
    build: build,
    act: (cubit) =>
        cubit.send(toUserId: 'bob', sportId: SportIds.pingPong, toName: 'Bob'),
    expect: () => [
      isA<ChallengeState>().having(
        (s) => s.sendStatus,
        'sendStatus',
        ChallengeSendStatus.sending,
      ),
      isA<ChallengeState>()
          .having((s) => s.sendStatus, 'sendStatus', ChallengeSendStatus.sent)
          .having((s) => s.lastSentToName, 'lastSentToName', 'Bob'),
    ],
  );

  blocTest<ChallengeCubit, ChallengeState>(
    'send duplicate: maps the guard to a distinct sendStatus',
    setUp: () {
      when(
        () => challengeRepository.sendChallenge(
          fromUserId: _me,
          toUserId: 'bob',
          sportId: SportIds.pingPong,
        ),
      ).thenThrow(const ChallengeException(ChallengeError.duplicatePending));
    },
    build: build,
    act: (cubit) => cubit.send(toUserId: 'bob', sportId: SportIds.pingPong),
    expect: () => [
      isA<ChallengeState>().having(
        (s) => s.sendStatus,
        'sendStatus',
        ChallengeSendStatus.sending,
      ),
      isA<ChallengeState>().having(
        (s) => s.sendStatus,
        'sendStatus',
        ChallengeSendStatus.duplicate,
      ),
    ],
  );

  blocTest<ChallengeCubit, ChallengeState>(
    'send failure: any other error maps to failed',
    setUp: () {
      when(
        () => challengeRepository.sendChallenge(
          fromUserId: any(named: 'fromUserId'),
          toUserId: any(named: 'toUserId'),
          sportId: any(named: 'sportId'),
        ),
      ).thenThrow(Exception('offline'));
    },
    build: build,
    act: (cubit) => cubit.send(toUserId: 'bob', sportId: SportIds.pingPong),
    expect: () => [
      isA<ChallengeState>().having(
        (s) => s.sendStatus,
        'sendStatus',
        ChallengeSendStatus.sending,
      ),
      isA<ChallengeState>().having(
        (s) => s.sendStatus,
        'sendStatus',
        ChallengeSendStatus.failed,
      ),
    ],
  );

  blocTest<ChallengeCubit, ChallengeState>(
    'accept delegates to respond(accept: true)',
    setUp: () {
      when(
        () => challengeRepository.respond(challengeId: 'c1', accept: true),
      ).thenAnswer((_) async {});
    },
    build: build,
    act: (cubit) => cubit.accept('c1'),
    verify: (_) => verify(
      () => challengeRepository.respond(challengeId: 'c1', accept: true),
    ).called(1),
  );

  // Each typed respond failure maps to its own actionError reason so the UI can
  // show distinct copy instead of one blanket "may have expired".
  for (final reason in ChallengeRespondError.values) {
    blocTest<ChallengeCubit, ChallengeState>(
      'a $reason respond failure bumps actionErrorNonce with that reason',
      setUp: () {
        when(
          () => challengeRepository.respond(challengeId: 'c1', accept: false),
        ).thenThrow(ChallengeRespondException(reason));
      },
      build: build,
      act: (cubit) => cubit.decline('c1'),
      expect: () => [
        isA<ChallengeState>()
            .having((s) => s.actionErrorNonce, 'actionErrorNonce', 1)
            .having((s) => s.actionError, 'actionError', reason),
      ],
    );
  }

  blocTest<ChallengeCubit, ChallengeState>(
    'an untyped respond failure is reported as unavailable (retryable)',
    setUp: () {
      when(
        () => challengeRepository.respond(challengeId: 'c1', accept: false),
      ).thenThrow(Exception('offline'));
    },
    build: build,
    act: (cubit) => cubit.decline('c1'),
    expect: () => [
      isA<ChallengeState>()
          .having((s) => s.actionErrorNonce, 'actionErrorNonce', 1)
          .having(
            (s) => s.actionError,
            'actionError',
            ChallengeRespondError.unavailable,
          ),
    ],
  );
}
