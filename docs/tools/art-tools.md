# Art tools

> Recommended software and workflow for card artwork, frames, icons and UI mockups. Direction: [functional/08-art-and-audio.md](../functional/08-art-and-audio.md).
> Status: Draft · Last updated: 2026-10-12

Prices and licences change — check them before buying.

## Key principle: artists draw illustrations, Godot assembles the card

A final card is **not** a single image. It is composed at runtime by the `CardView` scene ([technical/06-ui-implementation.md](../technical/06-ui-implementation.md)):

```
CardView = frame (by type / rarity) + artwork + faction icon + gem
         + text rendered by Godot (name, cost, rules, stats)
```

Why: the text must be translated into 4 languages and must reflect runtime stats (a buffed unit shows 5/6, not 3/4). So artists deliver:
- **Illustrations** without text (one per card),
- **Frame pieces** (per type and rarity) as separate layers,
- **Icons** (factions, keywords, Gold, Life).

## Recommended tools

| Need | Recommended | Free alternative | Notes |
|------|-------------|------------------|-------|
| **Painting the illustrations** | **Krita** | — (Krita is free) | Open source, excellent brushes, PSD export. Best default choice |
| Painting (paid option) | Clip Studio Paint | Krita | Very good for line art + colouring |
| Painting on tablet | Procreate (iPad) | Krita on Android tablet | Cheap one-time purchase, natural feel |
| **Card frames, icons (vector)** | **Inkscape** | — (free) | SVG → exported to PNG at the needed sizes |
| Frames / photo editing (all-in-one) | Affinity (by Canva) | GIMP | Affinity was relaunched as a free app in late 2025 — check its current licence terms |
| **UI mockups, screen flows** | **Figma** (free tier) | Penpot (open source) | Mock up the duel screen and the card layout before building in Godot |
| Paper prototype cards (playtest) | nanDECK (Windows, free) | Spreadsheet + mail merge | Generates printable cards from a CSV — useful before any art exists |

**Hardware:** a graphics tablet (Wacom, XP-Pen, Huion — entry models are fine) or an iPad with a stylus. Drawing with a mouse is not realistic for ~80 illustrations.

## Public-domain reference & material

- **Arthur Rackham's *Ring* illustrations (1910–1911)** are in the public domain (Rackham died in 1939). They are an ideal reference for the "Romantic painting" direction, and can even serve as **placeholder art** during prototyping.
- 19th-century stage designs and paintings of the *Ring* (e.g. Hermann Hendrich, Ferdinand Leeke) — check each artist's death date (public domain = 70 years after death in the EU).
- In the EU, faithful photo reproductions of public-domain 2D artworks are not protected (EU Directive 2019/790, art. 14), but check the source site's terms.

## Artwork policy

**Decision (2026-10-09): all final artwork is hand-drawn by the project author.**

- No AI-generated images in the game.
- Public-domain works (Rackham, etc.) are used only as **reference** and **temporary placeholders** during prototyping; every placeholder is replaced before release.
- Benefit: the author holds full copyright on the art, and no store AI-content disclosure is needed.

## Export specs for Godot

| Asset | Format | Size (draft) |
|-------|--------|--------------|
| Card illustration | PNG (source kept as `.kra` / `.psd` outside `res://`) | 1024 × 768, displayed smaller |
| Frame pieces | PNG with transparency, 9-slice-friendly where possible | Per reference resolution 1080×1920 |
| Icons | SVG (Godot imports SVG) or PNG @2x | 64–128 px |

- Source files (`.kra`, `.psd`, `.svg` masters) live in a separate folder or repository (large files → consider Git LFS).
- Godot compresses textures on import (ETC2/ASTC for Android).
