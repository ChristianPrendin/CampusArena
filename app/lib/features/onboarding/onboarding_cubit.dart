import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/user_repository.dart';

enum OnboardingStatus { idle, saving, error }

/// Drives the onboarding walkthrough. Its sole side effect is flipping
/// `onboardingComplete` on the user doc when the mini-tutorial finishes; the
/// router's onboarding guard reacts to the resulting `watchUser` emission and
/// routes to home — no manual navigation here.
class OnboardingCubit extends Cubit<OnboardingStatus> {
  OnboardingCubit({required this.uid, UserRepository? userRepository})
    : _userRepository = userRepository ?? UserRepository(),
      super(OnboardingStatus.idle);

  final String uid;
  final UserRepository _userRepository;

  Future<void> completeOnboarding() async {
    emit(OnboardingStatus.saving);
    try {
      await _userRepository.updateUser(uid, {'onboardingComplete': true});
    } catch (e, stackTrace) {
      // Keep the friendly error state, but never swallow the real cause —
      // a bare `catch (_)` here would hide Firestore errors (permissions,
      // missing index, offline) behind a generic error banner.
      debugPrint('[Onboarding] completeOnboarding failed: $e');
      debugPrintStack(stackTrace: stackTrace, label: 'Onboarding');
      emit(OnboardingStatus.error);
    }
  }
}
