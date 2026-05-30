/// 画像リサイズポリシーの種別。
enum ImageTier { avatar, item }

/// 画像リサイズポリシー。
///
/// 元の `src/types/imagePolicy.ts` を移植。
class ImageSizePolicy {
  const ImageSizePolicy({
    required this.maxWidth,
    required this.maxHeight,
    required this.maxBytes,
    required this.compress,
  });

  /// 最大幅（px）。アスペクト比を維持しながらリサイズ。
  final int maxWidth;

  /// 最大高さ（px）。
  final int maxHeight;

  /// この値（バイト）を超えるとリサイズ対象とみなすファイルサイズ。
  final int maxBytes;

  /// JPEG 圧縮品質（0〜100。元実装の 0〜1 を image パッケージの仕様に合わせて 0〜100 で保持）。
  final int compress;
}

/// 種別ごとのリサイズポリシー定義。
const Map<ImageTier, ImageSizePolicy> imageSizePolicies = {
  ImageTier.avatar: ImageSizePolicy(
    maxWidth: 400,
    maxHeight: 400,
    maxBytes: 512 * 1024, // 512KB
    compress: 70,
  ),
  ImageTier.item: ImageSizePolicy(
    maxWidth: 1024,
    maxHeight: 1024,
    maxBytes: 1024 * 1024, // 1MB
    compress: 70,
  ),
};
