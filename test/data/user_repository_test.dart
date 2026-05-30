import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/data/repositories/firestore_user_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreUserRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreUserRepository(db);
  });

  test('createUserDocument は初期フィールドを設定する', () async {
    await repo.createUserDocument('u1');
    final profile = await repo.getUserProfile('u1');
    expect(profile, isNotNull);
    expect(profile!.displayName, '');
    expect(profile.groupId, isNull);
    expect(profile.notificationsEnabled, isFalse);
  });

  test('getUserProfile は未存在で null を返す', () async {
    expect(await repo.getUserProfile('missing'), isNull);
  });

  test('updateUserProfile は表示名を更新する', () async {
    await repo.createUserDocument('u1');
    await repo.updateUserProfile('u1', displayName: 'Alice');
    expect((await repo.getUserProfile('u1'))!.displayName, 'Alice');
  });

  test('updateUserGroupId / getUserGroupId', () async {
    await repo.createUserDocument('u1');
    await repo.updateUserGroupId('u1', 'g1');
    expect(await repo.getUserGroupId('u1'), 'g1');
  });

  test('updateNotificationEnabled はフラグを更新する', () async {
    await repo.createUserDocument('u1');
    await repo.updateNotificationEnabled('u1', true);
    expect((await repo.getUserProfile('u1'))!.notificationsEnabled, isTrue);
  });

  test('watchUser はドキュメント更新を流す', () async {
    await repo.createUserDocument('u1');
    await repo.updateUserProfile('u1', displayName: 'Bob');
    final user = await repo.watchUser('u1').first;
    expect(user!.displayName, 'Bob');
  });

  test('deleteUserDocument は削除する', () async {
    await repo.createUserDocument('u1');
    await repo.deleteUserDocument('u1');
    expect(await repo.getUserProfile('u1'), isNull);
  });
}
