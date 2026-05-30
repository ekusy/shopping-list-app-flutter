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
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      throw toAppError(e);
    }
  }
}
