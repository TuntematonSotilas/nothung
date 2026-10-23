# Art tools

> Recommended software and workflow for card artwork, icons and UI mockups. Direction: [functional/08-art-and-audio.md](../functional/08-art-and-audio.md).
> Status: Draft · Last updated: 2026-10-23

Prices and licences change — check them before buying.

## Key principle: artists draw illustrations, Godot assembles the card

A final card is **not** a single image. It is composed at runtime by the `CardView` scene ([technical/06-ui-implementation.md](../technical/06-ui-implementation.md)):

```
CardView = frame + gem drawn by Godot (shape by type, colour by faction, gem by rarity)
         + artwork + faction icon
         + text rendered by Godot (name, cost, rules, stats)
```

Why: the text must be translated into 4 languages and must reflect runtime stats (a buffed unit shows 5/6, not 3/4). So artists deliver:
- **Illustrations** without text (one per card),
- **Icons** for card types and traits (Energy, Life, faction icons… come from game-icons.net).

Frames are not drawn: the game draws them ([card frames](../functional/08-art-and-audio.md#card-frames)).

## Recommended tools

| Need | Recommended | Free alternative | Notes |
|------|-------------|------------------|-------|
| **Painting the illustrations** | **Krita** | — (Krita is free) | Open source, excellent brushes, PSD export. Best default choice |
| Painting (paid option) | Clip Studio Paint | Krita | Very good for line art + colouring |
| Painting on tablet | Procreate (iPad) | Krita on Android tablet | Cheap one-time purchase, natural feel |
| **Icons (vector)** | **Inkscape** | — (free) | SVG → exported to PNG at the needed sizes |
| Photo editing (all-in-one) | Affinity (by Canva) | GIMP | Affinity was relaunched as a free app in late 2025 — check its current licence terms |
| **UI mockups, screen flows** | **Figma** (free tier) | Penpot (open source) | Mock up the duel screen and the card layout before building in Godot |
| Paper prototype cards (playtest) | nanDECK (Windows, free) | Spreadsheet + mail merge | Generates printable cards from a CSV — useful before any art exists |

**Hardware:** a graphics tablet (Wacom, XP-Pen, Huion — entry models are fine) or an iPad with a stylus. Drawing with a mouse is not realistic for ~80 illustrations.

## Hand-drawn art-to-digital workflow

**Draw and paint by hand → import the original → use AI-assisted cleanup → review and export.**
The artist creates every character and illustration by hand, on paper or digitally. AI is a
post-processing assistant for preparing that authored work, not an image generator or co-artist.

### Draw and paint by hand

- Keep the silhouette and key features readable at phone size; check a small thumbnail before
  finishing the painting.
- For paper work, leave enough margin for portrait/card crops and capture the whole painting
  with even lighting and minimal perspective distortion.
- Preserve the original scan, photo, or layered digital file unchanged as the master.

### Import and AI-assisted cleanup

1. Import a high-resolution scan, photo, or flattened export into the image-editing workflow.
2. Use AI-assisted cleanup only to remove paper specks, pencil marks, capture artefacts, and
   unwanted background; adjust crop, perspective, or colour balance where needed.
3. Do not generate, extend, or repaint the subject. Keep the hand-painted strokes, shapes, and
   colour choices authored by the artist.
4. Compare the cleaned result with the untouched master at full size and at phone size. Correct
   any cleanup that removes or changes painted detail; the artist approves the final image.
5. Export the approved crop as PNG for Godot and retain both the untouched master and the approved
   cleaned export.

**Consistency across the set:** use a Krita template and a fixed palette: muted tones plus the
[faction colours](../functional/08-art-and-audio.md#faction-palette-draft) as accents.

## Public-domain reference & material

- **Arthur Rackham's *Ring* illustrations (1910–1911)** are in the public domain (Rackham died in 1939). They are an ideal reference for the "Romantic painting" direction, and can even serve as **placeholder art** during prototyping.
- 19th-century stage designs and paintings of the *Ring* (e.g. Hermann Hendrich, Ferdinand Leeke) — check each artist's death date (public domain = 70 years after death in the EU).
- In the EU, faithful photo reproductions of public-domain 2D artworks are not protected (EU Directive 2019/790, art. 14), but check the source site's terms.

## Artwork policy

**Decision (2026-10-09, updated 2026-10-18): all final subject artwork is drawn and painted by
the project author; AI-assisted cleanup is allowed as described in the workflow above.**

- No AI-generated or AI-extended subject artwork in the game.
- AI may clean the imported hand-made image but must not invent or repaint its subject; the artist
  reviews and approves every final export.
- Public-domain works (Rackham, etc.) are used only as **reference** and **temporary placeholders**
  during prototyping; every placeholder is replaced before release.
- **Card frames** are not artwork: Godot draws them (shapes and colours, no image) — [card frames](../functional/08-art-and-audio.md#card-frames).
- **Exception — standard UI icons and faction icons** (Life, Energy, pause…, faction symbols): taken from game-icons.net (CC BY 3.0, see `CREDITS.md`). Card-type icons stay hand-drawn ([icons](../functional/08-art-and-audio.md#icons)).

## Export specs for Godot

| Asset | Format | Size (draft) |
|-------|--------|--------------|
| Card illustration | PNG (source kept as `.kra` / `.psd` outside `res://`) | 1024 × 768, displayed smaller |
| Leader portrait | PNG (master kept outside `res://`) | Portrait crop, displayed with aspect ratio preserved |
| Icons | SVG (Godot imports SVG) or PNG @2x | 64–128 px |

- Source files (`.kra`, `.psd`, `.svg` masters) live in a separate folder or repository (large files → consider Git LFS).
- Godot compresses textures on import (ETC2/ASTC for Android).
