import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/item.dart';
import '../../../domain/entities/purchase_history_entry.dart';
import '../../providers/group_members_provider.dart';
import '../../providers/history_controller.dart';
import '../../providers/item_controller.dart';
import '../../widgets/app_feedback.dart';

/// 購入履歴タイムライン画面（`/history`、#42 Step 1）。
///
/// `itemHistory`（`type == 'purchased'`）を週ごとにグルーピングして降順表示する。
/// 生履歴は TTL（180 日）で消えるため「直近 6 ヶ月」である旨を注記する。
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  /// 月曜始まりの週の開始日（時刻 0:00）。
  static DateTime _weekStart(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  static String _shortDate(DateTime d) => '${d.month}/${d.day}';

  static String _dateTime(DateTime d) {
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.month}/${d.day} ${d.hour}:$mm';
  }

  String? _memberName(Map<String, String> names, String? uid) {
    if (uid == null) return null;
    return names[uid] ?? (uid.length <= 6 ? uid : uid.substring(0, 6));
  }

  Future<void> _reAdd(
    BuildContext context,
    WidgetRef ref,
    PurchaseHistoryEntry entry,
  ) async {
    final draft = Item(
      id: '',
      name: entry.name,
      category: '',
      note: '',
      imageUrl: '',
      status: ItemStatus.active,
      tagId: entry.tagId,
    );
    try {
      await ref.read(itemControllerProvider).addItem(draft, null);
      if (context.mounted) {
        AppFeedback.showToast(
          context,
          'app.success.add'.tr(),
          type: ToastType.success,
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppFeedback.showToast(
          context,
          'app.error.add'.tr(),
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _ = context.locale;
    final state = ref.watch(historyControllerProvider);
    final memberNames = ref.watch(
      groupMemberNamesProvider.select(
        (s) => s.value ?? const <String, String>{},
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primary,
        title: Text('history.title'.tr()),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxContentWidth,
          ),
          child: _buildBody(context, ref, state, memberNames),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    HistoryState state,
    Map<String, String> memberNames,
  ) {
    if (state.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (state.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'history.error'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    if (state.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'history.empty'.tr(),
              key: const Key('history_empty'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[_ttlNote()];
    DateTime? currentWeek;
    for (final entry in state.entries) {
      final week = _weekStart(entry.occurredAt);
      if (currentWeek != week) {
        currentWeek = week;
        children.add(_weekHeader(week));
      }
      children.add(
        _HistoryRow(
          entry: entry,
          memberName: _memberName(memberNames, entry.purchasedBy),
          dateTimeLabel: _dateTime(entry.occurredAt),
          onReAdd: () => _reAdd(context, ref, entry),
        ),
      );
    }
    if (state.loadingMore) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          ref.read(historyControllerProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView(
        key: const Key('history_list'),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: children,
      ),
    );
  }

  Widget _ttlNote() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(AppRadii.md),
    ),
    child: Text(
      'history.ttl_note'.tr(),
      style: const TextStyle(
        fontSize: AppFontSizes.xs,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _weekHeader(DateTime weekStart) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
    child: Text(
      'history.week_of'.tr(namedArgs: {'date': _shortDate(weekStart)}),
      style: const TextStyle(
        fontSize: AppFontSizes.md,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),
  );
}

/// 履歴 1 行（商品名・購入日時・購入者・再追加ボタン）。
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.memberName,
    required this.dateTimeLabel,
    required this.onReAdd,
  });

  final PurchaseHistoryEntry entry;
  final String? memberName;
  final String dateTimeLabel;
  final VoidCallback onReAdd;

  @override
  Widget build(BuildContext context) {
    final subtitle = memberName == null
        ? dateTimeLabel
        : '$dateTimeLabel · ${'history.purchased_by'.tr(namedArgs: {'name': memberName!})}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.surfaceBorder),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: AppFontSizes.lg,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: AppFontSizes.xs,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            key: Key('history_readd_${entry.id}'),
            onPressed: onReAdd,
            icon: const Icon(Icons.add, size: AppFontSizes.lg),
            label: Text(
              'history.re_add'.tr(),
              style: const TextStyle(fontSize: AppFontSizes.xs),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
