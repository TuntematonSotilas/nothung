# Art & audio

> Visual and sound direction, and rights constraints on assets.
> Status: Draft · Last updated: 2026-10-21

## Art direction

Tools and export specs: [tools/art-tools.md](../tools/art-tools.md).

> **Decision (2026-10-15):** **Romantic painting** — inspired by Arthur Rackham's *Ring* illustrations (1910–11) and 19th-century German Romanticism: ink line art, muted palette, gold highlights. Next step: a mood board, which also validates the [faction palette](#faction-palette-draft).

Directions considered and set aside: stylised stained glass / woodcut (strong outlines, cheap to produce) and Art nouveau (ornate frames, flat colours).

Readability at phone size is the priority: one clear subject per illustration, high contrast silhouettes.

### Card colour system

> **Decision (2026-10-13):** Card colour encodes the **faction**, not the type. Type is shown by the **frame shape**, rarity by the **gem**. Each visual cue carries one piece of information.

| Visual cue | Encodes | Values |
|------------|---------|--------|
| **Frame colour** | Faction | See faction palette below |
| **Frame shape** | Type | **Unit**: rectangular frame with Attack ⚔ and Health ♥ stones · **Spell**: rounded, parchment-like frame · **Artifact**: octagonal frame · **Relic**: octagonal frame + "Bearer" ribbon |
| **Gem** (top right) | Rarity | Common grey · Rare blue · Epic purple · Legendary gold (see [gem colours](#gem-colours)) |

Why faction rather than type: decks are one faction + Neutral, so colour tells at a glance which side a card belongs to (collection, deck builder, enemy board). With only 3 types, shape is enough to tell them apart.

**Thematic exception:** the Ring and **Cursed** cards use a **dark-gold** frame whatever their faction. Dark gold is reserved for them and used by no faction.

**Accessibility:** every faction also has an **icon**, shown on the frame next to the type line, so cards can be identified without relying on colour (colour-blind players).

### Faction palette (draft)

Muted, slightly desaturated tones to match the Romantic direction (aged pigments, not saturated UI colours). Each faction has a **frame** colour (main fill) and a **trim** colour (borders, ornaments, type line). Hues are spread around the colour wheel, and the two light frames (Valkyries, Neutral) are told apart by temperature (cool vs warm).

| Faction | Colour | Frame | Trim | Card text | Symbol |
|---------|--------|-------|------|-----------|--------|
| Gods | Blue / silver | `#2E4A7D` | `#B8C4D6` | Light | Spear |
| Nibelungs | Purple / charcoal (Tarnhelm sorcery, Nibelheim) | `#4E3366` | `#2B2930` | Light | Anvil |
| Wälsungs & Heroes | Red | `#8B2323` | `#B07D4F` (bronze) | Light | Sword |
| Valkyries | White / steel | `#DDE2E8` | `#6F7C8A` | Dark | Winged helm |
| Neutral | Grey / parchment | `#A39A86` | `#DCCFAE` | Dark | Rhine wave |
| **Ring / Cursed** (any faction) | Dark gold | `#7A5A14` | `#C9A33A` | Light | — |
| *Reserved — Giants (expansion)* | *Brown / stone* | *`#6B5A4C`* | *`#9C9286`* | *Light* | *Club* |
| *Reserved — Gibichungs (expansion)* | *Deep green* | *`#2D5641`* | *`#A8B59A`* | *Light* | *Goblet* |

Shared text colours: **Light** = `#F4EFE4` (warm off-white), **Dark** = `#1C1A17` (ink). Every frame meets a WCAG contrast ratio of at least **5.5:1** with its text colour (target ≥ 4.5:1).

*Nibelungs moved from "dark gold / black" to purple so they don't clash with the dark-gold Ring / Cursed frame. Values are a starting point: adjust them on the mood board, keeping the contrast target and the hue spacing.*

### Gem colours

| Rarity | Gem |
|--------|-----|
| Common | `#9A9A9A` |
| Rare | `#3A7BD5` |
| Epic | `#8E44AD` |
| Legendary | `#E0B33A` |

Gems are brighter than frames so they stand out as small jewels. Legendary gold is bright and saturated, unlike the dark-gold Ring / Cursed frame.

### UI palette

> **Decision (2026-10-16):** Dark UI built on the splash colours: near-black background, warm off-white text, **gold of Nothung** as the single accent. Implemented in `game/ui/theme/` ([06-ui-implementation](../technical/06-ui-implementation.md#theme)).

| Token | Hex | Use | Contrast on `bg` / `surface_raised` |
|-------|-----|-----|-------------------------------------|
| `bg` | `#0E0F12` | Screen background, boot splash | — |
| `surface` | `#181A20` | Panels, board, popup menus | — |
| `surface_raised` | `#22252D` | Buttons | — |
| `border` | `#343844` | Borders, separators | — |
| `text` | `#E8E0CC` | Main text | 14.6 / 11.6 |
| `text_muted` | `#A1A3A8` | Secondary text | 7.6 / 6.1 |
| `text_disabled` | `#7E8190` | Disabled elements only | 5.0 / 4.0 |
| `accent` | `#C7A863` | Primary buttons, selection, focus, emblem (hover `#D4B97A`, pressed `#B0914E`) | 8.4 / 6.7 |
| `ink` | `#1C1A17` | Text on `accent` | 7.6 on accent |
| `life` | `#E46A5E` | Life, damage, destructive actions | 6.0 / 4.8 |
| `energy` | `#5BA8CC` | Energy (Rhine blue) | 7.2 / 5.8 |
| `heal` | `#5FA873` | Healing, buffs, success | 6.7 / 5.4 |

- The UI gold is paler and duller than the Ring / Cursed frame gold and the Legendary gem: it is for the interface, never for a card frame.
- Life, Energy and heal are always paired with an icon or a number (colour-blind players).
- Menus, dropdowns and popups use the theme too (`surface` panel, `text`), never the engine defaults.

### App icon

> **Decision (2026-10-16):** **Nothung through the Ring** — a vertical sword whose blade passes through the Ring (behind at the top, in front at the bottom). It carries the whole title and stays readable at 48 px. Geometric vector drawing, original to the project. Files: `game/assets/app_icon/` ([10-build-and-release](../technical/10-build-and-release.md#export-presets)).

Android adaptive icon, built from the [logo](#logo) (sword alone, no text):

| Layer | Colour |
|-------|--------|
| Background | `bg` `#0E0F12` → `surface` `#181A20` (subtle vertical gradient) — same as the boot screen, so launch looks seamless |
| Foreground | Sword in `accent` gold `#C7A863`, highlights in `text` `#E8E0CC`; keep it inside the 66 dp safe zone (of 108 dp) |
| Monochrome (Android 13+ themed icons) | Sword silhouette, single colour — Android tints it |

### Logo

Game logo for *Nothung: The Ring Card Game* built around the sword Nothung (e.g. the sword, broken or reforged, forming or crossing the title), so the name reads at a glance. Must also work as the adaptive Android app icon (sword alone, without text).

### Card frames

Frames follow the [card colour system](#card-colour-system): 4 shapes (unit, spell, artifact, relic) × 5 faction colours + the dark-gold Ring / Cursed variant. Produced as separate layers so Godot assembles them at runtime ([tools/art-tools.md](../tools/art-tools.md)).

### Icons

> **Decision (2026-10-21):** **Standard UI icons** (Life, Energy, attack, deck, graveyard, hand, pause, end turn, undo, close…) come from the [game-icons.net](https://game-icons.net) library (CC BY 3.0, credited in [CREDITS.md](../../CREDITS.md)). **Faction and card-type icons are hand-drawn** by the author, like the rest of the artwork.

- Format: **SVG** rather than an icon font. Godot imports SVG as a crisp texture at any size and tints it in game; icon fonts need codepoints and rich-text labels.
- In-game icons are single-colour on a transparent background (white or black, any shade): the game tints them (`modulate`).
- Hand-drawn icons to deliver, in `game/ui/icons/`:
  - Factions: `faction_gods.svg` (spear), `faction_nibelungs.svg` (anvil), `faction_walsungs.svg` (sword), `faction_valkyries.svg` (winged helm), `faction_neutral.svg` (Rhine wave).
  - Card types: `type_unit.svg`, `type_spell.svg`, `type_artifact.svg`, `type_relic.svg`.
  - SVG (vectorised in Inkscape from a scanned drawing) or PNG **256 × 256**; one solid shape, no thin details: they are shown at 24–48 px.

### Decorated buttons

Buttons can get a painted frame instead of the flat theme colours:

- One PNG per state: `button_normal.png`, `button_pressed.png` (and optionally `button_primary.png` for gold buttons), in `game/ui/theme/`.
- **9-slice**: e.g. 192 × 96 px with a **32 px** decorated border on each side; the middle must be plain (it gets stretched). Ornaments only in the corners and edges.
- Keep the centre dark and calm enough for the text (`#E8E0CC` on normal, ink `#1C1A17` on primary).
- Wired as `StyleBoxTexture` in `main_theme.tres`, so every button changes at once.

### Duel backgrounds

> **Decision (2026-10-21):** Duel backgrounds are **visual** boards (Valhalla, Nibelheim, Rhine depths, Gibichung hall…). Bonuses or penalties tied to a place exist only as [campaign duel special rules](05-game-modes.md#campaign).

- File: `game/assets/art/boards/<board_id>.png`, **1080 × 1920** (portrait), shown dimmed behind the duel; `default.png` is used for quick matches.
- Composition: interest at the **top and bottom edges**; keep the two play areas (roughly the middle 60 % of the height) **calm and low in contrast**, since cards sit on them.
- Muted tones from the Romantic palette; no text.

## Audio

### Music

- Wagner's scores are public domain, **but recordings are not**: performances are protected by performers' and producers' rights. Use only:
  - our own arrangements of the public-domain scores (written as MIDI, then rendered to audio — see [audio tools](../tools/audio-tools.md)), or
  - recordings explicitly licensed for reuse (e.g. CC0 / public-domain recordings, to be verified individually).
- Use **leitmotifs** as short stingers: Rhinegold motif when earning Rhinegold, Valhalla motif for Gods, Ride motif for Valkyries, Sword motif for Nothung, curse motif when the Ring hurts its holder.
- Background loops per board / chapter.

### Sound effects

- Card draw, play, attack, damage, death, end turn, victory, defeat.
- Faction-specific play sounds (anvil hammering for Nibelungs, thunder for Donner…).

## Asset rights checklist

- [ ] All artwork hand-drawn for the project by the author — no AI-generated images, no public-domain placeholders left ([artwork policy](../tools/art-tools.md#artwork-policy)).
- [ ] Standard UI icons from game-icons.net credited in `CREDITS.md` (CC BY 3.0) — the only third-party images allowed ([icons](#icons)).
- [ ] Every audio file has a documented source + licence (keep a `CREDITS.md`).
- [ ] Fonts licensed for embedding in apps (e.g. SIL OFL).
- [ ] Libretto quotes: German original is public domain; translations must be public domain or our own.
