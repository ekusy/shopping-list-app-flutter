import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/data/repositories/firebase_auth_repository.dart';

void main() {
  test('signIn は AuthUser を返す', () async {
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'u1', email: 'a@b.com'),
    );
    final repo = FirebaseAuthRepository(auth);
    final user = await repo.signIn('a@b.com', 'pw');
    expect(user.uid, 'u1');
    expect(user.email, 'a@b.com');
  });

  test('signUp は AuthUser を返す', () async {
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'new', email: 'n@b.com'),
    );
    final repo = FirebaseAuthRepository(auth);
    final user = await repo.signUp('n@b.com', 'pw123456');
    // モックは作成時にランダム uid を採番する。email で検証する。
    expect(user.email, 'n@b.com');
    expect(user.uid, isNotEmpty);
  });

  test('authStateChanges はサインイン済みユーザーを流す', () async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'a@b.com'),
    );
    final repo = FirebaseAuthRepository(auth);
    expect(repo.currentUser?.uid, 'u1');
    final emitted = await repo.authStateChanges().first;
    expect(emitted?.uid, 'u1');
  });

  test('signOut でログアウトする', () async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1'),
    );
    final repo = FirebaseAuthRepository(auth);
    await repo.signOut();
    expect(repo.currentUser, isNull);
  });
}
