import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/data/repositories/firestore_group_repository.dart';
import 'package:shopping_list_app/domain/entities/auth_user.dart';
import 'package:shopping_list_app/domain/repositories/auth_repository.dart';
import 'package:shopping_list_app/presentation/providers/group_providers.dart';
import 'package:shopping_list_app/presentation/providers/item_providers.dart';
import 'package:shopping_list_app/presentation/providers/repository_providers.dart';

/// 認証状態を任意のタイミングで null → user に遷移させられるテスト用 AuthRepository。
/// 初回ログイン（authStateProvider の null→user 遷移）を再現するために使う。
class _ControllableAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  void emit(AuthUser? user) {
    _current = user;
    _controller.add(user);
  }

  Future<void> dispose() => _controller.close();

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;
  @override
  AuthUser? get currentUser => _current;
  @override
  Future<void> deleteCurrentUser() async {}
  @override
  Future<AuthUser> signIn(String email, String password) async => _current!;
  @override
  Future<AuthUser> signUp(String email, String password) async => _current!;
  @override
  Future<void> signOut() async {}
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 80));

void main() {
  test('初回ログイン（auth null→user, グループ確定）後 itemsProvider のローディングが解除される', () async {
    final db = FakeFirebaseFirestore();
    // 既存ユーザーのグループを用意（初回ログインで読み込まれる想定）。
    final created = await FirestoreGroupRepository(
      db,
    ).createGroup('u1', 'Family', const []);
    final auth = _ControllableAuthRepository();

    final container = ProviderContainer(
      overrides: [
        firebaseFirestoreProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);

    // ダッシュボードと同様に itemsProvider を購読してライフサイクルを開始する。
    container.listen(itemsProvider, (_, _) {});
    container.listen(groupControllerProvider, (_, _) {});

    // 認証ストリームが未確定の段階（初期ローディング）。
    await _settle();

    // 初回ログイン: null → user へ遷移。
    auth.emit(const AuthUser(uid: 'u1'));

    // グループ読み込み + アイテムストリーム購読が完了するのを待つ。
    await _settle();
    await _settle();
    await _settle();

    final groupState = container.read(groupControllerProvider);
    expect(groupState.group?.id, created.groupId, reason: 'グループが確定していること');
    expect(groupState.loading, isFalse);

    final items = container.read(itemsProvider);
    // 初回ログイン直後でも itemsProvider はローディング解除済み（空リスト）であること。
    expect(
      items.isLoading,
      isFalse,
      reason: '初回ログイン後にアイテムリストがローディングのまま張り付かないこと',
    );
    expect(items.value, isNotNull);
    expect(items.value, isEmpty);
  });
}
