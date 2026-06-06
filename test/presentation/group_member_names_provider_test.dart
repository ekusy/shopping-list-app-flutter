import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/domain/entities/auth_user.dart';
import 'package:shopping_list_app/domain/repositories/auth_repository.dart';
import 'package:shopping_list_app/presentation/providers/group_members_provider.dart';
import 'package:shopping_list_app/presentation/providers/group_providers.dart';
import 'package:shopping_list_app/presentation/providers/repository_providers.dart';

/// 固定ユーザーを返すテスト用 AuthRepository。
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._user);
  final AuthUser? _user;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(_user);
  @override
  AuthUser? get currentUser => _user;
  @override
  Future<void> deleteCurrentUser() async {}
  @override
  Future<AuthUser> signIn(String email, String password) async => _user!;
  @override
  Future<AuthUser> signUp(String email, String password) async => _user!;
  @override
  Future<void> signOut() async {}
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 80));

void main() {
  // #22: 同一グループのメンバーの user ドキュメントを購読し、
  // displayName が設定されていれば uid フォールバックではなく displayName を返すこと。
  test('メンバーの displayName を解決し、未設定時のみ uid 先頭6文字にフォールバックする', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('groups').doc('g1').set({
      'name': 'Family',
      'ownerId': 'u1',
      'memberIds': ['u1', 'u2', 'longuid000001'],
      'inviteCode': 'CODE12',
    });
    await db.collection('users').doc('u1').set({
      'displayName': 'Alice',
      'groupId': 'g1',
    });
    await db.collection('users').doc('u2').set({
      'displayName': 'Bob',
      'groupId': 'g1',
    });
    // displayName 未設定のメンバーは uid 先頭6文字にフォールバックする。
    await db.collection('users').doc('longuid000001').set({
      'displayName': '',
      'groupId': 'g1',
    });

    final container = ProviderContainer(
      overrides: [
        firebaseFirestoreProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(const AuthUser(uid: 'u1')),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(groupControllerProvider, (_, _) {});
    container.listen(groupMemberNamesProvider, (_, _) {});

    await _settle();
    await _settle();

    final names = container.read(groupMemberNamesProvider).value;
    expect(names?['u1'], 'Alice');
    expect(names?['u2'], 'Bob');
    expect(names?['longuid000001'], 'longui');
  });
}
