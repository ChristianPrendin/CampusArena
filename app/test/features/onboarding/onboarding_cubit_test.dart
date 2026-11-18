import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/features/onboarding/onboarding_cubit.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  late _MockUserRepository userRepository;

  setUp(() {
    userRepository = _MockUserRepository();
  });

  OnboardingCubit buildCubit() =>
      OnboardingCubit(uid: 'u1', userRepository: userRepository);

  test('initial state is idle', () {
    expect(buildCubit().state, OnboardingStatus.idle);
  });

  blocTest<OnboardingCubit, OnboardingStatus>(
    'completeOnboarding flips onboardingComplete and emits saving',
    setUp: () => when(
      () => userRepository.updateUser(any(), any()),
    ).thenAnswer((_) async {}),
    build: buildCubit,
    act: (cubit) => cubit.completeOnboarding(),
    expect: () => [OnboardingStatus.saving],
    verify: (_) {
      verify(
        () => userRepository.updateUser('u1', {'onboardingComplete': true}),
      ).called(1);
    },
  );

  blocTest<OnboardingCubit, OnboardingStatus>(
    'completeOnboarding emits error when the write fails',
    setUp: () => when(
      () => userRepository.updateUser(any(), any()),
    ).thenThrow(Exception('offline')),
    build: buildCubit,
    act: (cubit) => cubit.completeOnboarding(),
    expect: () => [OnboardingStatus.saving, OnboardingStatus.error],
  );
}
