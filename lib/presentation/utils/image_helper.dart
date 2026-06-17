import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
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

  /// 画像バイト列をポリシーに従って **常に** リサイズして JPEG にエンコードする。
  ///
  /// - デコード成功時: 長辺を maxWidth / maxHeight 以下に収まるよう縮小し、
  ///   JPEG(q=compress) で再エンコード。元画像が上限以下でも再エンコードを行う
  ///   （Storage 保存前の品質統一）。縦長・横長の双方で上限を超えないため、
  ///   Storage Rules の 1MiB 制限超過を避けられる。
  /// - デコード失敗時: 原本をそのまま返す（フォールバック）。
  static Uint8List resizeBytes(Uint8List bytes, ImageTier tier) {
    final policy = imageSizePolicies[tier]!;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final exceedsLimit =
        decoded.width > policy.maxWidth || decoded.height > policy.maxHeight;
    final img.Image resized;
    if (exceedsLimit) {
      // 長辺を基準に縮小（copyResize はアスペクト比を維持）。
      resized = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: policy.maxWidth)
          : img.copyResize(decoded, height: policy.maxHeight);
    } else {
      resized = decoded;
    }
    return Uint8List.fromList(img.encodeJpg(resized, quality: policy.compress));
  }

  /// バイト列を `data:image/jpeg;base64,...` データ URI に変換する。
  ///
  /// 移行期の互換用途（`imageProviderFromUrl` の dataURI 読み取り分岐）のために残置。
  /// Storage 移行後は新規の書き込み用途では使用しない。
  static String toDataUri(Uint8List bytes) =>
      'data:image/jpeg;base64,${base64Encode(bytes)}';
}

/// `imageUrl`（http(s) URL または data URI）から [ImageProvider] を解決する。
/// 空文字の場合は null。
///
/// - http(s) URL: [CachedNetworkImageProvider] を返す（ディスクキャッシュ有効）。
///   表示側で `cacheWidth` を指定するとデコード負荷をさらに軽減できる（任意）。
/// - data URI: [MemoryImage] を返す（移行期の既存 Base64 データ互換）。
/// - 空文字: null。
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
  return CachedNetworkImageProvider(url);
}
