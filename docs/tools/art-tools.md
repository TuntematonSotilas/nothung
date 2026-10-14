# Art tools

> Recommended software and workflow for card artwork, frames, icons and UI mockups. Direction: [functional/08-art-and-audio.md](../functional/08-art-and-audio.md).
> Status: Draft · Last updated: 2026-10-14

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

## Paper-to-digital workflow

Recommended pipeline for hand-drawn illustrations: **ink on paper → scan → clean and colour in Krita**.

### Drawing on paper

| Setting | Value | Why |
|---------|-------|-----|
| Drawing area | **20 × 15 cm** (4:3) on A4 | Same ratio as the 1024 × 768 export; ~4–5× the final size |
| Safe margin | ~1 cm inside the area, no key elements | The card frame may crop the edges; room to adjust framing |
| Paper | Smooth Bristol / 180–250 g drawing paper | Ink doesn't bleed |
| Sketch | Non-photo **blue pencil** | Removed after scanning, no erasing needed |
| Ink | Fineliner **0.5–0.8 mm** for outlines, 0.3 mm minimum | The art is shown ~300–400 px wide on a phone (~12× reduction): thin lines disappear |

**Readability check:** look at the drawing at thumbnail size (~4 cm wide) before finishing it. If the silhouette doesn't read, colour won't fix it.

### Scanning

- **Flatbed scanner** (an entry model such as Canon LiDE is enough) rather than a phone photo: even lighting, no distortion. Free software: NAPS2 or Windows Scan.
- **600 dpi, colour** (keeps the blue pencil separable), saved as **PNG or TIFF — never JPEG**. Result ≈ 4700 × 3500 px; this is the master file.
- Phone apps (Microsoft Lens, Adobe Scan) are fine for tests only — quality is inconsistent across a full set.

### Cleaning and colouring in Krita

1. **Clean:** desaturate, or keep only the red channel (makes the blue pencil vanish), then *Filter → Adjust → Levels* for pure white and deep black.
2. **Isolate line art:** *Filter → Colors → Color to Alpha* on white, or set the line layer to **Multiply**. The lines stay on a transparent layer above the colours.
3. **Flats:** the **Colorize Mask** tool fills the closed areas automatically — a big time saver over ~80 cards.
4. **Shading and light** on layers between the flats and the line art.
5. **Export:** keep the `.kra` as source, export PNG at 1024 × 768 ([export specs](#export-specs-for-godot)).

**Consistency across the set:** use a Krita **template** (canvas at size, safe-margin guide, named layers) and a fixed **palette**: muted tones plus the [faction colours](../functional/08-art-and-audio.md#faction-palette-draft) as accents.

### Alternative: colour on paper

Ink + watercolour washes, as Rackham did — a perfect fit for the "Romantic painting" direction. Downsides: no undo, colour scan needs colour correction, harder to keep ~80 cards consistent. **To decide:** test both workflows on 2–3 cards before committing.

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
