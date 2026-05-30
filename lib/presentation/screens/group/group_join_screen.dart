import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';
import '../../providers/group_providers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_banner.dart';

/// グループ参加画面。招待コードを入力してグループに参加する。
/// ディープリンク（`?code=XXX`）から到達した場合は自動でフォームに挿入する。
class GroupJoinScreen extends ConsumerStatefulWidget {
  const GroupJoinScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<GroupJoinScreen> createState() => _GroupJoinScreenState();
}

class _GroupJoinScreenState extends ConsumerState<GroupJoinScreen> {
  late final TextEditingController _code;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final trimmed = _code.text.trim().toUpperCase();
    if (trimmed.isEmpty) {
      setState(() => _error = 'group.join.error.empty_code'.tr());
      return;
    }
    setState(() => _error = null);

    final controller = ref.read(groupControllerProvider.notifier);

    // 参加前にグループ名を表示するため先に検索する。
    String groupName;
    try {
      final found = await controller.findGroupByInviteCode(trimmed);
      if (found == null) {
        setState(() => _error = 'group.join.error.invalid_code'.tr());
        return;
      }
      groupName = found.name;
    } catch (_) {
      setState(() => _error = 'group.join.error.join_failed'.tr());
      return;
    }

    if (!mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'group.join.confirm_title'.tr(),
      message: 'group.join.confirm_message'.tr(namedArgs: {'groupName': groupName}),
      confirmLabel: 'group.join.confirm_button'.tr(),
    );
    if (!confirmed) return;

    setState(() => _joining = true);
    try {
      await controller.joinGroupByCode(trimmed);
      // 参加成功でグループ状態が変わり、ルーターがホームへ遷移する。
    } catch (e) {
      setState(() => _error = _joinError(e));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  String _joinError(Object e) {
    if (e is AppError) {
      switch (e.code) {
        case AppErrorCode.groupInvalidInviteCode:
          return 'group.join.error.invalid_code'.tr();
        case AppErrorCode.groupAlreadyMember:
          return 'group.join.error.already_member'.tr();
        default:
          return 'group.join.error.join_failed'.tr();
      }
    }
    return 'group.join.error.join_failed'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(currentUserProvider) != null;

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
                      'group.join.title'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: AppFontSizes.xxl,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (!loggedIn) ...[
                      // 未ログインで到達した場合はログインへ誘導する。
                      Text('group.join.code_label'.tr()),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: () => context.go('/login'),
                        child: Text('auth.login'.tr()),
                      ),
                    ] else ...[
                      Text('group.join.code_label'.tr()),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: _code,
                        enabled: !_joining,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: AppFontSizes.xl,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: AppColors.primary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'group.join.code_placeholder'.tr(),
                        ),
                        onChanged: (_) => setState(() => _error = null),
                        onSubmitted: (_) => _joining ? null : _join(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_error != null) ErrorBanner(_error!),
                      FilledButton(
                        onPressed: _joining ? null : _join,
                        child: Text(_joining
                            ? 'group.join.joining'.tr()
                            : 'group.join.button'.tr()),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton(
                        onPressed: () =>
                            context.canPop() ? context.pop() : context.go('/'),
                        child: Text('← ${'profile.back'.tr()}'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
