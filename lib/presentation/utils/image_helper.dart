import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../core/constants/image_policy.dart';

/// 画像選択・リサイズ・表示に関するユーティリティ。
class ImageHelper {
  ImageHelper(this._picker);

  final ImagePicker _picker;

  /// ギャラリーから画像を選び、ポリシーに従ってリサイズした JPEG バイト列を返す。
  /// キャンセル時は null。
  Future<Uint8List?> pickResized(ImageTier tier) async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return resizeBytes(bytes, tier);
  }

  /// 必要であれば画像バイト列をリサイズして JPEG にエンコードする。
  /// ファイルサイズがポリシー上限以下ならそのまま返す。
  static Uint8List resizeBytes(Uint8List bytes, ImageTier tier) {
    final policy = imageSizePolicies[tier]!;
    if (bytes.length <= policy.maxBytes) return bytes;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final resized = decoded.width > policy.maxWidth
        ? img.copyResize(decoded, width: policy.maxWidth)
        : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: policy.compress));
  }

  /// バイト列を `data:image/jpeg;base64,...` データ URI に変換する。
  static String toDataUri(Uint8List bytes) =>
      'data:image/jpeg;base64,${base64Encode(bytes)}';
}

/// `imageUrl`（http(s) URL または data URI）から [ImageProvider] を解決する。
/// 空文字の場合は null。
ImageProvider? imageProviderFromUrl(String url) {
  if (url.isEmpty) return null;
  if (url.startsWith('data:')) {
    final comma = url.indexOf(',');
    if (comma < 0) return null;
    try {
      return MemoryImage(base64Decode(url.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(url);
}
