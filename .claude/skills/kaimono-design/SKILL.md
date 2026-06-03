---
name: kaimono-design
description: Use this skill to generate well-branded interfaces and assets for the Kaimono shared shopping-list app (家族・グループ向け共有買い物リスト, Flutter / Material 3), either for production or throwaway prototypes/mocks. Contains essential design guidelines, colors, type, fonts, iconography, and a mobile UI kit for prototyping.
user-invocable: true
---

Read the `README.md` file within this skill, and explore the other available files.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy
assets out and create static HTML files for the user to view. If working on
production code, you can copy assets and read the rules here to become an expert
in designing with this brand.

If the user invokes this skill without any other guidance, ask them what they
want to build or design, ask some questions, and act as an expert designer who
outputs HTML artifacts _or_ production code, depending on the need.

## What's here

- `README.md` — product context, content & visual foundations, iconography, manifest.
- `colors_and_type.css` — all design tokens (color / type / spacing / radii / shadow / motion) as CSS vars + semantic type classes. Baseline (as-shipped) **and** the refreshed warm direction.
- `assets/` — iconography reference (the app ships no logo/illustration assets; the brand uses emoji + unicode glyphs).
- `preview/` — small specimen cards (colors, type, spacing, components, states).
- `ui_kits/app/` — interactive React recreation of the mobile app (login → dashboard, swipe cards, FAB add sheet, drawer, group switcher). Start from its components when mocking app screens.

## Key rules of thumb

- **Identity = indigo `#646CFF`.** Keep it for headers, primary CTAs, the group name. Add warmth with **leaf green `#2E9E6B`** (done/purchased) and **apricot `#F4A259`** (the 「買うよ」 I'll-buy-it moment) — never invent new hues.
- **Warm-paper canvas `#F6F5F2`**, flat white surfaces, **soft shadows over hard borders**, generous radii (cards 16, chips/FAB full). No gradients, no glassmorphism.
- **Iconography is emoji + unicode** (🙋 ✅ ✏️ 🗑️ ↩ 📷 👤 · ▼ ▲ ☰ ✕ ＋ ✓). Don't hand-draw SVG icons; don't use icon-font ligatures.
- **Voice:** Japanese-first, warm and action-first, light exclamation on success (追加しました！ · 買うよ！). Errors plain and blame-free. Speaks in human terms (私が買います / あなた).
- **Type:** Noto Sans JP (a flagged substitution for the platform default), weights 400–700, scale 12→28.
- **Stay within Material 3 / Flutter** stock components — mobile-first, web capped at 800px.
- Touch targets ≥ 44px; mobile gestures (swipe-to-reveal actions, long-press multi-select) are preferred over always-visible button rows.
