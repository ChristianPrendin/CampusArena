import 'package:campus_arena/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth auth;
  late AuthRepository repository;

  setUp(() {
    auth = MockFirebaseAuth();
    repository = AuthRepository(auth: auth);
  });

  test('signIn delegates to signInWithEmailAndPassword', () async {
    final credential = MockUserCredential();
    when(
      () => auth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => credential);

    final result = await repository.signIn(
      email: 'a@b.com',
      password: 'secret',
    );

    expect(result, credential);
    verify(
      () =>
          auth.signInWithEmailAndPassword(email: 'a@b.com', password: 'secret'),
    ).called(1);
  });

  test('signUp delegates to createUserWithEmailAndPassword', () async {
    final credential = MockUserCredential();
    when(
      () => auth.createUserWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => credential);

    final result = await repository.signUp(
      email: 'a@b.com',
      password: 'secret',
    );

    expect(result, credential);
    verify(
      () => auth.createUserWithEmailAndPassword(
        email: 'a@b.com',
        password: 'secret',
      ),
    ).called(1);
  });

  test('signOut delegates to FirebaseAuth.signOut', () async {
    when(() => auth.signOut()).thenAnswer((_) async {});

    await repository.signOut();

    verify(() => auth.signOut()).called(1);
  });

  test('resetPassword delegates to sendPasswordResetEmail', () async {
    when(
      () => auth.sendPasswordResetEmail(email: any(named: 'email')),
    ).thenAnswer((_) async {});

    await repository.resetPassword(email: 'a@b.com');

    verify(() => auth.sendPasswordResetEmail(email: 'a@b.com')).called(1);
  });

  test('authStateChanges forwards the FirebaseAuth stream', () {
    final user = MockUser();
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<User?>.fromIterable([null, user]));

    expect(repository.authStateChanges(), emitsInOrder([null, user]));
  });

  test('currentUser forwards FirebaseAuth.currentUser', () {
    final user = MockUser();
    when(() => auth.currentUser).thenReturn(user);

    expect(repository.currentUser, user);
  });
}
