import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shopping_list_app/core/constants/image_policy.dart';
import 'package:shopping_list_app/presentation/utils/image_helper.dart';

/// グラデーションパターンを持つ JPEG を生成する。
/// 単色 PNG は非常に小さくなるため、ポリシー閾値を超えさせるには JPEG + グラデーションを使う。
Uint8List _makeGradientJpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixel(x, y, img.ColorRgb8(x % 256, y % 256, (x + y) % 256));
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 100));
}

void main() {
  group('ImageHelper.resizeBytes', () {
    test('デコード不可バイト列は原本をそのまま返す', () {
      // img.decodeImage が null を返す（有効な画像フォーマットでない）バイト列
      final invalid = Uint8List(100); // ゼロ列は画像として解釈不能
      final result = ImageHelper.resizeBytes(invalid, ImageTier.avatar);
      expect(result, same(invalid));
    });

    test('アバター画像は幅 400px 以内にリサイズして JPEG で返す', () {
      // 1200x1200 グラデーション JPEG → avatar 上限 400px 以内
      final bigJpeg = _makeGradientJpeg(1200, 1200);
      final policy = imageSizePolicies[ImageTier.avatar]!;

      final result = ImageHelper.resizeBytes(bigJpeg, ImageTier.avatar);

      final decoded = img.decodeJpg(result);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(policy.maxWidth));
    });

    test('アイテム画像は常に 768px 以内にリサイズして JPEG で返す', () {
      // 2000x2000 グラデーション JPEG → item 上限 768px 以内
      final bigJpeg = _makeGradientJpeg(2000, 2000);
      final policy = imageSizePolicies[ImageTier.item]!;

      final result = ImageHelper.resizeBytes(bigJpeg, ImageTier.item);

      final decoded = img.decodeJpg(result);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(policy.maxWidth));
    });

    test('縦長アイテム画像は幅・高さとも 768px 以内に収まる', () {
      // 幅は上限以下だが高さが上限超過の縦長画像。長辺(高さ)基準で縮小され、
      // 高さ・幅とも 768 以内に収まること（Storage Rules 1MiB 制限の超過回避）。
      final tallJpeg = _makeGradientJpeg(600, 2400);
      final policy = imageSizePolicies[ImageTier.item]!;

      final result = ImageHelper.resizeBytes(tallJpeg, ImageTier.item);

      final decoded = img.decodeJpg(result);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(policy.maxWidth));
      expect(decoded.height, lessThanOrEqualTo(policy.maxHeight));
    });

    test('ポリシー上限以下のアイテム画像も常に再エンコードされる', () {
      // 300x300 は 768 以下だが、常時エンコードにより再エンコードされた JPEG が返る
      final smallJpeg = _makeGradientJpeg(300, 300);
      final policy = imageSizePolicies[ImageTier.item]!;
      final result = ImageHelper.resizeBytes(smallJpeg, ImageTier.item);
      final decoded = img.decodeJpg(result);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(policy.maxWidth));
      // 再エンコード後は元バイト列と同一オブジェクトではない
      expect(result, isNot(same(smallJpeg)));
    });
  });

  group('ImageHelper.toDataUri', () {
    test('image/jpeg の data URI を返す', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final uri = ImageHelper.toDataUri(bytes);
      expect(uri, startsWith('data:image/jpeg;base64,'));
    });
  });

  group('imageProviderFromUrl', () {
    test('空文字は null を返す', () {
      expect(imageProviderFromUrl(''), isNull);
    });

    test('data:image/jpeg;base64,... は MemoryImage を返す', () {
      final uri = ImageHelper.toDataUri(Uint8List.fromList([1, 2, 3]));
      expect(imageProviderFromUrl(uri), isNotNull);
    });

    test('https:// URL は CachedNetworkImageProvider を返す', () {
      final provider = imageProviderFromUrl('https://example.com/img.jpg');
      expect(provider, isA<CachedNetworkImageProvider>());
    });
  });
}
