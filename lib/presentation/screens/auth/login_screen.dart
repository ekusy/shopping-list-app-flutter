import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';
import '../../utils/error_messages.dart';
import '../../widgets/error_banner.dart';

/// ログイン画面。既存アカウントのメール + パスワードでログインする。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref.read(authControllerProvider).login(_email.text, _password.text);
      // 認証状態の変化に応じてルーターが自動的に遷移する。
    } catch (e) {
      setState(() => _error = loginErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                      'auth.login'.tr(),
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
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(labelText: 'auth.email'.tr()),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'auth.password'.tr(),
                        suffixIcon: TextButton(
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          child: Text(
                            _showPassword
                                ? 'auth.hide_password'.tr()
                                : 'auth.show_password'.tr(),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _loading ? null : _submit(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text('auth.login'.tr()),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'auth.need_account'.tr(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppFontSizes.sm,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/signup'),
                          child: Text('auth.signup'.tr()),
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
