import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../domain/entities/auth_user.dart';
import 'repository_providers.dart';

/// 認証状態のストリーム（ログイン/ログアウト/初期化完了を通知）。
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// 現在の認証ユーザー（未ログイン・初期化中は null）。
final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authStateProvider).value;
});

/// 認証状態の初期化が完了していないか（初回の状態確定まで true）。
final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isLoading;
});

/// 認証操作のオーケストレーションを担うコントローラ。
///
/// Firebase Auth / ユーザードキュメント / Storage / グループの各リポジトリを
/// 協調させ、UI から呼び出される認証アクションを提供する。
class AuthController {
  AuthController(this._ref);

  final Ref _ref;

  /// 新規ユーザー登録。成功時はユーザードキュメントも作成し、表示名があれば設定する。
  ///
  /// @param displayName 表示名（空の場合は設定しない）
  Future<void> signup(
    String email,
    String password, {
    String? displayName,
  }) async {
    final auth = _ref.read(authRepositoryProvider);
    final users = _ref.read(userRepositoryProvider);
    final user = await auth.signUp(email, password);
    await users.createUserDocument(user.uid);
    final trimmed = displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      await users.updateUserProfile(user.uid, displayName: trimmed);
    }
  }

  /// メール + パスワードでログイン。
  Future<void> login(String email, String password) async {
    await _ref.read(authRepositoryProvider).signIn(email, password);
  }

  /// ログアウト。
  Future<void> logout() async {
    await _ref.read(authRepositoryProvider).signOut();
  }

  /// プロフィール（表示名 + アバター画像）を更新する。
  ///
  /// @param imageBytes アップロードする画像バイト列（null の場合は画像を変更しない）
  /// @returns 更新後の avatarUrl（画像なしの場合は null）
  Future<String?> updateProfile(
    String displayName, {
    Uint8List? imageBytes,
  }) async {
    final uid = _ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      throw const AppError(AppErrorCode.authUnknown, 'Not authenticated');
    }
    String? avatarUrl;
    if (imageBytes != null) {
      avatarUrl = await _ref.read(storageRepositoryProvider).uploadAvatar(uid, imageBytes);
    }
    await _ref.read(userRepositoryProvider).updateUserProfile(
          uid,
          displayName: displayName,
          avatarUrl: avatarUrl,
        );
    return avatarUrl;
  }

  /// アカウントを退会する。
  ///
  /// グループオーナーのまま退会しようとすると [AppErrorCode.authCannotDeleteOwner] を throw する。
  Future<void> deleteAccount() async {
    final auth = _ref.read(authRepositoryProvider);
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      throw const AppError(AppErrorCode.authUnknown, 'Not authenticated');
    }
    final ownsGroup = await _ref.read(groupRepositoryProvider).isGroupOwner(uid);
    if (ownsGroup) {
      throw const AppError(
        AppErrorCode.authCannotDeleteOwner,
        'Cannot delete account while owning a group',
      );
    }
    await _ref.read(userRepositoryProvider).deleteUserDocument(uid);
    await auth.deleteCurrentUser();
  }
}

/// [AuthController] の DI プロバイダ。
final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref),
);
