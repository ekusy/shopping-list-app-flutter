import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/image_policy.dart';
import '../../core/constants/validation_limits.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/favorite_item.dart';
import '../providers/group_providers.dart';
import '../utils/image_helper.dart';

/// よく買う物テンプレートの新規追加 / 編集モーダルを表示する。
///
/// [favorite] が null の場合は新規追加、非 null の場合は既存テンプレートの編集。
/// [onSave] コールバックに name / tagId / note / imageUrl / imageBytes を渡す。
/// [imageBytes] が非 null の場合、呼び出し元が Storage へアップロードして
/// `imageUrl` を更新する（アイテムと同じ 2 段保存フロー）。[imageUrl] は既存の URL
/// または削除時は空文字。
Future<void> showFavoriteEditModal(
  BuildContext context, {
  FavoriteItem? favorite,
  required Future<void> Function({
    required String name,
    String? tagId,
    required String note,
    required String imageUrl,
    Uint8List? imageBytes,
  })
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
      child: _FavoriteEditContent(favorite: favorite, onSave: onSave),
    ),
  );
}

class _FavoriteEditContent extends ConsumerStatefulWidget {
  const _FavoriteEditContent({required this.favorite, required this.onSave});

  final FavoriteItem? favorite;
  final Future<void> Function({
    required String name,
    String? tagId,
    required String note,
    required String imageUrl,
    Uint8List? imageBytes,
  })
  onSave;

  @override
  ConsumerState<_FavoriteEditContent> createState() =>
      _FavoriteEditContentState();
}

class _FavoriteEditContentState extends ConsumerState<_FavoriteEditContent> {
  late final TextEditingController _name;
  late final TextEditingController _note;
  late String _tagId;

  /// 既存の imageUrl（https URL または移行期の dataURI）。
  /// 新規選択後は新しい URL に置き換えられる。削除操作で空文字になる。
  late String _imageUrl;

  /// 新たに選択した画像バイト列。非 null のとき呼び出し元が Storage アップロードを行う。
  Uint8List? _newImageBytes;

  bool _saving = false;

  bool get _isNew => widget.favorite == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.favorite?.name ?? '');
    _note = TextEditingController(text: widget.favorite?.note ?? '');
    _tagId = widget.favorite?.tagId ?? '';
    _imageUrl = widget.favorite?.imageUrl ?? '';
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
      setState(() {
        _newImageBytes = bytes;
        // プレビュー用に _imageUrl を一時的にクリアして _newImageBytes を優先表示する
        _imageUrl = '';
      });
    }
  }

  void _removeImage() {
    setState(() {
      _newImageBytes = null;
      _imageUrl = '';
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await widget.onSave(
      name: _name.text.trim(),
      tagId: _tagId.isEmpty ? null : _tagId,
      note: _note.text,
      imageUrl: _imageUrl,
      imageBytes: _newImageBytes,
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider).value ?? const [];

    // プレビュー優先順位: 新規選択バイト列 > 既存 URL > なし
    final ImageProvider? preview = _newImageBytes != null
        ? MemoryImage(_newImageBytes!)
        : imageProviderFromUrl(_imageUrl);

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
                _isNew ? 'favorites.add'.tr() : 'favorites.edit_title'.tr(),
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
            key: const Key('favorite_name_field'),
            controller: _name,
            maxLength: ValidationLimits.itemName,
            decoration: InputDecoration(hintText: 'item.name_placeholder'.tr()),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            key: const Key('favorite_tag_dropdown'),
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
                key: const Key('favorite_photo_button'),
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
                        key: const Key('favorite_remove_image_button'),
                        icon: const CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.errorAccent,
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: _removeImage,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('favorite_note_field'),
            controller: _note,
            maxLength: ValidationLimits.itemNote,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(hintText: 'form.placeholder_note'.tr()),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('favorite_save_button'),
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
