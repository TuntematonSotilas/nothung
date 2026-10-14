# Art & audio

> Visual and sound direction, and rights constraints on assets.
> Status: Draft · Last updated: 2026-10-13

## Art direction

Tools and export specs: [tools/art-tools.md](../tools/art-tools.md).

> **Open question:** Choose one direction and produce a mood board.

Candidate directions:
1. **Romantic painting** — inspired by Arthur Rackham's *Ring* illustrations (1910–11) and 19th-century German Romanticism. Muted palette, gold highlights.
2. **Stylised stained glass / woodcut** — strong outlines, readable at small size, cheaper to produce consistently.
3. **Art nouveau** — ornate card frames, flat colour fills.

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

### Logo

Game logo for *Nothung: The Ring Card Game* built around the sword Nothung (e.g. the sword, broken or reforged, forming or crossing the title), so the name reads at a glance. Must also work as the adaptive Android app icon (sword alone, without text).

### Card frames

Frames follow the [card colour system](#card-colour-system): 4 shapes (unit, spell, artifact, relic) × 5 faction colours + the dark-gold Ring / Cursed variant. Produced as separate layers so Godot assembles them at runtime ([tools/art-tools.md](../tools/art-tools.md)).

## Audio

### Music

- Wagner's scores are public domain, **but recordings are not**: performances are protected by performers' and producers' rights. Use only:
  - our own arrangements of the public-domain scores (written as MIDI, then rendered to audio — see [audio tools](../tools/audio-tools.md)), or
  - recordings explicitly licensed for reuse (e.g. CC0 / public-domain recordings, to be verified individually).
- Use **leitmotifs** as short stingers: Rhinegold motif when gaining Gold, Valhalla motif for Gods, Ride motif for Valkyries, Sword motif for Nothung, curse motif when the Ring hurts its holder.
- Background loops per board / chapter.

### Sound effects

- Card draw, play, attack, damage, death, end turn, victory, defeat.
- Faction-specific play sounds (anvil hammering for Nibelungs, thunder for Donner…).

## Asset rights checklist

- [ ] All artwork hand-drawn for the project by the author — no AI-generated images, no public-domain placeholders left ([artwork policy](../tools/art-tools.md#artwork-policy)).
- [ ] Every audio file has a documented source + licence (keep a `CREDITS.md`).
- [ ] Fonts licensed for embedding in apps (e.g. SIL OFL).
- [ ] Libretto quotes: German original is public domain; translations must be public domain or our own.
