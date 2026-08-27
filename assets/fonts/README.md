# バンドルフォント

## Noto Sans JP（サブセット）

Web（CanvasKit）はエンジンがフォントを管理し、OS のシステムフォントへフォールバック
しない。そのため日本語グリフを持たない Roboto のみでは日本語が tofu（□）になる（#75）。
オフライン優先 PWA の方針に合わせ、実行時ダウンロードではなく**サブセットを同梱**する。

| 項目 | 内容 |
|---|---|
| ファミリー名 | `NotoSansJP`（`pubspec.yaml` の `fonts:` で登録） |
| ウェイト | Regular (400) / Bold (700) |
| 取得元 | Google Fonts CSS API v2（`https://fonts.googleapis.com/css2?family=Noto+Sans+JP`） |
| 元バージョン | Version 2.004-H2（Noto Sans JP v56 / 2026-08 時点） |
| 収録文字 | JIS X 0208（第1・第2水準）+ ASCII + Latin-1 + 半角カナ + 約物・矢印・記号（7,445 文字） |
| サイズ | 各約 2.2MB（フル版は約 5.1MB） |
| ライセンス | SIL Open Font License 1.1（[OFL.txt](./OFL.txt)） |

### 再生成

```bash
pip install fonttools brotli
python3 scripts/subset-noto-sans-jp.py
```

### 収録していない文字

絵文字（👤 / 🔄 / 🗑 など）と一部の記号（✕ / ☑ / ✅ など）は **Noto Sans JP に元から
含まれない**。これらは従来どおり Flutter エンジンが実行時にフォールバックフォントを
取得して描画する（`web/index.html` の preconnect はこの取得のために残している）。

JIS X 0208 の範囲外の漢字（𠮟 などの JIS 第3・第4水準や異体字）も収録していない。
ユーザーが入力した商品名にこれらが含まれる場合はフォールバックに委ねられる。
収録範囲を広げる場合は `scripts/subset-noto-sans-jp.py` の `EXTRA_RANGES` を編集する
（フル版に戻すとバンドルが 1 ウェイトあたり約 5.1MB 増える点に注意）。

### ライセンス表示

`lib/main.dart` で `LicenseRegistry` に OFL を登録しているため、`showLicensePage()` から
ライセンス全文を参照できる。
