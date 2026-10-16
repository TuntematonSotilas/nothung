# UI implementation

> How screens and interactions from [functional/07-ui-ux.md](../functional/07-ui-ux.md) are built in Godot.
> Status: Draft · Last updated: 2026-10-09

## Display settings (`project.godot`)

| Setting | Value |
|---------|-------|
| `display/window/size/viewport_width × height` | 1080 × 1920 |
| `display/window/handheld/orientation` | Portrait |
| `display/window/stretch/mode` | `canvas_items` |
| `display/window/stretch/aspect` | `expand` (layouts use anchors/containers to absorb extra height) |
| Safe area | Read `DisplayServer.get_display_safe_area()` and pad the root UI for notches |

## Scene composition

- One scene per screen under `scenes/screens/`, swapped by the `SceneRouter` autoload (with a fade transition).
- Reusable components under `scenes/components/`: `CardView`, `HandView`, `BoardView`, `LeaderView`, `EnergyBar`, `CardZoomPopup`.
- UI built with `Control` nodes and containers; a shared `Theme` resource in `ui/theme/` for fonts, colours, styleboxes.

## Splash

- `scenes/screens/splash.tscn` is the project's startup scene.
- The default Godot boot splash is disabled: `application/boot_splash/show_image=false` in `project.godot`, and `splash_screen/disable_godot_boot_splash=true` in the Android export preset. Both boot backgrounds use the clear colour (`#0E0F12`), so the launch goes straight from a dark screen to the Nothung splash. On Android 12+, the system still shows its own launch screen (app icon on that background) for a moment; it can't be removed.
- Displays the game name and subtitle with a vector sword emblem; it uses no external assets.
- It remains on screen until the Title screen and scene routing are implemented.

## CardView

- Displays a `CardInstance` (runtime stats) or a `CardData` (collection).
- Updates only from events/bindings; never mutates game state.
- States: in hand, on board, zoomed, dragging, targetable, exhausted.
- Pooled to avoid re-instancing during a match.

## Input

- Touch handled via `_gui_input` on `CardView` / board slots, using `InputEventScreenTouch` and `InputEventScreenDrag` (with *emulate touch from mouse* enabled for desktop testing).
- Drag-and-drop: custom implementation (more control than `_get_drag_data`) that draws a targeting arrow and highlights legal targets from `Match.get_legal_actions()`.
- Tap-tap alternative mode for accessibility.
- Long press (≥ 400 ms) → `CardZoomPopup`.
- Android back button: `NOTIFICATION_WM_GO_BACK_REQUEST` handled by `SceneRouter`.

## Animation pipeline

```mermaid
sequenceDiagram
    participant M as Match (core)
    participant A as EventAnimator
    participant V as Views
    M->>A: event_emitted(DamageDealt)
    A->>A: enqueue
    A->>V: play damage tween
    V-->>A: finished
    A->>A: next event…
    A-->>V: queue empty → unlock input
```

- `EventAnimator` serialises `GameEvent`s into `Tween`s; game logic is already resolved, animations only catch up.
- Animation speed multiplier from `Settings` (1×, 2×, instant).

## Localisation

- `localization/strings.csv` (keys + `en`, `de`, `es`, `fr` columns; `en` is the source language), imported as Godot translations.
- All visible text via `tr("KEY")`; card texts via keys built from the card ID.
- Rules text with numbers uses `tr(...).format({...})`.
- Test long-text languages (German, then French and Spanish) for card text overflow; card text uses auto-shrinking `Label`/`RichTextLabel`.

## Performance targets

- 60 fps during animations on the reference device.
- Texture atlases / compressed textures (ETC2/ASTC) for card art; art loaded at the size it is displayed.
