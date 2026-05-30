import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/image_policy.dart';
import '../../core/constants/validation_limits.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/item.dart';
import '../providers/group_providers.dart';
import '../utils/image_helper.dart';

/// 商品追加フォーム（名前・タグ・メモ・写真）。写真は Base64 データ URI として保存する。
class AddItemForm extends ConsumerStatefulWidget {
  const AddItemForm({super.key, required this.onAdd});

  /// 追加するアイテム（id は無視、addedBy/order は呼び出し元が補完）。
  final Future<void> Function(Item draft) onAdd;

  @override
  ConsumerState<AddItemForm> createState() => _AddItemFormState();
}

class _AddItemFormState extends ConsumerState<AddItemForm> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  String _tagId = '';
  String _imageDataUri = '';
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final bytes = await ImageHelper(ImagePicker()).pickResized(ImageTier.item);
    if (bytes != null) {
      setState(() => _imageDataUri = ImageHelper.toDataUri(bytes));
    }
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _uploading = true);
    final draft = Item(
      id: '',
      name: _name.text.trim(),
      category: '',
      note: _note.text,
      imageUrl: _imageDataUri,
      status: ItemStatus.active,
      buyingBy: null,
      tagId: _tagId.isEmpty ? null : _tagId,
    );
    await widget.onAdd(draft);
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider).value ?? const [];
    final preview = imageProviderFromUrl(_imageDataUri);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          maxLength: ValidationLimits.itemName,
          decoration: InputDecoration(hintText: 'form.placeholder_name'.tr()),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _tagId,
                decoration: const InputDecoration(isDense: true),
                items: [
                  DropdownMenuItem(value: '', child: Text('tag.no_tag'.tr())),
                  for (final tag in tags)
                    DropdownMenuItem(value: tag.id, child: Text(tag.name)),
                ],
                onChanged: (v) => setState(() => _tagId = v ?? ''),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: _pickImage,
              child: Text('form.photo_button'.tr()),
            ),
          ],
        ),
        if (preview != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: Image(
                    image: preview,
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: IconButton(
                    icon: const CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.errorAccent,
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                    onPressed: () => setState(() => _imageDataUri = ''),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _note,
          maxLength: ValidationLimits.itemNote,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(hintText: 'form.placeholder_note'.tr()),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: _uploading ? null : _submit,
          child: Text(_uploading
              ? 'form.adding'.tr()
              : 'form.add_button'.tr()),
        ),
      ],
    );
  }
}
