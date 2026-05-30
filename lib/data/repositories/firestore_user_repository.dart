import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_doc.dart';
import '../../domain/repositories/user_repository.dart';
import '../firebase/firebase_error_converter.dart';
import '../firebase/firestore_mappers.dart';

/// Firestore を用いた [UserRepository] 実装。
class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<void> createUserDocument(String uid) async {
    try {
      await _userRef(uid).set({
        'displayName': '',
        'avatarUrl': '',
        'groupId': null,
        'notificationsEnabled': false,
        'fcmToken': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> updateUserGroupId(String uid, String groupId) async {
    try {
      await _userRef(uid).update({'groupId': groupId});
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> updateUserProfile(
    String uid, {
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'displayName': ?displayName,
        'avatarUrl': ?avatarUrl,
      };
      if (updates.isEmpty) return;
      await _userRef(uid).update(updates);
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> deleteUserDocument(String uid) async {
    try {
      await _userRef(uid).delete();
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<UserDoc?> getUserProfile(String uid) async {
    try {
      final snap = await _userRef(uid).get();
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return userDocFromData(data);
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> updateNotificationEnabled(String uid, bool enabled) async {
    try {
      await _userRef(uid).update({'notificationsEnabled': enabled});
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Stream<UserDoc?> watchUser(String uid) {
    return _userRef(uid).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return userDocFromData(data);
    });
  }

  @override
  Future<String?> getUserGroupId(String uid) async {
    try {
      final snap = await _userRef(uid).get();
      if (!snap.exists) return null;
      return snap.data()?['groupId'] as String?;
    } catch (e) {
      throw toAppError(e);
    }
  }
}
