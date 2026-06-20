import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/favorite_item.dart';
import '../../providers/favorite_providers.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/favorite_card.dart';
import '../../widgets/favorite_edit_modal.dart';

/// よく買う物テンプレート一覧画面（/favorites）。
///
/// deferred import 前提のため const コンストラクタを持つ StatelessWidget を起点とし、
/// 実処理は [ConsumerStatefulWidget] に委ねる。
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FavoritesScreenBody();
  }
}

class _FavoritesScreenBody extends ConsumerStatefulWidget {
  const _FavoritesScreenBody();

  @override
  ConsumerState<_FavoritesScreenBody> createState() =>
      _FavoritesScreenBodyState();
}

class _FavoritesScreenBodyState extends ConsumerState<_FavoritesScreenBody> {
  /// 選択中の FavoriteItem の id セット。
  final Set<String> _selectedIds = {};

  bool get _selectionMode => _selectedIds.isNotEmpty;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<FavoriteItem> favorites) {
    setState(() {
      if (_selectedIds.length == favorites.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(favorites.map((f) => f.id));
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  Future<void> _addToList(List<FavoriteItem> favorites) async {
    final selected = favorites
        .where((f) => _selectedIds.contains(f.id))
        .toList();
    if (selected.isEmpty) return;

    try {
      final result = await ref
          .read(favoriteControllerProvider)
          .addFavoritesToList(selected);
      if (!mounted) return;
      _clearSelection();
      if (result.added > 0) {
        AppFeedback.showToast(
          context,
          'favorites.added_count'.tr(namedArgs: {'count': '${result.added}'}),
          type: ToastType.success,
        );
      }
      if (result.skipped > 0) {
        AppFeedback.showToast(
          context,
          'favorites.skipped_count'.tr(
            namedArgs: {'count': '${result.skipped}'},
          ),
          type: ToastType.info,
        );
      }
    } on AppError catch (e) {
      if (!mounted) return;
      if (e.code == AppErrorCode.dataFavoriteLimitExceeded) {
        AppFeedback.showToast(
          context,
          'favorites.error.limit_exceeded'.tr(),
          type: ToastType.error,
        );
      } else {
        AppFeedback.showToast(
          context,
          'app.error.add'.tr(),
          type: ToastType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppFeedback.showToast(
        context,
        'app.error.add'.tr(),
        type: ToastType.error,
      );
    }
  }

  Future<void> _openAddModal() async {
    await showFavoriteEditModal(
      context,
      onSave:
          ({
            required name,
            tagId,
            required note,
            required String imageUrl,
            Uint8List? imageBytes,
          }) async {
            try {
              await ref
                  .read(favoriteControllerProvider)
                  .addFavorite(
                    name: name,
                    tagId: tagId,
                    note: note,
                    imageUrl: imageUrl,
                    imageBytes: imageBytes,
                  );
              if (mounted) Navigator.of(context).pop();
            } on AppError catch (e) {
              if (!mounted) return;
              Navigator.of(context).pop();
              if (e.code == AppErrorCode.dataFavoriteLimitExceeded) {
                AppFeedback.showToast(
                  context,
                  'favorites.error.limit_exceeded'.tr(),
                  type: ToastType.error,
                );
              } else {
                AppFeedback.showToast(
                  context,
                  'app.error.add'.tr(),
                  type: ToastType.error,
                );
              }
            } catch (_) {
              if (!mounted) return;
              Navigator.of(context).pop();
              AppFeedback.showToast(
                context,
                'app.error.add'.tr(),
                type: ToastType.error,
              );
            }
          },
    );
  }

  Future<void> _openEditModal(FavoriteItem favorite) async {
    await showFavoriteEditModal(
      context,
      favorite: favorite,
      onSave:
          ({
            required name,
            tagId,
            required note,
            required String imageUrl,
            Uint8List? imageBytes,
          }) async {
            try {
              await ref
                  .read(favoriteControllerProvider)
                  .updateFavorite(
                    favorite.id,
                    name: name,
                    tagId: tagId != null ? (() => tagId) : (() => null),
                    note: note,
                    imageUrl: imageUrl,
                    imageBytes: imageBytes,
                    previousImageUrl: favorite.imageUrl,
                  );
              if (mounted) Navigator.of(context).pop();
            } catch (_) {
              if (!mounted) return;
              Navigator.of(context).pop();
              AppFeedback.showToast(
                context,
                'app.error.update'.tr(),
                type: ToastType.error,
              );
            }
          },
    );
  }

  Future<void> _deleteFavorite(FavoriteItem favorite) async {
    final confirmed = await showConfirmDialog(
      context,
      message: 'favorites.delete_confirm'.tr(),
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(favoriteControllerProvider).deleteFavorite(favorite.id);
    } catch (_) {
      if (!mounted) return;
      AppFeedback.showToast(
        context,
        'app.error.delete'.tr(),
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // easy_localization の .tr() は static インスタンスを使うため context 依存が自動で
    // 作られない。context.locale を読むことで InheritedWidget 依存を明示し、
    // ロケール変更を確実に反映させる。
    context.locale;

    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        key: const Key('favorites_app_bar'),
        backgroundColor: AppColors.white,
        title: Text(
          'favorites.title'.tr(),
          style: const TextStyle(
            fontSize: AppFontSizes.xl,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.primary),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            key: const Key('favorites_add_button'),
            icon: const Icon(Icons.add),
            tooltip: 'favorites.add'.tr(),
            onPressed: _openAddModal,
          ),
        ],
      ),
      body: favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text('app.error.fetch'.tr())),
        data: (favorites) {
          if (favorites.isEmpty) {
            return Center(
              key: const Key('favorites_empty'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bookmark_outline,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'favorites.empty'.tr(),
                    style: const TextStyle(
                      fontSize: AppFontSizes.md,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final isAllSelected = _selectedIds.length == favorites.length;

          return Column(
            children: [
              // 選択モード時の操作バー
              if (_selectionMode)
                Container(
                  key: const Key('favorites_selection_bar'),
                  color: AppColors.primaryLight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      TextButton.icon(
                        key: const Key('favorites_select_all_button'),
                        onPressed: () => _toggleSelectAll(favorites),
                        icon: Icon(
                          isAllSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          'favorites.select_all'.tr(),
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _clearSelection,
                        child: Text('common.cancel'.tr()),
                      ),
                    ],
                  ),
                ),
              // リスト本体
              Expanded(
                child: ListView.builder(
                  key: const Key('favorites_list'),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final fav = favorites[index];
                    return FavoriteCard(
                      favorite: fav,
                      selectionMode: _selectionMode,
                      isSelected: _selectedIds.contains(fav.id),
                      onSelect: () => _toggleSelection(fav.id),
                      onEdit: () => _openEditModal(fav),
                      onDelete: () => _deleteFavorite(fav),
                    );
                  },
                ),
              ),
              // 下部バー: 選択モード時に「リストに追加」ボタンを表示
              if (_selectionMode)
                Container(
                  key: const Key('favorites_add_to_list_bar'),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: Border(
                      top: BorderSide(color: AppColors.surfaceBorder),
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: FilledButton.icon(
                    key: const Key('favorites_add_to_list_button'),
                    onPressed: () => _addToList(favorites),
                    icon: const Icon(Icons.playlist_add),
                    label: Text(
                      'favorites.add_to_list'.tr(
                        namedArgs: {'count': '${_selectedIds.length}'},
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
