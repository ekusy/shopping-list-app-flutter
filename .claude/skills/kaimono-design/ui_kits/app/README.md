# UI Kit — Kaimono Mobile App

A high-fidelity, interactive recreation of the **Kaimono shopping-list app**
(Flutter / Material 3), rebuilt in React for prototyping. It reproduces the real
screens and copy from `ekusy/shopping-list-app-flutter` and applies the
**refreshed "warm but clean" direction** from the design system (see the root
`README.md` and `colors_and_type.css`).

> This is a cosmetic recreation for design exploration — not production code.
> Data is in-memory (`data.js`); Firebase/Riverpod/go_router are not wired.

## Run it

Open `index.html`. It loads React 18 + Babel from CDN, the tokens from
`../../colors_and_type.css`, and the component scripts. Everything is rendered
inside a phone bezel (390×800).

## Flow

1. **Login** → tap ログイン (or switch to サインアップ).
2. **Dashboard** — the shared list, grouped by tag, max-width 800 / mobile-first.

## What's reproduced (and what the refresh changes)

| Element | Source behaviour | Refresh applied here |
|---|---|---|
| **App bar** | group name ▼ · タグ · ☰ | indigo group name + caret, tonal タグ pill, 44px menu |
| **Filter bar** | horizontal tag chips, OR filter | adds a **color dot** per tag so chips ≠ section headers |
| **Tag section** | bold name + count + collapse + delete | colored **square dot** + count; clearly distinct from the indigo group title |
| **Item card** | all actions always visible (dense) | **clean resting card** (check + name + one 「買うよ」pill); **swipe** reveals 編集/削除; **long-press** enters multi-select |
| **Buyer state** | 🙋 / 👤 badges + buttons | apricot wash + filled 「私が買います」badge (tap ✕ to cancel); others show 👤name + 代わりに |
| **Bought** | 0.6 opacity, strikethrough | green wash + green check; swipe to 戻す |
| **Bottom bar** | quick-add field **+** stacked 「＋ 詳細追加」button | quick-add field **+ FAB** — one row, far less vertical space |
| **Add/Edit** | bottom sheet (name/tag/photo/note) | same fields, rounded-20 sheet, scrim |
| **Drawer** | language · settings · profile · logout | plain ListTiles (faithful) |
| **Group switcher** | dialog, 使用中 badge, create/join | modal card |
| **Bulk bar** | count + change-tag + cancel | appears in selection mode |
| **Toasts** | success/info/error snackbars | pill toasts, green on success |

These four points directly answer the brief: **(2)** card density → swipe +
long-press; **(3)** bottom area → FAB; **(4)** warmer palette → apricot/green
accents; **(5)** tag-filter vs section → color dots + distinct header styling.

## Files

| File | Contents |
|---|---|
| `index.html` | Shell: fonts, the full stylesheet (all visual styling lives here as classes), script loads |
| `data.js` | Sample items / tags / groups / members (Japanese copy) |
| `ui.jsx` | `PhoneShell`, `AppBar`, `FilterBar`, `SectionHeader`, `BulkBar`, `BottomBar`, `Drawer`, `GroupSwitcher`, `Toast`, `StatusIcons` |
| `ItemCard.jsx` | Swipeable + long-pressable item card (the centerpiece) |
| `screens.jsx` | `LoginScreen`, `ShoppingList` (grouping), `AddSheet` |
| `app.jsx` | `App` root — state + all handlers + overlay wiring |

## Iconography

Matches the app exactly: **emoji** for actions (🙋 ✅ ✏️ 🗑️ ↩ 📷 👤) and
**unicode** for chrome (▼ ▲ ☰ ✕ ＋ ✓). Status-bar glyphs are tiny inline SVGs.
No icon-font ligatures — renders identically in every browser and export.

## Gestures

- **Tap check** → mark purchased (green).
- **Tap 買うよ** → volunteer; **tap your badge ✕** → cancel.
- **Swipe a card left** → reveal 編集 / 削除 (or 戻す / 削除 when bought).
- **Long-press a card** → enter multi-select; a bulk bar lets you re-tag; tap
  more cards to add; キャンセル exits.
- **FAB ＋** → detail add sheet. **Group name ▼** → switcher. **☰** → drawer.
