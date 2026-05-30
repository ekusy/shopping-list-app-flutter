import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/image_policy.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';
import '../../providers/repository_providers.dart';
import '../../utils/image_helper.dart';

/// プロフィール編集画面（表示名・アバター・退会）。
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _displayName = TextEditingController();
  String _avatarUrl = '';
  Uint8List? _selectedBytes;
  bool _loading = true;
  bool _saving = false;
  String? _saveError;
  String? _deleteError;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final profile = await ref.read(userRepositoryProvider).getUserProfile(uid);
      if (profile != null) {
        _displayName.text = profile.displayName;
        _avatarUrl = profile.avatarUrl;
      }
    } catch (_) {
      // ロード失敗でもスピナーは止める。
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final helper = ImageHelper(ImagePicker());
    final bytes = await helper.pickResized(ImageTier.avatar);
    if (bytes != null) setState(() => _selectedBytes = bytes);
  }

  Future<void> _save() async {
    setState(() {
      _saveError = null;
      _success = null;
      _saving = true;
    });
    try {
      final newUrl = await ref.read(authControllerProvider).updateProfile(
            _displayName.text,
            imageBytes: _selectedBytes,
          );
      if (newUrl != null) _avatarUrl = newUrl;
      _selectedBytes = null;
      setState(() => _success = 'profile.success'.tr());
    } catch (_) {
      setState(() => _saveError = 'profile.error.update_failed'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => _deleteError = null);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile.delete_account'.tr()),
        content: Text('profile.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('profile.delete_account'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authControllerProvider).deleteAccount();
      // ログアウト状態になりルーターが /login へ遷移する。
    } catch (e) {
      setState(() => _deleteError = e is AppError &&
              e.code == AppErrorCode.authCannotDeleteOwner
          ? 'profile.error.cannot_delete_owner'.tr()
          : 'profile.error.delete_failed'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final ImageProvider? preview = _selectedBytes != null
        ? MemoryImage(_selectedBytes!)
        : imageProviderFromUrl(_avatarUrl);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: BackButton(onPressed: () => _back(context)),
        title: Text('profile.title'.tr()),
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
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primary,
                            backgroundImage: preview,
                            child: preview == null
                                ? Text(
                                    _displayName.text.isNotEmpty
                                        ? _displayName.text
                                            .characters.first
                                            .toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: AppFontSizes.xxl,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton(
                            onPressed: _pickImage,
                            child: Text('profile.change_avatar'.tr()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'profile.display_name'.tr(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppFontSizes.sm,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: _displayName,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_success != null)
                      _MessageBox(_success!, success: true),
                    if (_saveError != null) _MessageBox(_saveError!),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : Text('profile.save'.tr()),
                    ),
                    const Divider(height: AppSpacing.xl * 2),
                    if (_deleteError != null) _MessageBox(_deleteError!),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      onPressed: _deleteAccount,
                      child: Text('profile.delete_account'.tr()),
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

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

/// 成功 / エラーメッセージボックス。
class _MessageBox extends StatelessWidget {
  const _MessageBox(this.message, {this.success = false});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFE8F5E9) : AppColors.errorBg,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: success ? const Color(0xFFC8E6C9) : AppColors.errorBorder,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: success ? AppColors.success : AppColors.error,
          fontSize: AppFontSizes.sm,
        ),
      ),
    );
  }
}
