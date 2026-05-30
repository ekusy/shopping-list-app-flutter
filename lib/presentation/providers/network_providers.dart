import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [Connectivity] の DI プロバイダ（テストで override 可能）。
final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// ネットワーク接続状態（オンラインなら true）をリアルタイム購読する（旧 `useNetworkStatus`）。
///
/// 注意: 厳密なインターネット到達性は保証せず、オフラインインジケーターの目安として利用する。
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = ref.watch(connectivityProvider);
  try {
    yield _isOnline(await connectivity.checkConnectivity());
  } catch (_) {
    yield true; // 取得失敗時は安全側（オンライン）に倒す。
  }
  yield* connectivity.onConnectivityChanged.map(_isOnline);
});
