import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/features/auth/cubit/auth_state.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/auth_test_helpers.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockUserRepository userRepository;
  late MockRatingRepository ratingRepository;
  late StreamController<User?> authStateController;
  late StreamController<UserModel?> docStream;

  final mockUserModel = UserModel(
    uid: 'u1',
    name: 'Test',
    username: 'test',
    email: 'test@test.com',
    degreeProgram: 'Test',
    language: 'en',
    pushTokens: const [],
    friendUids: const [],
    badges: const {},
    onboardingComplete: true,
    createdAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(
      UserModel(
        uid: 'fallback',
        name: '',
        username: '',
        email: '',
        degreeProgram: '',
        language: 'en',
        pushTokens: const [],
        friendUids: const [],
        badges: const {},
        onboardingComplete: false,
        createdAt: DateTime(2026),
      ),
    );
  });

  setUp(() {
    authRepository = MockAuthRepository();
    userRepository = MockUserRepository();
    ratingRepository = MockRatingRepository();
    authStateController = StreamController<User?>.broadcast();
    docStream = StreamController<UserModel?>.broadcast();
    when(
      () => authRepository.authStateChanges(),
    ).thenAnswer((_) => authStateController.stream);
    when(
      () => userRepository.watchUser(any()),
    ).thenAnswer((_) => Stream.value(mockUserModel));
  });

  tearDown(() {
    authStateController.close();
    docStream.close();
  });

  AuthCubit buildCubit() => AuthCubit(
    authRepository: authRepository,
    userRepository: userRepository,
    ratingRepository: ratingRepository,
  );

  UserModel userDoc({required bool onboardingComplete}) => UserModel(
    uid: 'u1',
    name: 'Ada',
    username: 'ada',
    email: 'a@b.com',
    degreeProgram: 'CS',
    language: 'en',
    pushTokens: const [],
    friendUids: const [],
    badges: const {},
    onboardingComplete: onboardingComplete,
    createdAt: DateTime(2026),
  );

  test('initial state is AuthState.initial', () {
    final cubit = buildCubit();
    expect(cubit.state, const AuthState.initial());
    cubit.close();
  });

  blocTest<AuthCubit, AuthState>(
    'emits authenticated, then carries onboardingComplete from the user doc',
    build: () {
      when(
        () => userRepository.watchUser('u1'),
      ).thenAnswer((_) => Stream.value(userDoc(onboardingComplete: false)));
      return buildCubit();
    },
    act: (_) {
      final user = MockUser();
      when(() => user.uid).thenReturn('u1');
      authStateController.add(user);
    },
    expect: () => [
      const AuthState.authenticated('u1'),
      const AuthState.authenticated('u1', onboardingComplete: false),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'emits unauthenticated when the auth stream reports null',
    build: buildCubit,
    act: (_) => authStateController.add(null),
    expect: () => [const AuthState.unauthenticated()],
  );

  blocTest<AuthCubit, AuthState>(
    'signIn emits [loading, error] on FirebaseAuthException',
    build: () {
      when(
        () => authRepository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'wrong-password'));
      return buildCubit();
    },
    act: (cubit) => cubit.signIn(email: 'a@b.com', password: 'bad'),
    expect: () => [
      const AuthState.loading(),
      const AuthState.error('wrong-password'),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'signIn emits [loading] then authenticated via the stream on success',
    build: () {
      when(
        () => authRepository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => MockUserCredential());
      when(
        () => userRepository.watchUser('u1'),
      ).thenAnswer((_) => Stream.value(userDoc(onboardingComplete: true)));
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.signIn(email: 'a@b.com', password: 'secret1');
      final user = MockUser();
      when(() => user.uid).thenReturn('u1');
      authStateController.add(user);
    },
    expect: () => [
      const AuthState.loading(),
      const AuthState.authenticated('u1'),
      const AuthState.authenticated('u1', onboardingComplete: true),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'register seeds user doc and ratings, then lets the stream drive the '
    'terminal authenticated state',
    build: () {
      final credential = MockUserCredential();
      final user = MockUser();
      when(() => user.uid).thenReturn('new-uid');
      when(() => credential.user).thenReturn(user);
      // signUp reports the new auth user (as Firebase does), which starts the
      // watchUser subscription — the single source of the terminal state.
      when(
        () => authRepository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {
        authStateController.add(user);
        return credential;
      });
      when(
        () => userRepository.watchUser('new-uid'),
      ).thenAnswer((_) => Stream.value(userDoc(onboardingComplete: false)));
      when(() => userRepository.createUser(any())).thenAnswer((_) async {});
      when(
        () => ratingRepository.seedUserRatings(
          uid: any(named: 'uid'),
          degreeProgram: any(named: 'degreeProgram'),
        ),
      ).thenAnswer((_) async {});
      return buildCubit();
    },
    act: (cubit) => cubit.register(
      name: 'Ada',
      username: 'ada',
      email: 'a@b.com',
      password: 'secret1',
      degreeProgram: 'Computer Science',
    ),
    // No manual terminal emit: the auth user holds on RegisterScreen
    // (registrationInProgress: true), and the freshly-written doc clears the flag
    // and moves the router off RegisterScreen into onboarding.
    expect: () => [
      const AuthState.loading(),
      const AuthState.authenticated('new-uid', registrationInProgress: true),
      const AuthState.authenticated('new-uid', onboardingComplete: false),
    ],
    verify: (_) {
      verify(
        () => userRepository.createUser(
          any(
            that: isA<UserModel>()
                .having((u) => u.uid, 'uid', 'new-uid')
                .having((u) => u.username, 'username', 'ada')
                .having((u) => u.onboardingComplete, 'onboarding', false),
          ),
        ),
      ).called(1);
      verify(
        () => ratingRepository.seedUserRatings(
          uid: 'new-uid',
          degreeProgram: 'Computer Science',
        ),
      ).called(1);
    },
  );

  blocTest<AuthCubit, AuthState>(
    'register masks a transient document-absent snapshot until the real doc '
    'arrives, never flashing profileMissing',
    build: () {
      final credential = MockUserCredential();
      final user = MockUser();
      when(() => user.uid).thenReturn('new-uid');
      when(() => credential.user).thenReturn(user);
      when(
        () => authRepository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {
        authStateController.add(user);
        return credential;
      });
      // watchUser delivers the document-absent (null) snapshot first, then the
      // freshly-written doc — the exact out-of-order sequence that used to bounce
      // the router to an empty RegisterScreen.
      when(
        () => userRepository.watchUser('new-uid'),
      ).thenAnswer((_) => docStream.stream);
      when(() => userRepository.createUser(any())).thenAnswer((_) async {});
      when(
        () => ratingRepository.seedUserRatings(
          uid: any(named: 'uid'),
          degreeProgram: any(named: 'degreeProgram'),
        ),
      ).thenAnswer((_) async {});
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.register(
        name: 'Ada',
        username: 'ada',
        email: 'a@b.com',
        password: 'secret1',
        degreeProgram: 'Computer Science',
      );
      docStream.add(null);
      docStream.add(userDoc(onboardingComplete: false));
    },
    // The null snapshot stays masked (registrationInProgress: true) rather than
    // reading as profileMissing; only the real doc clears the flag.
    expect: () => [
      const AuthState.loading(),
      const AuthState.authenticated('new-uid', registrationInProgress: true),
      const AuthState.authenticated(
        'new-uid',
        profileMissing: true,
        registrationInProgress: true,
      ),
      const AuthState.authenticated('new-uid', onboardingComplete: false),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'register emits error and writes nothing when signUp fails',
    build: () {
      when(
        () => authRepository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      return buildCubit();
    },
    act: (cubit) => cubit.register(
      name: 'Ada',
      username: 'ada',
      email: 'a@b.com',
      password: 'secret1',
      degreeProgram: 'Computer Science',
    ),
    expect: () => [
      const AuthState.loading(),
      const AuthState.error('email-already-in-use'),
    ],
    verify: (_) {
      verifyNever(() => userRepository.createUser(any()));
      verifyNever(
        () => ratingRepository.seedUserRatings(
          uid: any(named: 'uid'),
          degreeProgram: any(named: 'degreeProgram'),
        ),
      );
    },
  );

  blocTest<AuthCubit, AuthState>(
    'register rolls back the auth account and errors when the username is taken',
    build: () {
      final credential = MockUserCredential();
      final user = MockUser();
      when(() => user.uid).thenReturn('new-uid');
      when(() => user.delete()).thenAnswer((_) async {});
      when(() => credential.user).thenReturn(user);
      when(
        () => authRepository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => credential);
      // Ratings seed first (before the irreversible username claim), so it must
      // succeed for the flow to reach createUser.
      when(
        () => ratingRepository.seedUserRatings(
          uid: any(named: 'uid'),
          degreeProgram: any(named: 'degreeProgram'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => userRepository.createUser(any()),
      ).thenThrow(const UsernameTakenException('ada'));
      return buildCubit();
    },
    act: (cubit) => cubit.register(
      name: 'Ada',
      username: 'ada',
      email: 'a@b.com',
      password: 'secret1',
      degreeProgram: 'Computer Science',
    ),
    expect: () => [
      const AuthState.loading(),
      const AuthState.error('username-taken'),
    ],
    verify: (_) {
      // The orphaned auth account is deleted; ratings were seeded first (a dead
      // uid's ratings are harmless), but no username claim was ever written.
      verify(
        () => ratingRepository.seedUserRatings(
          uid: 'new-uid',
          degreeProgram: 'Computer Science',
        ),
      ).called(1);
    },
  );

  blocTest<AuthCubit, AuthState>(
    'register rolls back and errors on a transient createUser failure',
    build: () {
      final credential = MockUserCredential();
      final user = MockUser();
      when(() => user.uid).thenReturn('new-uid');
      when(() => user.delete()).thenAnswer((_) async {});
      when(() => credential.user).thenReturn(user);
      when(
        () => authRepository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => credential);
      when(
        () => ratingRepository.seedUserRatings(
          uid: any(named: 'uid'),
          degreeProgram: any(named: 'degreeProgram'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => userRepository.createUser(any()),
      ).thenThrow(Exception('network blip'));
      return buildCubit();
    },
    act: (cubit) => cubit.register(
      name: 'Ada',
      username: 'ada',
      email: 'a@b.com',
      password: 'secret1',
      degreeProgram: 'Computer Science',
    ),
    // Any non-taken createUser failure surfaces a generic registration error,
    // after deleting the orphaned auth account.
    expect: () => [
      const AuthState.loading(),
      const AuthState.error('registration-failed'),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'register rolls back and errors when seeding ratings fails, never claiming '
    'a handle',
    build: () {
      final credential = MockUserCredential();
      final user = MockUser();
      when(() => user.uid).thenReturn('new-uid');
      when(() => user.delete()).thenAnswer((_) async {});
      when(() => credential.user).thenReturn(user);
      when(
        () => authRepository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => credential);
      when(
        () => ratingRepository.seedUserRatings(
          uid: any(named: 'uid'),
          degreeProgram: any(named: 'degreeProgram'),
        ),
      ).thenThrow(Exception('offline'));
      return buildCubit();
    },
    act: (cubit) => cubit.register(
      name: 'Ada',
      username: 'ada',
      email: 'a@b.com',
      password: 'secret1',
      degreeProgram: 'Computer Science',
    ),
    expect: () => [
      const AuthState.loading(),
      const AuthState.error('registration-failed'),
    ],
    verify: (_) {
      // Seed fails before the irreversible username claim, so createUser (which
      // would write an un-deletable handle) is never reached.
      verifyNever(() => userRepository.createUser(any()));
    },
  );

  blocTest<AuthCubit, AuthState>(
    'flags profileMissing when the authenticated user has no profile doc',
    build: () {
      when(
        () => userRepository.watchUser('u1'),
      ).thenAnswer((_) => Stream<UserModel?>.value(null));
      return buildCubit();
    },
    act: (_) {
      final user = MockUser();
      when(() => user.uid).thenReturn('u1');
      authStateController.add(user);
    },
    expect: () => [
      const AuthState.authenticated('u1'),
      // Doc absent: onboardingComplete stays null (never reads as onboarded) and
      // profileMissing is set so the router routes to profile recreation.
      const AuthState.authenticated('u1', profileMissing: true),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'provisionProfile recreates the doc for the current uid without signUp',
    build: () {
      final user = MockUser();
      when(() => user.uid).thenReturn('u1');
      when(() => user.email).thenReturn('a@b.com');
      when(() => authRepository.currentUser).thenReturn(user);
      when(() => userRepository.createUser(any())).thenAnswer((_) async {});
      when(
        () => ratingRepository.seedUserRatings(
          uid: any(named: 'uid'),
          degreeProgram: any(named: 'degreeProgram'),
        ),
      ).thenAnswer((_) async {});
      return buildCubit();
    },
    act: (cubit) => cubit.provisionProfile(
      name: 'Ada',
      username: 'ada',
      degreeProgram: 'Computer Science',
    ),
    // Only the transient loading emit here: the terminal authenticated state now
    // arrives via the live watchUser stream (clearing registrationInProgress once
    // the recreated doc lands), exercised end-to-end in the routing integration
    // test (register_flow_test.dart).
    expect: () => [const AuthState.loading()],
    verify: (_) {
      verifyNever(
        () => authRepository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
      verify(
        () => userRepository.createUser(
          any(
            that: isA<UserModel>()
                .having((u) => u.uid, 'uid', 'u1')
                .having((u) => u.username, 'username', 'ada')
                .having((u) => u.email, 'email', 'a@b.com')
                .having((u) => u.onboardingComplete, 'onboarding', false),
          ),
        ),
      ).called(1);
      verify(
        () => ratingRepository.seedUserRatings(
          uid: 'u1',
          degreeProgram: 'Computer Science',
        ),
      ).called(1);
    },
  );

  blocTest<AuthCubit, AuthState>(
    'provisionProfile surfaces a taken username',
    build: () {
      final user = MockUser();
      when(() => user.uid).thenReturn('u1');
      when(() => user.email).thenReturn('a@b.com');
      when(() => authRepository.currentUser).thenReturn(user);
      when(
        () => ratingRepository.seedUserRatings(
          uid: any(named: 'uid'),
          degreeProgram: any(named: 'degreeProgram'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => userRepository.createUser(any()),
      ).thenThrow(const UsernameTakenException('ada'));
      return buildCubit();
    },
    act: (cubit) => cubit.provisionProfile(
      name: 'Ada',
      username: 'ada',
      degreeProgram: 'Computer Science',
    ),
    expect: () => [
      const AuthState.loading(),
      const AuthState.error('username-taken'),
    ],
  );

  test('signOut delegates to the repository', () async {
    when(() => authRepository.signOut()).thenAnswer((_) async {});
    final cubit = buildCubit();

    await cubit.signOut();

    verify(() => authRepository.signOut()).called(1);
    await cubit.close();
  });
}
