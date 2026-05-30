import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';
import '../providers/group_providers.dart';
import 'confirm_dialog.dart';

/// グループ切り替えダイアログを表示する。
Future<void> showGroupSwitcher(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _GroupSwitcherDialog(),
  );
}

class _GroupSwitcherDialog extends ConsumerStatefulWidget {
  const _GroupSwitcherDialog();

  @override
  ConsumerState<_GroupSwitcherDialog> createState() =>
      _GroupSwitcherDialogState();
}

class _GroupSwitcherDialogState extends ConsumerState<_GroupSwitcherDialog> {
  String? _actionError;

  Future<void> _leave(String groupId) async {
    setState(() => _actionError = null);
    final ok = await showConfirmDialog(
      context,
      title: 'group.settings.leave_group'.tr(),
      message: 'group.settings.leave_confirm'.tr(),
      confirmLabel: 'group.settings.leave_group'.tr(),
    );
    if (!ok) return;
    try {
      await ref.read(groupControllerProvider.notifier).leaveGroup(groupId);
    } catch (e) {
      setState(() => _actionError = e is AppError &&
              e.code == AppErrorCode.groupOwnerCannotLeave
          ? 'group.settings.error.owner_cannot_leave'.tr()
          : 'group.settings.error.leave_failed'.tr());
    }
  }

  Future<void> _disband(String groupId) async {
    setState(() => _actionError = null);
    final ok = await showConfirmDialog(
      context,
      title: 'group.settings.disband_group'.tr(),
      message: 'group.settings.disband_confirm'.tr(),
      confirmLabel: 'group.settings.disband_group'.tr(),
    );
    if (!ok) return;
    try {
      await ref.read(groupControllerProvider.notifier).disbandGroup(groupId);
    } catch (_) {
      setState(() => _actionError = 'group.settings.error.disband_failed'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupControllerProvider);
    final uid = ref.watch(currentUserProvider)?.uid;
    final activeId = state.group?.id;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'group.switcher.title'.tr(),
                style: const TextStyle(
                  fontSize: AppFontSizes.lg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Divider(),
              if (_actionError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Text(
                    _actionError!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: AppFontSizes.sm),
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final g in state.joinedGroups)
                      _row(g.id, g.name, g.ownerId == uid, g.id == activeId),
                  ],
                ),
              ),
              const Divider(),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/group/create');
                },
                child: Text('group.switcher.create_new'.tr()),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/group/join');
                },
                child: Text('group.switcher.join_with_code'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String id, String name, bool isOwner, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              child: Text(
                'group.switcher.active_badge'.tr(),
                style: const TextStyle(
                    color: AppColors.white, fontSize: AppFontSizes.xs),
              ),
            )
          else ...[
            OutlinedButton(
              onPressed: () {
                ref.read(groupControllerProvider.notifier).switchGroup(id);
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact),
              child: Text('group.switcher.switch_button'.tr()),
            ),
            const SizedBox(width: AppSpacing.xs),
            OutlinedButton(
              onPressed: () => isOwner ? _disband(id) : _leave(id),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(isOwner
                  ? 'group.switcher.disband'.tr()
                  : 'group.switcher.leave'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}
