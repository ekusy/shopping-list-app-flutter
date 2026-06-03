# assets/

The Kaimono app **ships no logo, illustration, photographic, SVG, or PNG icon
assets** in its repository (`ekusy/shopping-list-app-flutter`). The brand is
expressed entirely through color, type, layout, and an **emoji-based icon
language**. There is therefore nothing to copy here — this file documents the
icon system so designs stay consistent.

## Icon system

1. **Emoji (primary action language)** — defined in
   `lib/core/utils/item_icons.dart`:

   | Emoji | Token | Meaning |
   |---|---|---|
   | 🙋 | `volunteer` / `volunteerBadge` | "I'll buy it" volunteer |
   | ✕ | `cancelVolunteer` | cancel your volunteering |
   | 🔄 | `takeOver` | take over from another buyer |
   | ✅ | `bought` | mark purchased |
   | ↩ | `returnToBuy` | return to unbought |
   | 🗑️ | `delete` | delete item |
   | ⏳ | `pendingSync` | offline write pending |
   | 👤 | `othersBadge` | another person is buying |
   | 📷 | (form) | add photo |

   > 🛒 is intentionally NOT used for volunteering (reads as "purchased"); 🙋
   > (raised hand = "I'll take it on") is the deliberate choice.

2. **Unicode glyphs (structure):** `▼ ▲` caret/collapse, `☐ ☑` selection,
   `＋` detail-add prefix.

3. **Material chrome icons:** `Icons.menu` (☰), `Icons.close`. In HTML designs,
   use the **Material Symbols Rounded** webfont via CDN as the closest stand-in:

   ```html
   <link rel="stylesheet"
     href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@24,400,0,0" />
   <!-- usage -->
   <span class="material-symbols-rounded">menu</span>
   ```

   ⚠️ **Substitution flagged** — Material Symbols Rounded stands in for Flutter's
   bundled Material Icons. Swap to the Outlined/Sharp variant if preferred.
