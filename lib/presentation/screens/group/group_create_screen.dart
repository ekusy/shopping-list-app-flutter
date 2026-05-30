import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/invite_url.dart';
import '../../providers/auth_providers.dart';
import '../../providers/group_providers.dart';
import '../../utils/share_helper.dart';
import '../../widgets/error_banner.dart';

/// グループ作成画面。グループ名を入力して作成し、招待コード / リンクを表示する。
class GroupCreateScreen extends ConsumerStatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  ConsumerState<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends ConsumerState<GroupCreateScreen> {
  final _groupName = TextEditingController();
  bool _creating = false;
  String? _inviteCode;
  String? _error;

  @override
  void dispose() {
    _groupName.dispose();
    super.dispose();
  }

  String get _inviteUrl =>
      _inviteCode == null ? '' : buildInviteUrl(_inviteCode!);

  Future<void> _create() async {
    if (_groupName.text.trim().isEmpty) {
      setState(() => _error = 'group.create.error.empty_name'.tr());
      return;
    }
    setState(() {
      _error = null;
      _creating = true;
    });
    try {
      final code = await ref
          .read(groupControllerProvider.notifier)
          .createGroup(_groupName.text.trim());
      setState(() => _inviteCode = code);
    } catch (e) {
      setState(() => _error = e is AppError
          ? 'group.create.error.create_failed'.tr()
          : 'group.create.error.create_failed'.tr());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final joinedGroups = ref.watch(groupControllerProvider).joinedGroups;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'group.create.title'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: AppFontSizes.xxl,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_inviteCode == null)
                      ..._buildForm(joinedGroups)
                    else
                      ..._buildInviteView(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildForm(List<dynamic> joinedGroups) {
    return [
      TextField(
        controller: _groupName,
        enabled: !_creating,
        decoration:
            InputDecoration(hintText: 'group.create.name_placeholder'.tr()),
        onSubmitted: (_) => _creating ? null : _create(),
      ),
      const SizedBox(height: AppSpacing.md),
      if (_error != null) ErrorBanner(_error!),
      FilledButton(
        onPressed: _creating ? null : _create,
        child: Text(_creating
            ? 'group.create.creating'.tr()
            : 'group.create.button'.tr()),
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'group.create.join_instead'.tr(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.sm,
            ),
          ),
          TextButton(
            onPressed:
                _creating ? null : () => context.push('/group/join'),
            child: Text('group.create.join_instead_link'.tr()),
          ),
        ],
      ),
      if (joinedGroups.length > 1) ...[
        const Divider(height: AppSpacing.lg),
        Text(
          'group.create.existing_groups'.tr(),
          style: const TextStyle(
            fontSize: AppFontSizes.sm,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final g in joinedGroups)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(g.name as String, overflow: TextOverflow.ellipsis),
                ),
                OutlinedButton(
                  onPressed: () {
                    ref
                        .read(groupControllerProvider.notifier)
                        .switchGroup(g.id as String);
                    context.go('/');
                  },
                  child: Text('group.switcher.switch_button'.tr()),
                ),
              ],
            ),
          ),
      ],
      const SizedBox(height: AppSpacing.xs),
      TextButton(
        onPressed: _creating
            ? null
            : () => ref.read(authControllerProvider).logout(),
        child: Text('auth.logout'.tr()),
      ),
    ];
  }

  List<Widget> _buildInviteView() {
    return [
      Text(
        'group.create.invite_code_label'.tr(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: AppFontSizes.sm,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      SelectableText(
        _inviteCode!,
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
        onPressed: () => _copy(_inviteCode!, 'group.create.copied_toast'.tr()),
        child: Text('group.create.copy_button'.tr()),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        'group.create.invite_url_label'.tr(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: AppFontSizes.sm,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      SelectableText(_inviteUrl, textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.xs),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () =>
                  _copy(_inviteUrl, 'group.create.copied_url_toast'.tr()),
              child: Text('group.create.copy_url_button'.tr()),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FilledButton(
              onPressed: () => ShareHelper.shareText(
                '${'group.invite.share_message'.tr()}\n$_inviteUrl',
                subject: 'group.invite.share_title'.tr(),
              ),
              child: Text('group.create.share_button'.tr()),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      FilledButton(
        onPressed: () => context.go('/'),
        child: Text('group.create.proceed_button'.tr()),
      ),
    ];
  }

  Future<void> _copy(String text, String toast) async {
    await ShareHelper.copyToClipboard(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(toast),
        duration: const Duration(seconds: 2),
      ));
  }
}
