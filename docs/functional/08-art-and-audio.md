# Art & audio

> Visual and sound direction, and rights constraints on assets.
> Status: Draft · Last updated: 2026-10-09

## Art direction

Tools and export specs: [tools/art-tools.md](../tools/art-tools.md).

> **Open question:** Choose one direction and produce a mood board.

Candidate directions:
1. **Romantic painting** — inspired by Arthur Rackham's *Ring* illustrations (1910–11) and 19th-century German Romanticism. Muted palette, gold highlights.
2. **Stylised stained glass / woodcut** — strong outlines, readable at small size, cheaper to produce consistently.
3. **Art nouveau** — ornate card frames, flat colour fills.

Readability at phone size is the priority: one clear subject per illustration, high contrast silhouettes.

### Faction colour & symbol (draft)

| Faction | Colour | Symbol |
|---------|--------|--------|
| Gods | Blue / silver | Spear |
| Nibelungs | Dark gold / black | Anvil |
| Giants | Brown / stone | Club |
| Wälsungs & Heroes | Red | Sword |
| Valkyries | White / steel | Winged helm |
| Gibichungs | Purple | Goblet |
| Neutral | Grey-green | Rhine wave |

### Logo

Game logo for *Nothung: The Ring Card Game* built around the sword Nothung (e.g. the sword, broken or reforged, forming or crossing the title), so the name reads at a glance. Must also work as the adaptive Android app icon (sword alone, without text).

### Card frames

Frame varies by type (unit / spell / artifact) and rarity (gem colour). The Ring and cursed cards get a distinct dark-gold frame.

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
