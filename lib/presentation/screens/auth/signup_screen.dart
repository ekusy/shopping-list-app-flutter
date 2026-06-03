import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';
import '../../utils/error_messages.dart';
import '../../widgets/error_banner.dart';

/// サインアップ（ユーザー登録）画面。メール + パスワードで新規アカウントを作成する。
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _email = TextEditingController();
  final _displayName = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _showPassword = false;
  bool _showPasswordConfirm = false;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _displayName.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'auth.error.empty_password'.tr());
      return;
    }
    if (_password.text != _passwordConfirm.text) {
      setState(() => _error = 'auth.error.passwords_do_not_match'.tr());
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref
          .read(authControllerProvider)
          .signup(
            _email.text,
            _password.text,
            displayName: _displayName.text.isEmpty ? null : _displayName.text,
          );
    } catch (e) {
      setState(() => _error = signupErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: TextButton(
          onPressed: onToggle,
          child: Text(
            visible ? 'auth.hide_password'.tr() : 'auth.show_password'.tr(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'auth.signup'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: AppFontSizes.xxl,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_error != null) ErrorBanner(_error!),
                    TextField(
                      controller: _displayName,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'auth.display_name'.tr(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(labelText: 'auth.email'.tr()),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _passwordField(
                      controller: _password,
                      label: 'auth.password'.tr(),
                      visible: _showPassword,
                      onToggle: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _passwordField(
                      controller: _passwordConfirm,
                      label: 'auth.password_confirm'.tr(),
                      visible: _showPasswordConfirm,
                      onToggle: () => setState(
                        () => _showPasswordConfirm = !_showPasswordConfirm,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text('auth.signup'.tr()),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'auth.has_account'.tr(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppFontSizes.sm,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text('auth.login'.tr()),
                        ),
                      ],
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
}
