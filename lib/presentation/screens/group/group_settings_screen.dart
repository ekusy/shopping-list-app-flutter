import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/invite_url.dart';
import '../../../domain/entities/group.dart';
import '../../providers/auth_providers.dart';
import '../../providers/group_members_provider.dart';
import '../../providers/group_providers.dart';
import '../../providers/notification_providers.dart';
import '../../utils/share_helper.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/message_box.dart';

/// グループ設定画面（名前変更・招待コード共有・メンバー管理・通知・脱退/解散）。
class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key});

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  final _groupName = TextEditingController();
  bool _nameInitialized = false;
  bool _saving = false;
  String? _saveError;
  String? _saveSuccess;
  String? _actionError;

  @override
  void dispose() {
    _groupName.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() {
      _saveError = null;
      _saveSuccess = null;
    });
    if (_groupName.text.trim().isEmpty) {
      setState(() => _saveError = 'group.settings.error.empty_name'.tr());
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(groupControllerProvider.notifier)
          .renameGroup(_groupName.text.trim());
      setState(() => _saveSuccess = 'group.settings.name_success'.tr());
    } catch (_) {
      setState(() => _saveError = 'group.settings.error.save_failed'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    setState(() => _actionError = null);
    final confirmed = await showConfirmDialog(
      context,
      title: 'group.settings.leave_group'.tr(),
      message: 'group.settings.leave_confirm'.tr(),
      confirmLabel: 'group.settings.leave_group'.tr(),
    );
    if (!confirmed) return;
    try {
      await ref.read(groupControllerProvider.notifier).leaveGroup();
    } catch (e) {
      setState(() => _actionError = e is AppError &&
              e.code == AppErrorCode.groupOwnerCannotLeave
          ? 'group.settings.error.owner_cannot_leave'.tr()
          : 'group.settings.error.leave_failed'.tr());
    }
  }

  Future<void> _disband() async {
    setState(() => _actionError = null);
    final confirmed = await showConfirmDialog(
      context,
      title: 'group.settings.disband_group'.tr(),
      message: 'group.settings.disband_confirm'.tr(),
      confirmLabel: 'group.settings.disband_group'.tr(),
    );
    if (!confirmed) return;
    try {
      await ref.read(groupControllerProvider.notifier).disbandGroup();
    } catch (_) {
      setState(() => _actionError = 'group.settings.error.disband_failed'.tr());
    }
  }

  Future<void> _removeMember(String uid, String name) async {
    setState(() => _actionError = null);
    final confirmed = await showConfirmDialog(
      context,
      title: 'group.settings.remove_member'.tr(),
      message: 'group.settings.remove_member_confirm'.tr(namedArgs: {'name': name}),
      confirmLabel: 'group.settings.remove_member'.tr(),
    );
    if (!confirmed) return;
    try {
      await ref.read(groupControllerProvider.notifier).removeMember(uid);
    } catch (e) {
      setState(() => _actionError = e is AppError &&
              e.code == AppErrorCode.groupCannotRemoveOwner
          ? 'group.settings.error.cannot_remove_owner'.tr()
          : 'group.settings.error.remove_member_failed'.tr());
    }
  }

  Future<void> _copy(String text, String toast) async {
    await ShareHelper.copyToClipboard(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(toast), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(activeGroupProvider);
    if (group == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (!_nameInitialized) {
      _groupName.text = group.name;
      _nameInitialized = true;
    }

    final uid = ref.watch(currentUserProvider)?.uid;
    final isOwner = group.ownerId == uid;
    final memberNames = ref.watch(groupMemberNamesProvider).value ?? const {};
    final notificationsEnabled = ref.watch(notificationsControllerProvider);
    final inviteUrl = buildInviteUrl(group.inviteCode);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text('group.settings.title'.tr()),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('group.settings.name_label'.tr()),
                    TextField(
                      controller: _groupName,
                      maxLength: 50,
                      onChanged: (_) => setState(() {
                        _saveError = null;
                        _saveSuccess = null;
                      }),
                    ),
                    if (_saveSuccess != null)
                      MessageBox(_saveSuccess!, success: true),
                    if (_saveError != null) MessageBox(_saveError!),
                    FilledButton(
                      onPressed: _saving ? null : _saveName,
                      child: Text(_saving
                          ? 'group.settings.saving'.tr()
                          : 'group.settings.save'.tr()),
                    ),
                    const Divider(height: AppSpacing.xl * 2),
                    _inviteSection(group, inviteUrl),
                    const Divider(height: AppSpacing.xl * 2),
                    _membersSection(group, uid, isOwner, memberNames),
                    const Divider(height: AppSpacing.xl * 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('group.settings.notifications_label'.tr()),
                        Switch(
                          value: notificationsEnabled,
                          onChanged: (v) => ref
                              .read(notificationsControllerProvider.notifier)
                              .toggle(v),
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.xl * 2),
                    if (_actionError != null) MessageBox(_actionError!),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      onPressed: isOwner ? _disband : _leave,
                      child: Text(isOwner
                          ? 'group.settings.disband_group'.tr()
                          : 'group.settings.leave_group'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppFontSizes.sm,
          ),
        ),
      );

  Widget _inviteSection(Group group, String inviteUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('group.invite.code_label'.tr()),
        SelectableText(
          group.inviteCode,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppFontSizes.xl,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: () =>
              _copy(group.inviteCode, 'group.invite.copied_toast'.tr()),
          child: Text('group.invite.copy_button'.tr()),
        ),
        const SizedBox(height: AppSpacing.md),
        _label('group.invite.url_label'.tr()),
        SelectableText(inviteUrl),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    _copy(inviteUrl, 'group.invite.copied_url_toast'.tr()),
                child: Text('group.invite.copy_url_button'.tr()),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: () => ShareHelper.shareText(
                  '${'group.invite.share_message'.tr()}\n$inviteUrl',
                  subject: 'group.invite.share_title'.tr(),
                ),
                child: Text('group.invite.share_button'.tr()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _membersSection(
    Group group,
    String? uid,
    bool isOwner,
    Map<String, String> memberNames,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('group.settings.members_label'.tr()),
        for (final memberId in group.memberIds)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    memberNames[memberId] ??
                        (memberId.length <= 8
                            ? memberId
                            : memberId.substring(0, 8)),
                  ),
                ),
                if (memberId == group.ownerId)
                  _badge('group.settings.owner_badge'.tr(), AppColors.primary),
                if (memberId == uid)
                  _badge('group.settings.you_badge'.tr(), AppColors.success),
                if (isOwner && memberId != group.ownerId && memberId != uid)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: () => _removeMember(
                        memberId,
                        memberNames[memberId] ?? memberId,
                      ),
                      child: Text(
                        'group.settings.remove_member'.tr(),
                        style: const TextStyle(fontSize: AppFontSizes.xs),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _badge(String text, Color color) => Container(
        margin: const EdgeInsets.only(left: AppSpacing.xs),
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: AppFontSizes.xs,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
