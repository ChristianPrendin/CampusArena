import 'package:campus_arena/features/settings/cubit/locale_cubit.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late MockUserRepository repository;

  setUp(() {
    repository = MockUserRepository();
  });

  test('initial state follows the system locale (null)', () {
    final cubit = LocaleCubit(userRepository: repository);
    expect(cubit.state, isNull);
    cubit.close();
  });

  test('seed applies a supported stored language without persisting', () {
    final cubit = LocaleCubit(userRepository: repository);
    cubit.seed('it');
    expect(cubit.state, const Locale('it'));
    verifyNever(() => repository.updateUser(any(), any()));
    cubit.close();
  });

  test('seed ignores a null or unsupported language', () {
    final cubit = LocaleCubit(userRepository: repository);
    cubit.seed(null);
    expect(cubit.state, isNull);
    cubit.seed('fr');
    expect(cubit.state, isNull);
    cubit.close();
  });

  test(
    'setLanguage emits the locale and persists via the repository',
    () async {
      when(
        () => repository.updateUser('me', {'language': 'it'}),
      ).thenAnswer((_) async {});

      final cubit = LocaleCubit(userRepository: repository);
      await cubit.setLanguage('me', 'it');

      expect(cubit.state, const Locale('it'));
      verify(() => repository.updateUser('me', {'language': 'it'})).called(1);
      cubit.close();
    },
  );

  test('seed is a no-op once the language was set manually', () async {
    when(
      () => repository.updateUser('me', {'language': 'it'}),
    ).thenAnswer((_) async {});

    final cubit = LocaleCubit(userRepository: repository);
    await cubit.setLanguage('me', 'it');
    // A slow cold-start read resolving after the manual toggle must not revert.
    cubit.seed('en');

    expect(cubit.state, const Locale('it'));
    cubit.close();
  });
}
