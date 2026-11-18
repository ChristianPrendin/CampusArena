import 'package:campus_arena/core/services/push_token_service.dart';
import 'package:campus_arena/features/settings/cubit/settings_cubit.dart';
import 'package:campus_arena/features/settings/cubit/settings_state.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/auth_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockPushTokenService extends Mock implements PushTokenService {}

const _me = 'me';

UserModel _user({List<String> pushTokens = const []}) => UserModel(
  uid: _me,
  name: 'Me',
  username: 'me',
  email: 'me@polimi.it',
  degreeProgram: 'Computer Science',
  language: 'en',
  pushTokens: pushTokens,
  friendUids: const [],
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MockUserRepository userRepository;
  late MockAuthRepository authRepository;
  late MockPushTokenService pushTokenService;

  setUp(() {
    userRepository = MockUserRepository();
    authRepository = MockAuthRepository();
    pushTokenService = MockPushTokenService();
  });

  SettingsCubit build() => SettingsCubit(
    uid: _me,
    userRepository: userRepository,
    authRepository: authRepository,
    pushTokenService: pushTokenService,
  );

  test('unavailable token disables the row and toggle is a no-op', () async {
    when(() => pushTokenService.getToken()).thenAnswer((_) async => null);
    when(
      () => userRepository.watchUser(_me),
    ).thenAnswer((_) => Stream.value(_user()));

    final cubit = build();
    await _flush();

    expect(cubit.state.notification, NotificationSetting.unavailable);
    expect(cubit.state.notificationRowEnabled, isFalse);

    await cubit.toggleNotifications();
    verifyNever(() => userRepository.addPushToken(any(), any()));
    verifyNever(() => userRepository.removePushToken(any(), any()));
    await cubit.close();
  });

  test('stays loading until the first user snapshot, then removes a registered '
      'token (no spurious disabled window)', () async {
    final controller = StreamController<UserModel?>();
    when(() => pushTokenService.getToken()).thenAnswer((_) async => 'tok');
    when(
      () => userRepository.watchUser(_me),
    ).thenAnswer((_) => controller.stream);
    when(
      () => userRepository.removePushToken(_me, 'tok'),
    ).thenAnswer((_) async {});

    final cubit = build();
    await _flush();

    // Token resolved but no user doc yet: must not flash `disabled`.
    expect(cubit.state.notification, NotificationSetting.loading);

    controller.add(_user(pushTokens: const ['tok']));
    await _flush();
    expect(cubit.state.notification, NotificationSetting.enabled);

    await cubit.toggleNotifications();
    verify(() => userRepository.removePushToken(_me, 'tok')).called(1);
    verifyNever(() => userRepository.addPushToken(any(), any()));

    await controller.close();
    await cubit.close();
  });

  test(
    'token absent from pushTokens reads as disabled; toggle registers it',
    () async {
      when(() => pushTokenService.getToken()).thenAnswer((_) async => 'tok');
      when(
        () => userRepository.watchUser(_me),
      ).thenAnswer((_) => Stream.value(_user()));
      when(
        () => userRepository.addPushToken(_me, 'tok'),
      ).thenAnswer((_) async {});

      final cubit = build();
      await _flush();

      expect(cubit.state.notification, NotificationSetting.disabled);

      await cubit.toggleNotifications();
      verify(() => userRepository.addPushToken(_me, 'tok')).called(1);
      await cubit.close();
    },
  );

  test(
    'token present in pushTokens reads as enabled; toggle deregisters it',
    () async {
      when(() => pushTokenService.getToken()).thenAnswer((_) async => 'tok');
      when(
        () => userRepository.watchUser(_me),
      ).thenAnswer((_) => Stream.value(_user(pushTokens: const ['tok'])));
      when(
        () => userRepository.removePushToken(_me, 'tok'),
      ).thenAnswer((_) async {});

      final cubit = build();
      await _flush();

      expect(cubit.state.notification, NotificationSetting.enabled);

      await cubit.toggleNotifications();
      verify(() => userRepository.removePushToken(_me, 'tok')).called(1);
      await cubit.close();
    },
  );

  test('sendPasswordReset uses the signed-in email', () async {
    when(() => pushTokenService.getToken()).thenAnswer((_) async => null);
    when(
      () => userRepository.watchUser(_me),
    ).thenAnswer((_) => Stream.value(_user()));
    when(
      () => authRepository.resetPassword(email: 'me@polimi.it'),
    ).thenAnswer((_) async {});

    final cubit = build();
    await _flush();

    final result = await cubit.sendPasswordReset();
    expect(result, PasswordResetResult.sent);
    verify(() => authRepository.resetPassword(email: 'me@polimi.it')).called(1);
    await cubit.close();
  });

  test('sendPasswordReset maps a send failure to failed', () async {
    when(() => pushTokenService.getToken()).thenAnswer((_) async => null);
    when(
      () => userRepository.watchUser(_me),
    ).thenAnswer((_) => Stream.value(_user()));
    when(
      () => authRepository.resetPassword(email: 'me@polimi.it'),
    ).thenThrow(Exception('offline'));

    final cubit = build();
    await _flush();

    final result = await cubit.sendPasswordReset();
    expect(result, PasswordResetResult.failed);
    await cubit.close();
  });
}
