import '../entities/suggestion.dart';

/// AI 提案（`groups/{groupId}/suggestions`）の永続化抽象。
abstract class SuggestionRepository {
  /// 指定グループの最新提案を `generatedAt` 降順でリアルタイム購読する。
  ///
  /// 提案が存在しない場合は null を返す。
  Stream<Suggestion?> watchLatestSuggestion(String groupId);
}
