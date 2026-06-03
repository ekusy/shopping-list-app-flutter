# Kaimono Shopping List — Design System

A design system for **家族・グループ向けの共有買い物リストアプリ** — a shared
shopping-list app for families and small groups, built in **Flutter** and
running on **Web / Android / iOS**.

> The product's own one-liner captures the loop perfectly:
> *「気づいたら記録、記録したら自動で共有、『買います』『買った』で行動も共有」*
> — *Notice it → jot it down → it's instantly shared → "I'll buy it" / "Bought it"
> shares the action too.*

This system is built from the app's real source code (theme tokens, widgets,
screens, and i18n copy) and then **evolves it** to answer a UI re-examination
brief: make it feel like *a warm app a family uses together* without losing the
clean, legible, Material-3 foundation. Everything proposed here stays inside
what stock Flutter / Material 3 components can do — no custom renderers.

---

## Sources

This system was derived directly from the following repository. The reader is
encouraged to explore it for deeper fidelity when building new screens or
production code:

- **GitHub — `ekusy/shopping-list-app-flutter`**
  https://github.com/ekusy/shopping-list-app-flutter
  Flutter 3.44 / Dart 3.12 · Riverpod · go_router · Firebase · easy_localization (ja/en)
  - Design tokens: `lib/core/theme/app_theme.dart`
  - Item action icons (emoji): `lib/core/utils/item_icons.dart`
  - Screens: `lib/presentation/screens/**` (auth, dashboard, group, profile)
  - Widgets: `lib/presentation/widgets/**` (item_card, filter_bar, quick_add_input, shopping_list, …)
  - Copy / i18n: `assets/translations/ja.json`, `assets/translations/en.json`
- Predecessor (React Native / Expo) the Flutter app was ported from:
  `ekusy/shopping-list-app` (private).

No logo, illustration, or photographic asset ships in the repo — the brand is
expressed purely through **color, type, emoji iconography, and layout**. See
*Iconography* below.

---

## Product at a glance

| Area | What it does |
|---|---|
| **Auth** | Email + password login / signup, profile (avatar upload), account delete |
| **Groups** | Create / rename / leave / disband / switch, invite by code or share-URL |
| **Tags** | Add (free: 5 / paid: 50), rename, delete, **OR** filtering |
| **Items** | Add / quick-add / edit / delete, mark purchased, **「買います」(I'll buy)** declaration, bulk tag, clear-purchased, pending-sync badge |
| **Platform** | Offline-aware (network banner + pending count), i18n ja/en |

**Core screen — the Dashboard** (max content width **800px**, centred on web):

```
┌───────────────────────────────────────┐
│ Group name ▼            [タグ]   [☰]    │  ← app bar (group switcher / tag mgr / drawer)
├───────────────────────────────────────┤
│ [すべて][急ぎ][まとめ買い] …             │  ← FilterBar (horizontal tag chips, OR filter)
│                                         │
│ 急ぎ  2件 ───────────────────────       │  ← tag SECTION header (collapsible)
│  ▢ 牛乳            🙋私が買います  ✅✏🗑 │  ← ItemCard
│  ▢ パン                          🙋✅✏🗑│
│                                         │
│ 購入済み (3件)  ─────────  全削除  ▲     │  ← purchased section
├───────────────────────────────────────┤
│  [ 商品を追加… ___________ ]      (+)    │  ← quick-add + detail FAB
└───────────────────────────────────────┘
```

---

## CONTENT FUNDAMENTALS

How the product speaks. Pulled from `assets/translations/ja.json` (primary) and
`en.json`. The voice is **friendly, concise, and action-first** — a helper
standing next to you, not a system reporting at you.

- **Language:** Japanese-first, English parity. UI strings are short noun- or
  verb-phrases, almost never full sentences.
- **Tone:** Warm and encouraging, with **light exclamation** on positive
  moments. Successes celebrate briefly:
  - `追加しました！` (Added!) · `担当しました！` (You're on it!) ·
    `購入済みにしました！` (Marked as bought!)
  - The flagship action button is literally **`買うよ！`** ("I'll buy it!") — casual,
    spoken, first-person volunteering. This is the emotional heart of the copy.
- **Person:** Speaks to the user as **あなた/私 (I/you)** in human terms —
  badges say `私が買います` ("I'll buy this"), `{name} が買います` ("{name} will buy
  this"), `あなた` (you), `オーナー` (owner). It frames the list as *people doing
  things for each other*, not tasks in a queue.
- **Casing (English):** Sentence case for messages ("Added!", "Marked as
  bought!"); Title-ish for short button labels. Never SHOUTY CAPS except the
  drawer's section eyebrow `LANGUAGE`/`言語` (uppercased, letter-spaced).
- **Confirmations are gentle questions:** `削除しますか？` (Delete this?),
  `グループから脱退しますか？` (Leave this group?), `退会してもよいですか？この操作は
  取り消せません。` (OK to delete your account? This can't be undone.)
- **Errors are plain and blame-free:** `更新に失敗しました` (Couldn't update),
  `招待コードが無効です` (That invite code isn't valid),
  `メールアドレスまたはパスワードが正しくありません` (Email or password is incorrect).
  Always state what happened, never scold.
- **Status is reassuring, not alarming:** offline reads
  `オフラインです（再接続を待っています）` (You're offline — waiting to reconnect),
  with a calm pending counter `同期待ち {count} 件`.
- **Emoji as punctuation of feeling:** used deliberately inside copy/buttons
  (🙋 ✅ 🗑️ ⏳ 👤 📷) — see *Iconography*. They carry warmth; they are not
  decorative spam.
- **Numbers & units:** counts use a compact `{count}件` pattern
  (`2件`, `購入済み (3件)`). Limits are stated kindly: `あと{count}件追加可能`
  (You can add {count} more).

**Micro-glossary (use these exact terms):**

| Concept | JA | EN |
|---|---|---|
| Shared list group | グループ | Group |
| Tag / category | タグ | Tag |
| Volunteer to buy | 買うよ！ / 私が買います | I'll buy it! / I'll buy this |
| Mark bought | 購入済 | Bought |
| Quick add | クイック追加 | Quick add |
| Detail add | 詳細追加 | Add details |
| Pending sync | 同期待ち | Pending sync |

---

## VISUAL FOUNDATIONS

The honest baseline first, then the refresh this system commits to.

### The baseline (as-shipped)
A clean, slightly clinical Material-3 surface: cool blue-grey background
(`#F0F4F8`), white cards outlined with **1px hairline borders**, periwinkle-indigo
primary (`#646CFF`), slate text. Spacing scale 4/8/16/24/32. Corner radii
4/8/16/20/full. Almost no shadow — separation comes from borders. Emoji do the
heavy lifting for action affordances. It reads as a competent React-port; it
does not yet feel *warm*.

### The refresh (this system)
A warmer, softer, more human take that keeps every legibility win:

- **Color vibe:** Indigo identity is preserved (`#646CFF` still drives headers,
  primary CTAs, and the group name). We **warm the canvas** from cool blue-grey
  to soft paper (`#F6F5F2`) and introduce two human accents — a friendly **leaf
  green** (`#2E9E6B`) for *done / purchased / success*, and a warm **apricot**
  (`#F4A259`) for the *「買うよ」 I'll-buy-it* volunteer moment (the app's most
  emotional interaction). Indigo = structure, green = accomplishment,
  apricot = helping each other.
- **Imagery:** none in-brand. Items may carry a **user photo** (Base64 data-URI,
  resized, shown at 150px, `cover`, radius `--r-sm`). No stock photography, no
  illustration, no full-bleed hero. Keep it that way — the *content* (what the
  family needs) is the imagery.
- **Backgrounds:** flat warm-neutral fills only. **No gradients**, no textures,
  no patterns. Surfaces are flat white; the app bar and bottom bar are white
  against the warm-paper scroll area.
- **Cards:** the signature element. Refreshed cards use **radius `--r-lg` (16px)**
  and a **soft warm shadow (`--shadow-1`)** instead of a hard 1px border for the
  resting state. State is shown by **wash + left feel**, not heavy outlines:
  - default → white + soft shadow
  - someone volunteering → apricot wash (`--accent-apricot-light`) + indigo-to-apricot accent
  - bought → green wash (`--accent-green-light`), 0.6 opacity, name struck-through
  - selected (bulk) → primary-light wash + 2px primary border
- **Borders:** reserved for inputs, chips, and section dividers (a 2px bottom
  rule under tag-section headers). Cards lead with shadow, not border.
- **Shadows:** subtle, warm-tinted, two steps (`--shadow-1` resting card,
  `--shadow-2` sheets/menus) plus a tinted **FAB glow** (`--shadow-fab`). Never
  hard or far-cast.
- **Corner radii:** generous. Cards 16, quick-add field & bottom-sheet top 20,
  chips/FAB/pills full. Friendly, never sharp.
- **Transparency & blur:** used lightly — status washes are translucent tints
  (`rgba` of the accent); the offline banner is a translucent red wash. No
  glassmorphism / backdrop-blur.
- **Hover / press (web + ripple):** primary lightens to `--primary-hover` on
  hover and darkens to `--primary-pressed` on press; icon buttons get an
  `--overlay` (5% black) wash; Material ripple on tap. Subtle scale (0.97) is
  acceptable on the FAB press. Nothing bounces.
- **Motion:** Material 3 standard easing (`cubic-bezier(0.2,0,0,1)`), 120–300ms.
  Bottom sheet slides up; chips & checkboxes cross-fade; toasts fade.
  **Swipe-to-reveal** card actions and **long-press** multi-select are the two
  signature gestures (see UI kit). No looping/decorative animation.
- **Layout rules:** single column, centred, capped at **800px** on web so it
  never sprawls. App bar fixed top, action bar fixed bottom, list scrolls
  between. Touch targets ≥ 44px (icon buttons are 32px today — the refresh bumps
  primary actions to 44px).
- **Type:** one family — **Noto Sans JP** (substitution for the platform default,
  flagged below). Weights 400/500/600/700. Sizes 12→28 on the documented scale.
  Indigo is used as a *text color* for the group name and auth title — a small,
  distinctive brand tell.

See `colors_and_type.css` for every token, and the cards in the **Design System**
tab for live specimens.

---

## ICONOGRAPHY

The app has **no icon-font of its own and ships no SVG/PNG icon assets.** Icons
come from three sources, in this order of prominence:

1. **Emoji — the primary action vocabulary.** Defined centrally in
   `lib/core/utils/item_icons.dart` (`ItemIconConfig`). These are deliberate,
   warm, and load-free, and they ARE the brand's icon language:

   | Emoji | Meaning | Where |
   |---|---|---|
   | 🙋 | Volunteer / "I'll buy" | volunteer button + "私が買います" badge |
   | ✕ | Cancel volunteering | when you're the buyer |
   | 🔄 | Take over from someone | when another person volunteered |
   | ✅ | Mark bought | bought button |
   | ↩ | Return to unbought | on a bought item |
   | 🗑️ | Delete | delete button |
   | ⏳ | Pending sync | offline write badge |
   | 👤 | Other person | "{name} will buy" badge |
   | 📷 | Photo | add-item photo button |

   > Design note from the source: 🛒 (cart) is **intentionally avoided** for
   > volunteering because it reads as "purchased." 🙋 (raised hand) was chosen to
   > mean "I'll take this on." Respect that distinction.

2. **Unicode glyphs — structural affordances.** `▼ ▲` (group switcher caret,
   section collapse), `☐ ☑` (selection checkbox), `＋` (detail-add prefix).

3. **Material Icons — chrome only.** `Icons.menu` (☰ drawer), `Icons.close`
   (sheet/preview dismiss). Available everywhere Material 3 runs.

**Guidance for this design system & UI kit:** keep emoji as the action language
— it's a genuine brand signature, not slop. For any Material chrome icon, use
the **Material Symbols (Rounded)** webfont from CDN (closest match to Flutter's
Material Icons, with the rounded style reinforcing the warm refresh).
**SUBSTITUTION flagged** — see below. Never hand-draw replacement SVGs.

---

## Fonts — substitution flagged ⚠️

The app sets `fontFamily: null`, i.e. it renders in the **platform default**
(Roboto on Android/Web, with the OS CJK fallback for Japanese). There is no
bundled font file to copy. For faithful, consistent, warm Japanese rendering
across this HTML design system, we standardise on **Noto Sans JP** (loaded from
Google Fonts CDN in each HTML file) with **Roboto** for Latin/numerals.

> **Please confirm / replace:** if production should pin a specific face (e.g.
> bundle Noto Sans JP, or keep the bare platform default), send the font files
> or the preferred family and we'll swap `--font-sans` accordingly.

Material chrome icons use **Material Symbols Rounded** (CDN) as a stand-in for
Flutter's Material Icons — flag if you'd prefer the sharp/outlined variant.

---

## Index / manifest

Root files:

- **`README.md`** — this file (context, content & visual foundations, iconography, manifest).
- **`colors_and_type.css`** — all design tokens (color, type, spacing, radii, shadow, motion) as CSS vars + semantic type classes. Baseline + refreshed.
- **`SKILL.md`** — Agent-Skill front-matter so this folder can be used directly in Claude Code.
- **`assets/`** — extracted brand assets (icon reference; the app ships none, so this documents the emoji/Material set).
- **`preview/`** — small HTML specimen cards that populate the **Design System** tab (colors, type, spacing, components, states).
- **`ui_kits/app/`** — the mobile app UI kit: interactive, high-fidelity React recreation of the refreshed dashboard + auth + sheets. See its own `README.md`. Open `ui_kits/app/index.html` to use it.

*No slide template was provided, so no `slides/` directory was created.*
