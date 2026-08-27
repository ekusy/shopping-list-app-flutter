#!/usr/bin/env python3
"""assets/fonts/NotoSansJP-{Regular,Bold}.ttf を再生成する。

Google Fonts が配信する Noto Sans JP から、日本語 UI に必要な文字だけを残した
サブセットを作る（#75）。フル版は 1 ウェイト約 5.1MB あり Web バンドルには重すぎるため、
JIS X 0208（第1・第2水準）+ ASCII + Latin-1 + 半角カナ + 記号に絞って約 2.2MB にしている。

使い方（fonttools が必要）:

    pip install fonttools brotli
    python3 scripts/subset-noto-sans-jp.py

注意:
  - 絵文字（U+1F300〜 等）と一部の記号（✕ / ☑ 等）は Noto Sans JP に元から含まれない。
    これらは実行時に Flutter エンジンがフォールバックフォントを取得して描画する。
  - フォントを差し替えたら `assets/fonts/README.md` のバージョンも更新すること。
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

# Google Fonts CSS API v2。UA を送らないと TTF（Flutter が読める形式）が返る。
CSS_URL = "https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@{weight}"
WEIGHTS = {"Regular": 400, "Bold": 700}
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "fonts"

# JIS X 0208 以外に含める文字（記号・約物・矢印など）。
EXTRA_RANGES = [
    (0x0020, 0x007E),  # ASCII
    (0x00A0, 0x00FF),  # Latin-1 Supplement
    (0xFF61, 0xFF9F),  # 半角カナ
    (0x2010, 0x2027),  # 一般約物
    (0x2030, 0x203F),
    (0x20A0, 0x20BF),  # 通貨記号
    (0x2190, 0x21FF),  # 矢印
    (0x25A0, 0x25FF),  # 幾何学模様
    (0x2600, 0x264F),  # その他の記号
]


def jis_x0208_chars() -> set[str]:
    """EUC-JP でデコードできる 2 バイト列から JIS X 0208 の文字集合を得る。"""
    chars: set[str] = set()
    for hi in range(0xA1, 0xFF):
        for lo in range(0xA1, 0xFF):
            try:
                chars.add(bytes([hi, lo]).decode("euc_jp"))
            except UnicodeDecodeError:
                continue
    return chars


def ttf_url(weight: int) -> str:
    with urllib.request.urlopen(CSS_URL.format(weight=weight), timeout=60) as res:
        css = res.read().decode("utf-8")
    for token in css.split("url("):
        if token.startswith("https://") and ".ttf" in token:
            return token.split(")")[0]
    raise RuntimeError(f"TTF の URL を CSS から取得できなかった (weight={weight})")


def main() -> int:
    chars = jis_x0208_chars()
    for start, end in EXTRA_RANGES:
        chars.update(chr(c) for c in range(start, end + 1))
    print(f"サブセット対象: {len(chars)} 文字")

    with tempfile.TemporaryDirectory() as tmp:
        text_file = Path(tmp) / "chars.txt"
        text_file.write_text("".join(sorted(chars)), encoding="utf-8")

        for name, weight in WEIGHTS.items():
            url = ttf_url(weight)
            src = Path(tmp) / f"NotoSansJP-{name}-full.ttf"
            urllib.request.urlretrieve(url, src)
            dst = OUT_DIR / f"NotoSansJP-{name}.ttf"
            subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "fontTools.subset",
                    str(src),
                    f"--text-file={text_file}",
                    "--layout-features=*",
                    "--name-IDs=*",
                    f"--output-file={dst}",
                ],
                check=True,
            )
            print(f"{dst.name}: {src.stat().st_size / 1e6:.1f}MB -> {dst.stat().st_size / 1e6:.1f}MB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
