import 'dart:async';

import 'package:campus_arena/core/bracket/bracket_engine.dart' as engine;
import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/tournaments/cubit/tournament_detail_cubit.dart';
import 'package:campus_arena/features/tournaments/cubit/tournament_detail_state.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/models/tournament_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/tournament_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
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
  Map<String, List<String>> bracket = const {},
  int max = 8,
}) => TournamentModel(
  tournamentId: _tid,
  name: 'Cup',
  sportId: SportIds.pingPong,
  facilityId: 'f1',
  organizerId: organizerId,
  maxParticipants: max,
  status: status,
  bracket: bracket,
  eloMultiplier: 1.5,
  registrationDeadline: DateTime(2026, 7, 5),
  scheduledAt: DateTime(2026, 7, 6),
  createdAt: DateTime(2026, 6, 30),
);

TournamentParticipantModel _p(String uid, int seed, {bool out = false}) =>
    TournamentParticipantModel(uid: uid, seed: seed, eliminated: out);

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

RatingModel _rating(String uid, int elo) => RatingModel(
  ratingId: RatingRepository.ratingId(SportIds.pingPong, uid),
  ownerType: OwnerType.user,
  ownerId: uid,
  sportId: SportIds.pingPong,
  elo: elo,
  matchesPlayed: 3,
  lastMatchAt: DateTime(2026, 6, 30),
);

void main() {
  late MockTournamentRepository tournamentRepository;
  late MockMatchRepository matchRepository;
  late MockUserRepository userRepository;
  late MockRatingRepository ratingRepository;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

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
      () => ratingRepository.getUserRatings(any(), any()),
    ).thenAnswer((_) async => const <String, RatingModel>{});
    // The shared base fires the lazy Spark-tier healings; stub them as no-ops.
    when(
      () => tournamentRepository.seedIfDue(any(), now: any(named: 'now')),
    ).thenAnswer((_) async {});
    when(
      () => tournamentRepository.activateIfStarted(any()),
    ).thenAnswer((_) async {});
    when(
      () => tournamentRepository.completeIfDecided(any(), any()),
    ).thenAnswer((_) async {});
  });

  TournamentDetailCubit build({String uid = _organizer}) =>
      TournamentDetailCubit(
        tournamentId: _tid,
        uid: uid,
        tournamentRepository: tournamentRepository,
        matchRepository: matchRepository,
        userRepository: userRepository,
        ratingRepository: ratingRepository,
      );

  void streamTournament(TournamentModel t) {
    when(
      () => tournamentRepository.watchTournament(_tid),
    ).thenAnswer((_) => Stream.value(t));
  }

  void streamParticipants(List<TournamentParticipantModel> ps) {
    when(
      () => tournamentRepository.watchParticipants(_tid),
    ).thenAnswer((_) => Stream.value(ps));
  }

  test('constructor emits the initial loading state synchronously', () {
    final cubit = build();
    addTearDown(cubit.close);
    expect(cubit.state.status, TournamentDetailStatus.loading);
    expect(cubit.state.isOrganizer, isFalse);
  });

  test('standings put alive first then eliminated, each by ELO desc', () async {
    streamTournament(_tournament());
    streamParticipants([
      _p('u1', 1),
      _p('u2', 2, out: true),
      _p('u3', 3),
      _p('u4', 4),
    ]);
    when(() => ratingRepository.getUserRatings(any(), any())).thenAnswer(
      (_) async => {
        'u1': _rating('u1', 1600),
        'u2': _rating('u2', 1700),
        'u3': _rating('u3', 1500),
        'u4': _rating('u4', 1550),
      },
    );

    final cubit = build();
    addTearDown(cubit.close);
    cubit.init();
    await pumpEventQueue();

    expect(cubit.state.status, TournamentDetailStatus.ready);
    // u2 is flagged (dimmed, last); the alive trio orders by ELO descending.
    expect(cubit.state.standings.map((s) => s.uid), ['u1', 'u4', 'u3', 'u2']);
    expect(cubit.state.standings.last.eliminated, isTrue);
    expect(cubit.state.isOrganizer, isTrue);
  });

  void streamMatches(List<MatchModel> matches) {
    when(
      () => matchRepository.watchTournamentMatches(
        any(),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => Stream.value(matches));
  }

  MatchModel confirmedFinal({String? round = 'final'}) => MatchModel(
    matchId: 'm1',
    facilityId: 'f1',
    sportId: SportIds.pingPong,
    mode: 'singles',
    playerUids: const ['u1', 'u2'],
    state: MatchStates.confirmed,
    result: const PingPongResult(
      winnerIds: ['u1'],
      sets: [11, 11],
      opponentSets: [8, 6],
    ),
    tournamentId: _tid,
    tournamentRound: round,
    startedAt: DateTime(2026, 7, 6, 18),
  );

  test('a confirmed-match loser is eliminated without a flag', () async {
    streamTournament(
      _tournament(
        bracket: const {
          'final': ['m1'],
        },
      ),
    );
    streamParticipants([_p('u1', 1), _p('u2', 2)]);
    streamMatches([confirmedFinal()]);

    final cubit = build();
    addTearDown(cubit.close);
    cubit.init();
    await pumpEventQueue();

    final u2 = cubit.state.standings.firstWhere((s) => s.uid == 'u2');
    expect(u2.eliminated, isTrue, reason: 'lost a confirmed match');
    final u1 = cubit.state.standings.firstWhere((s) => s.uid == 'u1');
    expect(u1.eliminated, isFalse);
  });

  test(
    'a confirmed match missing from bracket[] still resolves by round',
    () async {
      // recordBracketMatch failed to persist, so the bracket map is empty — the
      // engine must still resolve the slot from the match's own tournamentRound.
      streamTournament(_tournament(bracket: const {}));
      streamParticipants([_p('u1', 1), _p('u2', 2)]);
      streamMatches([confirmedFinal()]);

      final cubit = build();
      addTearDown(cubit.close);
      cubit.init();
      await pumpEventQueue();

      final u2 = cubit.state.standings.firstWhere((s) => s.uid == 'u2');
      expect(u2.eliminated, isTrue, reason: 'resolved from tournamentRound');
    },
  );

  test('a dead match stream is never papered over by later data', () async {
    // The match stream errors permanently; the tournament + participants
    // streams stay healthy and re-emit afterwards. The screen must latch on
    // `error` (retry reachable) rather than flip back to a healthy-looking view
    // whose standings would silently stop tracking confirmed results.
    streamTournament(_tournament());
    final participants = StreamController<List<TournamentParticipantModel>>();
    when(
      () => tournamentRepository.watchParticipants(_tid),
    ).thenAnswer((_) => participants.stream);
    when(
      () => matchRepository.watchTournamentMatches(
        any(),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => Stream<List<MatchModel>>.error(Exception('dead')));

    final cubit = build();
    addTearDown(cubit.close);
    cubit.init();
    participants.add([_p('u1', 1), _p('u2', 2)]);
    await pumpEventQueue();
    expect(cubit.state.status, TournamentDetailStatus.error);

    // A later participants emission must not resurrect a ready view.
    participants.add([_p('u1', 1)]);
    await pumpEventQueue();
    expect(cubit.state.status, TournamentDetailStatus.error);
    await participants.close();
  });

  test('advanceSlot aborts when the slot already resolved', () async {
    // The Advance sheet holds a slot snapshot from when it opened; a real result
    // confirmed meanwhile must win. Picking the losing side here would otherwise
    // flag the true winner eliminated.
    streamTournament(
      _tournament(
        bracket: const {
          'final': ['m1'],
        },
      ),
    );
    streamParticipants([_p('u1', 1), _p('u2', 2)]);
    streamMatches([confirmedFinal()]); // u1 beat u2, slot now resolved
    when(
      () => tournamentRepository.updateParticipant(any(), any(), any()),
    ).thenAnswer((_) async {});

    final cubit = build();
    addTearDown(cubit.close);
    cubit.init();
    await pumpEventQueue();

    // A stale snapshot of the (now-decided) final, declaring the real loser u2.
    final staleSlot = engine.BracketSlot(
      round: 'final',
      index: 0,
      a: engine.BracketSide(uid: 'u1'),
      b: engine.BracketSide(uid: 'u2'),
    );
    await cubit.advanceSlot(staleSlot, 'u2');

    verifyNever(
      () => tournamentRepository.updateParticipant(any(), any(), any()),
    );
  });

  test('error view retry resubscribes and recovers', () async {
    var calls = 0;
    when(() => tournamentRepository.watchTournament(_tid)).thenAnswer((_) {
      calls++;
      return calls == 1
          ? Stream<TournamentModel?>.error(Exception('load failed'))
          : Stream.value(_tournament());
    });
    streamParticipants([_p('u1', 1), _p('u2', 2)]);

    final cubit = build();
    addTearDown(cubit.close);
    cubit.init();
    await pumpEventQueue();
    expect(cubit.state.status, TournamentDetailStatus.error);

    cubit.retry();
    await pumpEventQueue();
    expect(cubit.state.status, TournamentDetailStatus.ready);
  });

  test('markForfeit flags the chosen participant', () async {
    streamTournament(_tournament());
    streamParticipants([_p('u1', 1), _p('u2', 2)]);
    when(
      () => tournamentRepository.updateParticipant(any(), any(), any()),
    ).thenAnswer((_) async {});

    final cubit = build();
    addTearDown(cubit.close);
    cubit.init();
    await pumpEventQueue();

    await cubit.markForfeit('u2');
    verify(
      () => tournamentRepository.updateParticipant(_tid, 'u2', {
        'eliminated': true,
        'eliminationReason': EliminationReason.forfeit,
      }),
    ).called(1);
  });

  test('advanceSlot flags the non-winning side', () async {
    streamTournament(_tournament());
    streamParticipants([_p('u1', 1), _p('u2', 2)]);
    when(
      () => tournamentRepository.updateParticipant(any(), any(), any()),
    ).thenAnswer((_) async {});

    final cubit = build();
    addTearDown(cubit.close);
    cubit.init();
    await pumpEventQueue();

    final slot = cubit.state.playableSlots.single;
    await cubit.advanceSlot(slot, 'u1');
    verify(
      () => tournamentRepository.updateParticipant(_tid, 'u2', {
        'eliminated': true,
        'eliminationReason': EliminationReason.advanced,
      }),
    ).called(1);
  });

  test('cancel sets the tournament status to cancelled', () async {
    streamTournament(_tournament(status: TournamentStatus.registering));
    streamParticipants([_p('u1', 1)]);
    when(
      () => tournamentRepository.updateTournament(any(), any()),
    ).thenAnswer((_) async {});

    final cubit = build();
    addTearDown(cubit.close);
    cubit.init();
    await pumpEventQueue();

    await cubit.cancel();
    verify(
      () => tournamentRepository.updateTournament(_tid, {
        'status': TournamentStatus.cancelled,
      }),
    ).called(1);
  });
}
