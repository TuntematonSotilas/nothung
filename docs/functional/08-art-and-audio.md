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
| **Gem** (top right) | Rarity | Common grey · Rare blue · Epic purple · Legendary gold |

Why faction rather than type: decks are one faction + Neutral, so colour tells at a glance which side a card belongs to (collection, deck builder, enemy board). With only 3 types, shape is enough to tell them apart.

**Thematic exception:** the Ring and **Cursed** cards use a **dark-gold** frame whatever their faction. Dark gold is reserved for them and used by no faction.

**Accessibility:** every faction also has an **icon**, shown on the frame next to the type line, so cards can be identified without relying on colour (colour-blind players).

### Faction palette (draft)

| Faction | Colour | Symbol |
|---------|--------|--------|
| Gods | Blue / silver | Spear |
| Nibelungs | Purple / charcoal (Tarnhelm sorcery, Nibelheim) | Anvil |
| Wälsungs & Heroes | Red | Sword |
| Valkyries | White / steel | Winged helm |
| Neutral | Grey / parchment | Rhine wave |
| *Reserved — Giants (expansion)* | *Brown / stone* | *Club* |
| *Reserved — Gibichungs (expansion)* | *Deep green* | *Goblet* |

*Nibelungs moved from "dark gold / black" to purple so they don't clash with the dark-gold Ring / Cursed frame. Exact hex values to be set with the art direction (mood board).*

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
