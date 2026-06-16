import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/suggestion.dart';
import 'group_providers.dart';
import 'repository_providers.dart';

/// SharedPreferences のキー（最後に既読した weekId を端末ローカルに保存）。
const _kLastReadWeekId = 'suggestion_last_read_week_id';

/// アクティブグループの最新提案をリアルタイム購読する。
///
/// グループ未所属時は null を返す。
final latestSuggestionProvider = StreamProvider<Suggestion?>((ref) {
  final gid = ref.watch(activeGroupIdProvider);
  if (gid == null) return Stream.value(null);
  final repo = ref.watch(suggestionRepositoryProvider);
  return repo.watchLatestSuggestion(gid);
});

/// 未読バッジを出すべきかの純粋判定（テスト容易性のため provider から分離）。
///
/// 最新提案が ready かつ、その weekId が最後に既読した weekId と異なる場合に true。
bool isSuggestionUnread(Suggestion? latest, String? lastReadWeekId) {
  if (latest == null || latest.status != SuggestionStatus.ready) return false;
  return latest.id != lastReadWeekId;
}

/// 未読提案があるかどうか（端末ローカル判定）。
///
/// latestSuggestionProvider の現在値を読む。ロード中は null（=未読なし）だが、
/// ストリームが emit すると本 provider は再評価され、最新値で判定し直される。
final hasUnreadSuggestionProvider = FutureProvider<bool>((ref) async {
  final suggestion = ref.watch(latestSuggestionProvider).value;
  final prefs = await SharedPreferences.getInstance();
  return isSuggestionUnread(suggestion, prefs.getString(_kLastReadWeekId));
});

/// 最新提案を既読としてマークする（端末ローカルに weekId を保存）。
///
/// 提案画面を開いたタイミングで呼ぶ。保存後に [hasUnreadSuggestionProvider] を
/// invalidate して、ダッシュボードの未読バッジを即座に消す。
///
/// 保存中に画面が破棄され `ref` が無効化されているケース（await 後に pop された等）
/// では invalidate が例外を投げうるが、その場合バッジ provider は次回読み取り時に
/// 新しい既読 weekId で再評価されるため握りつぶして問題ない。
Future<void> markSuggestionAsRead(WidgetRef ref, String weekId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kLastReadWeekId, weekId);
  try {
    ref.invalidate(hasUnreadSuggestionProvider);
  } catch (_) {
    // ref がすでに破棄済み: 次回読み取りで再評価されるため無視。
  }
}
