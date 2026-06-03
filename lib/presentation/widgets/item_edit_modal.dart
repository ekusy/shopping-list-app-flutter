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

/// アイテム編集モーダル（名前・タグ・メモ・写真）をボトムシートで表示する。
Future<void> showItemEditModal(
  BuildContext context, {
  required Item item,
  required Future<void> Function(
    String name,
    String? tagId,
    String note,
    String imageUrl,
  )
  onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _ItemEditContent(item: item, onSave: onSave),
    ),
  );
}

class _ItemEditContent extends ConsumerStatefulWidget {
  const _ItemEditContent({required this.item, required this.onSave});

  final Item item;
  final Future<void> Function(
    String name,
    String? tagId,
    String note,
    String imageUrl,
  )
  onSave;

  @override
  ConsumerState<_ItemEditContent> createState() => _ItemEditContentState();
}

class _ItemEditContentState extends ConsumerState<_ItemEditContent> {
  late final TextEditingController _name;
  late final TextEditingController _note;
  late String _tagId;
  late String _imageUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item.name);
    _note = TextEditingController(text: widget.item.note);
    _tagId = widget.item.tagId ?? '';
    _imageUrl = widget.item.imageUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final bytes = await ImageHelper(ImagePicker()).pickResized(ImageTier.item);
    if (bytes != null) {
      setState(() => _imageUrl = ImageHelper.toDataUri(bytes));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(
      _name.text,
      _tagId.isEmpty ? null : _tagId,
      _note.text,
      _imageUrl,
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider).value ?? const [];
    final preview = imageProviderFromUrl(_imageUrl);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'item.edit_title'.tr(),
                style: const TextStyle(
                  fontSize: AppFontSizes.lg,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _name,
            maxLength: ValidationLimits.itemName,
            decoration: InputDecoration(hintText: 'item.name_placeholder'.tr()),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _tagId,
            decoration: const InputDecoration(isDense: true),
            items: [
              DropdownMenuItem(value: '', child: Text('tag.no_tag'.tr())),
              for (final tag in tags)
                DropdownMenuItem(value: tag.id, child: Text(tag.name)),
            ],
            onChanged: (v) => setState(() => _tagId = v ?? ''),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              OutlinedButton(
                onPressed: _pickImage,
                child: Text('form.photo_button'.tr()),
              ),
              const SizedBox(width: AppSpacing.md),
              if (preview != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: Image(
                        image: preview,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: IconButton(
                        icon: const CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.errorAccent,
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: () => setState(() => _imageUrl = ''),
                      ),
                    ),
                  ],
                ),
            ],
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
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? 'item.edit_saving'.tr() : 'item.edit_save'.tr(),
            ),
          ),
        ],
      ),
    );
  }
}
