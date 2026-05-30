import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'repository_providers.dart';

/// 通知設定フラグを管理するコントローラ（旧 `useNotifications`）。
///
/// マウント時に Firestore からフラグを読み込み、[toggle] で永続化と楽観的更新を行う。
/// Sprint 3 スコープ: Firestore フラグ保存のみ（FCM 連携は将来実装）。
class NotificationsController extends Notifier<bool> {
  @override
  bool build() {
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      _load(user.uid);
    }
    return false;
  }

  Future<void> _load(String uid) async {
    final profile = await ref.read(userRepositoryProvider).getUserProfile(uid);
    state = profile?.notificationsEnabled ?? false;
  }

  /// 通知設定を切り替える。Firestore 書き込みと同時にローカル状態を楽観的更新する。
  Future<void> toggle(bool enabled) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    state = enabled;
    await ref.read(userRepositoryProvider).updateNotificationEnabled(uid, enabled);
  }
}

/// 通知設定コントローラのプロバイダ。
final notificationsControllerProvider =
    NotifierProvider<NotificationsController, bool>(NotificationsController.new);
