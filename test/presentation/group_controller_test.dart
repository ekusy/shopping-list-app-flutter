import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/errors/app_error.dart';
import 'package:shopping_list_app/data/repositories/firestore_group_repository.dart';
import 'package:shopping_list_app/data/repositories/firestore_tag_repository.dart';
import 'package:shopping_list_app/domain/entities/auth_user.dart';
import 'package:shopping_list_app/domain/repositories/auth_repository.dart';
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

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 80));

ProviderContainer _makeContainer(FakeFirebaseFirestore db) {
  final container = ProviderContainer(overrides: [
    firebaseFirestoreProvider.overrideWithValue(db),
    authRepositoryProvider
        .overrideWithValue(_FakeAuthRepository(const AuthUser(uid: 'u1'))),
  ]);
  // 各プロバイダを購読してライフサイクルを開始する。
  container.listen(groupControllerProvider, (_, _) {});
  container.listen(tagsProvider, (_, _) {});
  return container;
}

void main() {
  test('アクティブグループを Firestore から読み込む', () async {
    final db = FakeFirebaseFirestore();
    final r = await FirestoreGroupRepository(db)
        .createGroup('u1', 'Family', const []);

    final container = _makeContainer(db);
    addTearDown(container.dispose);

    await _settle();
    await _settle();

    final state = container.read(groupControllerProvider);
    expect(state.group?.id, r.groupId);
    expect(state.group?.name, 'Family');
    expect(state.loading, isFalse);
  });

  test('オーナーは脱退できない', () async {
    final db = FakeFirebaseFirestore();
    await FirestoreGroupRepository(db).createGroup('u1', 'Family', const []);

    final container = _makeContainer(db);
    addTearDown(container.dispose);
    await _settle();
    await _settle();

    await expectLater(
      container.read(groupControllerProvider.notifier).leaveGroup(),
      throwsA(isA<AppError>()
          .having((e) => e.code, 'code', AppErrorCode.groupOwnerCannotLeave)),
    );
  });

  test('タグ上限（無料5件）を超える追加は dataTagLimitExceeded', () async {
    final db = FakeFirebaseFirestore();
    final r = await FirestoreGroupRepository(db)
        .createGroup('u1', 'Family', const []);
    final tagRepo = FirestoreTagRepository(db);
    for (var i = 0; i < 5; i++) {
      await tagRepo.addTag(r.groupId, 'tag$i', i + 1);
    }

    final container = _makeContainer(db);
    addTearDown(container.dispose);
    await _settle();
    await _settle();

    expect(container.read(tagsProvider).value?.length, 5);

    await expectLater(
      container.read(groupControllerProvider.notifier).addTag('over'),
      throwsA(isA<AppError>()
          .having((e) => e.code, 'code', AppErrorCode.dataTagLimitExceeded)),
    );
  });
}
