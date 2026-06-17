import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/repositories/storage_repository.dart';
import '../firebase/firebase_error_converter.dart';

/// Firebase Storage を用いた [StorageRepository] 実装。
class FirebaseStorageRepository implements StorageRepository {
  FirebaseStorageRepository(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<String> uploadAvatar(String uid, Uint8List bytes) async {
    try {
      final ref = _storage.ref('avatars/$uid');
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<String> uploadItemImage(
    String groupId,
    String itemId,
    Uint8List bytes,
  ) async {
    try {
      final ref = _storage.ref('groups/$groupId/items/$itemId.jpg');
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> deleteItemImage(String groupId, String itemId) async {
    try {
      final ref = _storage.ref('groups/$groupId/items/$itemId.jpg');
      await ref.delete();
    } on FirebaseException catch (e) {
      // ファイルが存在しない場合は best-effort で無視する
      if (e.code == 'object-not-found') return;
      throw toAppError(e);
    } catch (e) {
      throw toAppError(e);
    }
  }
}
