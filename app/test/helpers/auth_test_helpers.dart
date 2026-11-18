import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/auth_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

/// AuthCubit bundled with its repository mocks, for stubbing / verification.
typedef AuthCubitHarness = ({
  AuthCubit cubit,
  MockAuthRepository authRepository,
  MockUserRepository userRepository,
  MockRatingRepository ratingRepository,
});

UserModel _stubUser(String uid, bool onboardingComplete) => UserModel(
  uid: uid,
  name: 'Test',
  username: 'test',
  email: 'test@polimi.it',
  degreeProgram: 'Computer Science',
  language: 'en',
  pushTokens: const [],
  friendUids: const [],
  badges: const {},
  onboardingComplete: onboardingComplete,
  createdAt: DateTime(2026),
);

/// An [AuthCubit] whose auth stream immediately reports a signed-in user whose
/// user document loads with the given [onboardingComplete] — resolves straight
/// to the shell (onboarded) or into onboarding (not onboarded).
AuthCubit authenticatedAuthCubit({
  String uid = 'test-uid',
  bool onboardingComplete = true,
}) {
  final authRepository = MockAuthRepository();
  final userRepository = MockUserRepository();
  final user = MockUser();
  when(() => user.uid).thenReturn(uid);
  when(
    () => authRepository.authStateChanges(),
  ).thenAnswer((_) => Stream<User?>.value(user));
  when(
    () => userRepository.watchUser(uid),
  ).thenAnswer((_) => Stream.value(_stubUser(uid, onboardingComplete)));
  return AuthCubit(
    authRepository: authRepository,
    userRepository: userRepository,
    ratingRepository: MockRatingRepository(),
  );
}

/// An [AuthCubit] whose auth stream never reports a user (stays
/// unauthenticated). Returns the cubit plus mocks for verification.
AuthCubitHarness unauthenticatedAuthCubit() {
  final authRepository = MockAuthRepository();
  final userRepository = MockUserRepository();
  final ratingRepository = MockRatingRepository();
  when(
    () => authRepository.authStateChanges(),
  ).thenAnswer((_) => Stream<User?>.empty());
  final cubit = AuthCubit(
    authRepository: authRepository,
    userRepository: userRepository,
    ratingRepository: ratingRepository,
  );
  return (
    cubit: cubit,
    authRepository: authRepository,
    userRepository: userRepository,
    ratingRepository: ratingRepository,
  );
}
