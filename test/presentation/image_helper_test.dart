import 'dart:typed_data';

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
    test('ポリシー上限以下のバイト列はそのまま返す', () {
      final small = Uint8List(100);
      final result = ImageHelper.resizeBytes(small, ImageTier.avatar);
      expect(result, same(small));
    });

    test('上限を超えるアバター画像は幅 400px 以内にリサイズして JPEG で返す', () {
      // 1200x1200 グラデーション JPEG は 512KB (avatar 上限) を超える
      final bigJpeg = _makeGradientJpeg(1200, 1200);
      final policy = imageSizePolicies[ImageTier.avatar]!;
      expect(bigJpeg.length, greaterThan(policy.maxBytes));

      final result = ImageHelper.resizeBytes(bigJpeg, ImageTier.avatar);

      final decoded = img.decodeJpg(result);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(policy.maxWidth));
    });

    test('上限を超えるアイテム画像は幅 1024px 以内にリサイズして JPEG で返す', () {
      // 2000x2000 グラデーション JPEG は 1MB (item 上限) を超える
      final bigJpeg = _makeGradientJpeg(2000, 2000);
      final policy = imageSizePolicies[ImageTier.item]!;
      expect(bigJpeg.length, greaterThan(policy.maxBytes));

      final result = ImageHelper.resizeBytes(bigJpeg, ImageTier.item);

      final decoded = img.decodeJpg(result);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(policy.maxWidth));
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

    test('https:// URL は NetworkImage を返す', () {
      expect(imageProviderFromUrl('https://example.com/img.jpg'), isNotNull);
    });
  });
}
