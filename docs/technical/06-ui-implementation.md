# UI implementation

> How screens and interactions from [functional/07-ui-ux.md](../functional/07-ui-ux.md) are built in Godot.
> Status: In progress · Last updated: 2026-10-22

## Display settings (`project.godot`)

| Setting | Value |
|---------|-------|
| `display/window/size/viewport_width × height` | 1080 × 1920 |
| `display/window/handheld/orientation` | Portrait |
| `display/window/stretch/mode` | `canvas_items` |
| `display/window/stretch/aspect` | `expand` (layouts use anchors/containers to absorb extra height) |
| Safe area | Read `DisplayServer.get_display_safe_area()` and pad the root UI for notches |

## Scene composition

- One scene per screen under `scenes/screens/`, swapped by the `SceneRouter` autoload (with a fade transition). The splash now starts a Gods-vs-Nibelungs duel.
- Reusable components under `scenes/components/`; the first `CardView` and portrait duel screen are implemented.
- UI built with `Control` nodes and containers; a shared `Theme` resource in `ui/theme/` for fonts, colours, styleboxes.

## Theme

- `ui/theme/main_theme.tres` is the project theme (`gui/theme/custom` in `project.godot`): every `Control` inherits it, popups and menus included.
- `ui/theme/palette.gd` (`class_name Palette`) holds the same colours as constants for scripts (`Palette.LIFE`, `Palette.ACCENT`…). Source of truth: [UI palette](../functional/08-art-and-audio.md#ui-palette). A `.tres` can't reference script constants, so a colour change must be made in both files.
- Variations instead of per-node overrides: `LabelAccent`, `LabelMuted`, `ButtonPrimary` (set with `theme_type_variation`). Avoid `theme_override_colors` in scenes.

## Splash

- `scenes/screens/splash.tscn` is the project's startup scene.
- The default Godot boot splash is disabled: `application/boot_splash/show_image=false` in `project.godot`, and `splash_screen/disable_godot_boot_splash=true` in the Android export preset. Both boot backgrounds use the clear colour (`#0E0F12`), so the launch goes straight from a dark screen to the Nothung splash. On Android 12+, the system still shows its own launch screen (app icon on that background) for a moment; it can't be removed.
- Displays the game name and subtitle with a vector sword emblem; it uses no external assets.
- The **Start Match** button opens the playable duel screen.

## CardView

- `scenes/components/card_view.gd` displays translated name/rules, Energy cost and runtime/unit stats.
- **Frame drawn in code** ([card frames](../functional/08-art-and-audio.md#card-frames)): `_card_style()` builds a `StyleBoxFlat` whose shape depends on the type (`SHAPE_RADIUS`; artifacts use `corner_detail = 1` for cut corners) and whose border takes the faction frame colour from `CardPalette` (`ui/theme/card_palette.gd`: faction frame / trim, card background, gems, Ring) on the shared dark background. Children add the name banner (`NameBanner`, faction colour), the cost / attack / health holders (bare, no pill), the gem (`GemShape`, a panel turned 45°) and the relic ribbon. Sizes follow the card's size (`_face_k`), so hand, board and zoom cards share one layout.
- Highlights are a `shadow` glow on the style; neither the card nor its face clip, so the glow and the full-width name banner can draw outside the face (the rules text clips itself).
- The duel reconstructs hand/board/Leader/Energy/Life views from `Match` state after authoritative `GameEvent`s; views never mutate the rules engine.
- Exhausted and ready units have distinct visual states. Dragging, zoom and pooling are not implemented yet.

## Input

- The current interaction uses touch-friendly button targets: tap a card, then tap a legal unit/Leader target; tap an attacking unit, then its target. End Turn and Leader ability have dedicated buttons.
- The opening Redraw overlay lets the player select any subset of their hand and confirm it.
- Drag-and-drop targeting arrows and long-press zoom remain future work.
- Android back button: `NOTIFICATION_WM_GO_BACK_REQUEST` handled by `SceneRouter`: back to the previous screen (`SceneRouter.go_to()` keeps a history), or quit when there is none. `application/config/quit_on_go_back=false` so Godot does not quit on its own.

## Duel and AI

- `scenes/screens/duel.tscn` uses portrait containers for both boards, artifacts, Leaders, Energy, deck/graveyard counts, battle log and the scrollable hand.
- The first match uses the generated Gods and Nibelungs starter decks. Redraw, action validation, turn updates, match results and rematches are wired to `Match`.
- `ai/easy_ai.gd` picks only from serialized legal actions on a `Thread`; the main thread alone applies the returned action.
- A headless smoke test loads and starts the duel scene. The Android device play-through is still required before this milestone is complete.

## Animation pipeline

```mermaid
sequenceDiagram
    participant D as Duel screen
    participant M as Match (core)
    participant F as DuelFx (FxLayer)
    D->>M: apply(action)
    M-->>D: event_emitted × n (queued in _pending_events)
    D->>F: begin() — input blocked
    D->>F: spell / attack / damage / death ghosts over the old board
    D->>D: _refresh() — new state shown
    D->>F: draws fly to the new hand slots
    D->>F: end() — idle, input unlocked
```

- The rules are resolved at once; animations only catch up (`duel.gd` `_play_fx`). The board is rebuilt **once per action**, after the events that need the old positions (spell, attack, damage, death), and before the draws, which need the new hand slots.
- `scenes/components/duel_fx.gd` (`DuelFx`, on the `FxLayer` canvas layer, between the board and the modal layer) tweens **ghost** copies of cards; the duel hides the real view while its ghost plays. `CardView.shown_instance()` gives the stats as drawn, since the match has already changed them.
- While a sequence runs, `DuelFx` stops taps (`MOUSE_FILTER_STOP`) and `_apply_action` ignores drags; the AI waits for `idle` before its next step, so each AI action is seen.
- Speed from `Settings.animation_speed`: durations are divided by it (1×, 2×); `0` (instant) skips the animations and refreshes at once. UI integration tests run at instant speed; `tests/integration/test_duel_fx.gd` checks the animations.

## Localisation

- `localization/strings.csv` (keys + `en`, `de`, `es`, `fr` columns; `en` is the source language), imported as Godot translations (the generated `.translation` files are git-ignored and rebuilt on import). A test fails if any key lacks a language.
- Language: `Settings.language`; empty = the device language if supported, otherwise English.
- The brand texts (*Nothung*, *The Ring Card Game*) stay in English in every language.
- All visible text via `tr("KEY")`; card texts via keys built from the card ID.
- Rules text with numbers uses `tr(...).format({...})`.
- Test long-text languages (German, then French and Spanish) for card text overflow; card text uses auto-shrinking `Label`/`RichTextLabel`.

## Performance targets

- 60 fps during animations on the reference device.
- Texture atlases / compressed textures (ETC2/ASTC) for card art; art loaded at the size it is displayed.
