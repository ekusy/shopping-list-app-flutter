import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../providers/group_providers.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/splash_screen.dart';

// 遅延ロード: 初期表示に不要な画面を deferred import してバンドル分割する。
// Flutter web ではビルド時に個別の .part.js として出力され、
// 初回アクセス時にのみダウンロードされる。
// Android/iOS では loadLibrary() が即時完了するため動作に影響しない。
import '../screens/auth/signup_screen.dart' deferred as signup;
import '../screens/group/group_create_screen.dart' deferred as group_create;
import '../screens/group/group_join_screen.dart' deferred as group_join;
import '../screens/group/group_settings_screen.dart' deferred as group_settings;
import '../screens/profile/profile_screen.dart' deferred as profile;

/// 認証・グループ状態の変化を go_router に伝えるためのリスナー兼リダイレクト判定。
///
/// 元の `AppGuard`（`app/_layout.tsx`）のルーティング判定を移植したもの。
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _ref.listen(groupControllerProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  /// 認証・グループ状態に基づくリダイレクト先を返す（null は遷移なし）。
  String? redirect(BuildContext context, GoRouterState state) {
    final authLoading = _ref.read(authLoadingProvider);
    final user = _ref.read(currentUserProvider);
    final loc = state.matchedLocation;

    final inAuthRoute = loc == '/login' || loc == '/signup';
    final inGroupCreate = loc == '/group/create';
    final inGroupJoin = loc.startsWith('/group/join');
    final inProfile = loc == '/profile';
    final inSplash = loc == '/splash';

    // 1. 認証ロード中 → スプラッシュ
    if (authLoading) return inSplash ? null : '/splash';

    // 2. 未認証: 招待リンク(/group/join)と認証画面以外は /login へ
    if (user == null) {
      if (inAuthRoute || inGroupJoin) return null;
      return '/login';
    }

    // 3. 認証済み・グループロード中 → スプラッシュ
    final groupLoading = _ref.read(groupLoadingProvider);
    if (groupLoading) return inSplash ? null : '/splash';

    // 4. グループ未所属: グループ作成/参加/プロフィール以外は /group/create へ
    final group = _ref.read(activeGroupProvider);
    if (group == null) {
      if (inGroupCreate || inGroupJoin || inProfile) return null;
      return '/group/create';
    }

    // 5. グループ所属済み: 認証画面・スプラッシュにいる場合はホームへ
    if (inAuthRoute || inSplash) return '/';
    return null;
  }
}

/// deferred library のロード中に表示するプレースホルダー。
class _DeferredLoadingPlaceholder extends StatelessWidget {
  const _DeferredLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// アプリのルーター。認証・グループ状態に応じてリダイレクトする。
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (_, _) => FutureBuilder(
          future: signup.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return signup.SignupScreen();
            }
            return const _DeferredLoadingPlaceholder();
          },
        ),
      ),
      GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
      GoRoute(
        path: '/profile',
        builder: (_, _) => FutureBuilder(
          future: profile.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return profile.ProfileScreen();
            }
            return const _DeferredLoadingPlaceholder();
          },
        ),
      ),
      GoRoute(
        path: '/group/create',
        builder: (_, _) => FutureBuilder(
          future: group_create.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return group_create.GroupCreateScreen();
            }
            return const _DeferredLoadingPlaceholder();
          },
        ),
      ),
      GoRoute(
        path: '/group/join',
        builder: (_, state) => FutureBuilder(
          future: group_join.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return group_join.GroupJoinScreen(
                initialCode: state.uri.queryParameters['code'],
              );
            }
            return const _DeferredLoadingPlaceholder();
          },
        ),
      ),
      GoRoute(
        path: '/group/settings',
        builder: (_, _) => FutureBuilder(
          future: group_settings.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return group_settings.GroupSettingsScreen();
            }
            return const _DeferredLoadingPlaceholder();
          },
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
