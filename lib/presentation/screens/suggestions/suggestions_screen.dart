import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/item.dart';
import '../../../domain/entities/suggestion.dart';
import '../../providers/auth_providers.dart';
import '../../providers/group_providers.dart';
import '../../providers/item_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/suggestion_providers.dart';
import '../../widgets/app_feedback.dart';

/// AI 提案画面（/suggestions）。
///
/// deferred import 前提のため const コンストラクタを持つ StatelessWidget を起点とし、
/// 実処理は [ConsumerStatefulWidget] に委ねる。
class SuggestionsScreen extends StatelessWidget {
  const SuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SuggestionsScreenBody();
  }
}

class _SuggestionsScreenBody extends ConsumerStatefulWidget {
  const _SuggestionsScreenBody();

  @override
  ConsumerState<_SuggestionsScreenBody> createState() =>
      _SuggestionsScreenBodyState();
}

class _SuggestionsScreenBodyState
    extends ConsumerState<_SuggestionsScreenBody> {
  String? get _groupId => ref.read(activeGroupProvider)?.id;
  String? get _uid => ref.read(currentUserProvider)?.uid;

  int _nextOrder() {
    final items = ref.read(itemsProvider).value ?? const [];
    return items.fold<int>(
          0,
          (max, i) => (i.order ?? 0) > max ? i.order! : max,
        ) +
        1;
  }

  Future<void> _addItemFromSuggestion(String name) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final draft = Item(
      id: '',
      name: name,
      category: '',
      note: '',
      imageUrl: '',
      status: ItemStatus.active,
      addedBy: _uid,
    );
    AppFeedback.showLoading(context, 'status.adding'.tr());
    try {
      await ref
          .read(itemRepositoryProvider)
          .addItem(groupId, draft, _nextOrder());
      if (mounted) {
        AppFeedback.hide(context);
        AppFeedback.showToast(
          context,
          'app.success.add'.tr(),
          type: ToastType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.hide(context);
        AppFeedback.showToast(
          context,
          'app.error.add'.tr(),
          type: ToastType.error,
        );
      }
    }
  }

  /// 既読化を一度だけ実行するためのガード。
  bool _markedAsRead = false;

  /// 最新提案が読み込めたら一度だけ既読化する。
  ///
  /// 初回フレーム時点ではストリーム未解決（null）のことがあるため、
  /// [build] から `ref.listen` 経由で「最初の非 null 値」を待って実行する。
  void _markReadOnce(Suggestion? suggestion) {
    if (_markedAsRead || suggestion == null) return;
    _markedAsRead = true;
    markSuggestionAsRead(ref, suggestion.id);
  }

  @override
  Widget build(BuildContext context) {
    // easy_localization の .tr() は static インスタンスを使うため context 依存が自動で
    // 作られない。context.locale を読むことで InheritedWidget 依存を明示し、
    // ロケール変更を確実に反映させる。
    context.locale;

    // ストリームが値を出した時点で既読化する（postFrameCallback では初回 null を
    // 取りこぼすため、reactive な listen に統一）。
    ref.listen(latestSuggestionProvider, (_, next) {
      _markReadOnce(next.value);
    });
    // 画面マウント時点で既に解決済みのケースも拾う。
    _markReadOnce(ref.read(latestSuggestionProvider).value);

    final suggestionAsync = ref.watch(latestSuggestionProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Text(
          'suggestions.title'.tr(),
          style: const TextStyle(
            fontSize: AppFontSizes.xl,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.primary),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: AppColors.background,
      body: suggestionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _ErrorState(),
        data: (suggestion) {
          if (suggestion == null) {
            return _EmptyState(reason: _EmptyReason.noDocument);
          }
          if (suggestion.status == SuggestionStatus.empty) {
            return _EmptyState(reason: _EmptyReason.statusEmpty);
          }
          if (suggestion.forgottenItems.isEmpty &&
              suggestion.recommendedItems.isEmpty) {
            return _EmptyState(reason: _EmptyReason.noItems);
          }
          return _SuggestionContent(
            suggestion: suggestion,
            onAddItem: _addItemFromSuggestion,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / Error states
// ---------------------------------------------------------------------------

enum _EmptyReason { noDocument, statusEmpty, noItems }

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.reason});

  final _EmptyReason reason;

  @override
  Widget build(BuildContext context) {
    final message = switch (reason) {
      _EmptyReason.noDocument => 'suggestions.empty.no_history'.tr(),
      _EmptyReason.statusEmpty => 'suggestions.empty.status_empty'.tr(),
      _EmptyReason.noItems => 'suggestions.empty.no_items'.tr(),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 48, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppFontSizes.lg,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'app.error.fetch'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppFontSizes.lg,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main content
// ---------------------------------------------------------------------------

class _SuggestionContent extends StatelessWidget {
  const _SuggestionContent({required this.suggestion, required this.onAddItem});

  final Suggestion suggestion;
  final Future<void> Function(String name) onAddItem;

  /// 生成日時を "YYYY/M/D HH:mm" 形式にフォーマットする。
  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year;
    final mo = local.month;
    final d = local.day;
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$y/$mo/$d $h:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(suggestion.generatedAt);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // --- 購入忘れかも ---
        if (suggestion.forgottenItems.isNotEmpty) ...[
          _SectionHeader(title: 'suggestions.section.forgotten'.tr()),
          ...suggestion.forgottenItems.map(
            (item) => _SuggestionCard(
              name: item.name,
              reason: item.reason,
              badge: _confidenceBadge(item.confidence),
              onAddItem: onAddItem,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // --- 次の買い物におすすめ ---
        if (suggestion.recommendedItems.isNotEmpty) ...[
          _SectionHeader(title: 'suggestions.section.recommended'.tr()),
          ...suggestion.recommendedItems.map(
            (item) => _SuggestionCard(
              name: item.name,
              reason: item.reason,
              onAddItem: onAddItem,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // --- フッター ---
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'suggestions.footer.generated_at'.tr(namedArgs: {'date': dateLabel}),
          style: const TextStyle(
            fontSize: AppFontSizes.xs,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'suggestions.footer.ai_note'.tr(),
          style: const TextStyle(
            fontSize: AppFontSizes.xs,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  String? _confidenceBadge(SuggestionConfidence confidence) {
    return switch (confidence) {
      SuggestionConfidence.high => null, // high は無印（自明）
      SuggestionConfidence.medium => '?',
      SuggestionConfidence.low => '??',
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.xs),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: AppFontSizes.lg,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.name,
    required this.reason,
    this.badge,
    required this.onAddItem,
  });

  final String name;
  final String reason;

  /// high: null, medium: '?', low: '??'
  final String? badge;
  final Future<void> Function(String name) onAddItem;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: const BorderSide(color: AppColors.surfaceBorder),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: AppFontSizes.lg,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          badge!,
                          style: const TextStyle(
                            fontSize: AppFontSizes.sm,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      reason,
                      style: const TextStyle(
                        fontSize: AppFontSizes.sm,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => onAddItem(name),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: AppColors.primaryLight,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: Text(
                'suggestions.add_to_list'.tr(),
                style: const TextStyle(
                  fontSize: AppFontSizes.sm,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
