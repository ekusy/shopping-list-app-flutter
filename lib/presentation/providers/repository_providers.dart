import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firebase_auth_repository.dart';
import '../../data/repositories/firebase_storage_repository.dart';
import '../../data/repositories/firestore_group_repository.dart';
import '../../data/repositories/firestore_item_repository.dart';
import '../../data/repositories/firestore_tag_repository.dart';
import '../../data/repositories/firestore_user_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/group_repository.dart';
import '../../domain/repositories/item_repository.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../domain/repositories/tag_repository.dart';
import '../../domain/repositories/user_repository.dart';

/// Firebase SDK インスタンスの DI プロバイダ群。
///
/// 上位のリポジトリプロバイダは、テスト時にここではなくリポジトリプロバイダ自体を
/// override（fake 実装に差し替え）するため、テストではこれらは評価されない。
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firebaseFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);

// --- リポジトリプロバイダ（ドメイン抽象を返す。テストで override 可能） ---

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(ref.watch(firebaseAuthProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => FirestoreUserRepository(ref.watch(firebaseFirestoreProvider)),
);

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => FirestoreGroupRepository(ref.watch(firebaseFirestoreProvider)),
);

final tagRepositoryProvider = Provider<TagRepository>(
  (ref) => FirestoreTagRepository(ref.watch(firebaseFirestoreProvider)),
);

final itemRepositoryProvider = Provider<ItemRepository>(
  (ref) => FirestoreItemRepository(ref.watch(firebaseFirestoreProvider)),
);

final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => FirebaseStorageRepository(ref.watch(firebaseStorageProvider)),
);
