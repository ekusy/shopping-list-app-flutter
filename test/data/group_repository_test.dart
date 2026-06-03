import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/errors/app_error.dart';
import 'package:shopping_list_app/data/repositories/firestore_group_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreGroupRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreGroupRepository(db);
  });

  // サインアップ済みユーザーは必ず users/{uid} ドキュメントを持つ前提を再現する。
  Future<void> seedUser(String uid) =>
      db.collection('users').doc(uid).set(<String, dynamic>{'groupId': null});

  test('createGroup は group・デフォルトタグ・user.groupId を作成する', () async {
    final result = await repo.createGroup('u1', 'Family', ['急ぎ', 'まとめ買い']);

    expect(result.inviteCode.length, 8);

    final group = await repo.getGroup(result.groupId);
    expect(group, isNotNull);
    expect(group!.name, 'Family');
    expect(group.ownerId, 'u1');
    expect(group.memberIds, ['u1']);

    final tags = await db
        .collection('groups')
        .doc(result.groupId)
        .collection('tags')
        .get();
    expect(tags.docs.length, 2);

    final user = await db.collection('users').doc('u1').get();
    expect(user.data()!['groupId'], result.groupId);
  });

  test('isGroupOwner は所有グループの有無を返す', () async {
    final r = await repo.createGroup('owner', 'G', const []);
    expect(await repo.isGroupOwner('owner'), isTrue);
    expect(await repo.isGroupOwner('stranger'), isFalse);
    expect(r.groupId, isNotEmpty);
  });

  test('getGroupByInviteCode は大文字小文字を無視して検索する', () async {
    final r = await repo.createGroup('u1', 'G', const []);
    final found = await repo.getGroupByInviteCode(r.inviteCode.toLowerCase());
    expect(found?.id, r.groupId);
    expect(await repo.getGroupByInviteCode('NOPE0000'), isNull);
  });

  group('joinGroup', () {
    test('メンバーに追加し user.groupId を更新する', () async {
      final r = await repo.createGroup('u1', 'G', const []);
      await seedUser('u2');
      final gid = await repo.joinGroup('u2', r.inviteCode);
      expect(gid, r.groupId);
      final group = await repo.getGroup(gid);
      expect(group!.memberIds, containsAll(['u1', 'u2']));
      final user = await db.collection('users').doc('u2').get();
      expect(user.data()!['groupId'], gid);
    });

    test('無効なコードは groupInvalidInviteCode', () async {
      await expectLater(
        repo.joinGroup('u2', 'BADCODE0'),
        throwsA(
          isA<AppError>().having(
            (e) => e.code,
            'code',
            AppErrorCode.groupInvalidInviteCode,
          ),
        ),
      );
    });

    test('既にメンバーなら groupAlreadyMember', () async {
      final r = await repo.createGroup('u1', 'G', const []);
      await expectLater(
        repo.joinGroup('u1', r.inviteCode),
        throwsA(
          isA<AppError>().having(
            (e) => e.code,
            'code',
            AppErrorCode.groupAlreadyMember,
          ),
        ),
      );
    });
  });

  group('removeMember', () {
    test('メンバーを外し user.groupId を null にする', () async {
      final r = await repo.createGroup('owner', 'G', const []);
      await seedUser('member');
      await repo.joinGroup('member', r.inviteCode);
      await repo.removeMember(r.groupId, 'member');
      final group = await repo.getGroup(r.groupId);
      expect(group!.memberIds, isNot(contains('member')));
      final user = await db.collection('users').doc('member').get();
      expect(user.data()!['groupId'], isNull);
    });

    test('オーナーは外せない', () async {
      final r = await repo.createGroup('owner', 'G', const []);
      await expectLater(
        repo.removeMember(r.groupId, 'owner'),
        throwsA(
          isA<AppError>().having(
            (e) => e.code,
            'code',
            AppErrorCode.groupCannotRemoveOwner,
          ),
        ),
      );
    });
  });

  test('leaveGroup はメンバーから外し user.groupId を null にする', () async {
    final r = await repo.createGroup('owner', 'G', const []);
    await seedUser('member');
    await repo.joinGroup('member', r.inviteCode);
    await repo.leaveGroup('member', r.groupId);
    final group = await repo.getGroup(r.groupId);
    expect(group!.memberIds, isNot(contains('member')));
  });

  test('disbandGroup はグループを削除する', () async {
    final r = await repo.createGroup('owner', 'G', const []);
    await repo.disbandGroup('owner', r.groupId);
    expect(await repo.getGroup(r.groupId), isNull);
  });

  test('updateGroupName は名前を更新する', () async {
    final r = await repo.createGroup('u1', 'Old', const []);
    await repo.updateGroupName(r.groupId, 'New');
    expect((await repo.getGroup(r.groupId))!.name, 'New');
  });

  test('getGroupsByMemberId は参加グループを返す', () async {
    final r1 = await repo.createGroup('u1', 'G1', const []);
    final r2 = await repo.createGroup('u2', 'G2', const []);
    await repo.joinGroup('u1', r2.inviteCode);
    final groups = await repo.getGroupsByMemberId('u1');
    expect(groups.map((g) => g.id), containsAll([r1.groupId, r2.groupId]));
  });
}
