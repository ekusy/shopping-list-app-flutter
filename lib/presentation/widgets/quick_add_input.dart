import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// クイック追加インプット（名前のみ）。Enter または追加ボタンで送信し、入力欄をリセット。
class QuickAddInput extends StatefulWidget {
  const QuickAddInput({super.key, required this.onAdd, this.disabled = false});

  final Future<void> Function(String name) onAdd;
  final bool disabled;

  @override
  State<QuickAddInput> createState() => _QuickAddInputState();
}

class _QuickAddInputState extends State<QuickAddInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onAdd(trimmed);
      _controller.clear();
      _focusNode.requestFocus();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.disabled && !_submitting;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.surfaceBorder),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: enabled,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'quick_add.placeholder'.tr(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: enabled ? _submit : null,
            child: Text('form.add_button'.tr()),
          ),
        ],
      ),
    );
  }
}
