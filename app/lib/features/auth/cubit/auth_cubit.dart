import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/user_model.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/rating_repository.dart';
import '../../../repositories/user_repository.dart';
import 'auth_state.dart';

/// Single source of auth truth for the app.
///
/// Subscribes to [AuthRepository.authStateChanges] for the
/// authenticated/unauthenticated baseline (which drives the router redirect),
/// and exposes form actions that emit transient `loading` / `error` states.
/// Firebase only fires `authStateChanges` on real transitions, so a failed
/// `signIn` / `register` never clobbers the `error` state.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    AuthRepository? authRepository,
    UserRepository? userRepository,
    RatingRepository? ratingRepository,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _userRepository = userRepository ?? UserRepository(),
       _ratingRepository = ratingRepository ?? RatingRepository(),
       super(const AuthState.initial()) {
    _authSubscription = _authRepository.authStateChanges().listen(
      _onAuthStateChanged,
    );
  }

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final RatingRepository _ratingRepository;
  late final StreamSubscription<User?> _authSubscription;
  StreamSubscription<UserModel?>? _userSubscription;

  /// Set while a profile is being provisioned — either a fresh [register] or a
  /// [provisionProfile] recovery (see [AuthState.registrationInProgress]).
  /// Carried onto every authenticated emit so the redirect holds on
  /// `RegisterScreen` until the freshly-written `users/{uid}` doc actually
  /// arrives on the `watchUser` stream. Clearing it only on that non-null
  /// snapshot (not on the write completing) keeps the redirect pinned across any
  /// transient document-absent snapshot, so it never flashes the empty
  /// profile-recovery page en route to onboarding.
  bool _registering = false;

  void _onAuthStateChanged(User? user) {
    _userSubscription?.cancel();
    _userSubscription = null;

    if (user == null) {
      emit(const AuthState.unauthenticated());
      return;
    }

    // Authenticated but the user doc hasn't loaded yet: onboardingComplete is
    // null until watchUser emits, which keeps the router on the splash.
    emit(
      AuthState.authenticated(user.uid, registrationInProgress: _registering),
    );
    _userSubscription = _userRepository.watchUser(user.uid).listen((userModel) {
      // Provisioning (register / provisionProfile) completes the instant its
      // freshly-written doc first arrives: clear the flag so the redirect can
      // advance off RegisterScreen. Until then it stays set, masking any
      // document-absent snapshot behind the registrationInProgress redirect
      // branch instead of the profileMissing one.
      if (userModel != null) _registering = false;
      emit(
        AuthState.authenticated(
          user.uid,
          // A null userModel means the users/{uid} doc is absent (not merely
          // unloaded): flag it so the router routes to profile recreation rather
          // than the dead-end onboarding tutorial. onboardingComplete stays null
          // in that case, which never reads as "onboarded".
          onboardingComplete: userModel?.onboardingComplete,
          profileMissing: userModel == null,
          registrationInProgress: _registering,
        ),
      );
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    emit(const AuthState.loading());
    try {
      await _authRepository.signIn(email: email, password: password);
      // Success path resolves via the authStateChanges stream.
    } on FirebaseAuthException catch (e) {
      emit(AuthState.error(e.code));
    }
  }

  /// Registration orchestration: create the auth user, seed one rating per
  /// supported sport, then create its `users/{uid}` document (which atomically
  /// claims the username). Ratings are seeded BEFORE the username claim on
  /// purpose: a `usernames/{handle}` claim is immutable (the Security Rules
  /// forbid delete), so it must be the last, irreversible step. Any earlier
  /// failure rolls back with a single auth-account delete — no orphaned,
  /// un-freeable handle. `_registering` keeps `RegisterScreen` mounted across
  /// the auth-state bounce so the outcome (success or error) actually surfaces.
  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required String degreeProgram,
  }) async {
    emit(const AuthState.loading());
    _registering = true;
    try {
      final credential = await _authRepository.signUp(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      final user = UserModel(
        uid: uid,
        name: name,
        username: username,
        email: email,
        degreeProgram: degreeProgram,
        language: 'en',
        pushTokens: const [],
        friendUids: const [],
        badges: const {},
        onboardingComplete: false,
        createdAt: DateTime.now(),
      );
      try {
        await _ratingRepository.seedUserRatings(
          uid: uid,
          degreeProgram: degreeProgram,
        );
        await _userRepository.createUser(user);
      } catch (_) {
        // Any seed-or-claim failure: roll back the orphaned auth account so a
        // retry isn't blocked by email-already-in-use. The username claim is
        // never half-written (createUser's transaction is atomic), so there is
        // nothing else to undo. Rethrow to the typed handlers below.
        await credential.user!.delete();
        rethrow;
      }
      // No manual terminal emit: the `watchUser` subscription (started in
      // _onAuthStateChanged) delivers the freshly-written doc, clears
      // `_registering`, and emits the authenticated state the redirect routes to
      // onboarding. Emitting here would race that stream and let a late
      // document-absent snapshot bounce the router back to an empty RegisterScreen.
    } on UsernameTakenException {
      _registering = false;
      emit(const AuthState.error('username-taken'));
    } on FirebaseAuthException catch (e) {
      _registering = false;
      emit(AuthState.error(e.code));
    } catch (_) {
      _registering = false;
      emit(const AuthState.error('registration-failed'));
    }
  }

  /// Recreates the `users/{uid}` doc (and per-sport ratings) for the CURRENT,
  /// already-authenticated user whose profile is missing — an Auth account with
  /// no profile doc (a wiped/re-seeded database, or an account that never
  /// finished provisioning). Mirrors [register]'s doc + ratings provisioning but
  /// skips `signUp`, since the account already exists; email is taken from the
  /// live Auth session. On success the profile stream re-emits with the new doc
  /// and the router moves on to onboarding.
  Future<void> provisionProfile({
    required String name,
    required String username,
    required String degreeProgram,
  }) async {
    final current = _authRepository.currentUser;
    if (current == null) return;
    emit(const AuthState.loading());
    _registering = true;
    try {
      final user = UserModel(
        uid: current.uid,
        name: name,
        username: username,
        email: current.email ?? '',
        degreeProgram: degreeProgram,
        language: 'en',
        pushTokens: const [],
        friendUids: const [],
        badges: const {},
        onboardingComplete: false,
        createdAt: DateTime.now(),
      );
      await _ratingRepository.seedUserRatings(
        uid: current.uid,
        degreeProgram: degreeProgram,
      );
      await _userRepository.createUser(user);
      // No manual terminal emit: the live `watchUser` subscription delivers the
      // recreated doc, clears `_registering`, and emits the authenticated state
      // the redirect routes to onboarding — same single-source rule as [register].
    } on UsernameTakenException {
      _registering = false;
      emit(const AuthState.error('username-taken'));
    } catch (_) {
      _registering = false;
      emit(const AuthState.error('registration-failed'));
    }
  }

  Future<void> sendPasswordReset({required String email}) async {
    emit(const AuthState.loading());
    try {
      await _authRepository.resetPassword(email: email);
      emit(const AuthState.unauthenticated());
    } on FirebaseAuthException catch (e) {
      emit(AuthState.error(e.code));
    }
  }

  Future<void> signOut() => _authRepository.signOut();

  @override
  Future<void> close() {
    _authSubscription.cancel();
    _userSubscription?.cancel();
    return super.close();
  }
}
