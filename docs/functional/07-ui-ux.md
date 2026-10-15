# UI / UX

> Screens, navigation and interaction design for an Android phone.
> Status: Draft · Last updated: 2026-10-15

## Platform constraints

- **Portrait** orientation, one-handed use where possible.
- Reference resolution 1080×1920; must adapt from 16:9 to 20:9+ aspect ratios and display cutouts (notches).
- Minimum touch target: 48 dp.
- Android back button must always do something sensible (go back / open pause menu).

> **Decision (2026-10-09):** Portrait orientation for the whole game, duel screen included.

## Screen flow

```mermaid
flowchart TD
    Splash --> Title
    Title --> MainMenu
    MainMenu --> Campaign
    MainMenu --> QuickMatch
    MainMenu --> Collection
    MainMenu --> Settings
    MainMenu -->|interrupted match| Duel
    Campaign --> ChapterMap --> StoryPanel --> DeckSelect
    ChapterMap --> Quest --> Results
    QuickMatch --> DeckSelect
    DeckSelect --> OpeningHand --> Duel
    Duel --> Pause
    Duel --> Results
    Results --> MainMenu
    Collection --> DeckBuilder
    Collection --> Forge
```

## Screens

| Screen | Key elements |
|--------|--------------|
| Main menu | Campaign, Quick match, Collection, Settings; Rhinegold counter; **Resume match** prompt (Resume / Abandon) when a match was interrupted ([persistence](../technical/07-persistence.md#resume-an-interrupted-match)) |
| Chapter map | Chapter nodes (duels and Quests), progress, rewards preview, Quest endings found / missing |
| Quest | Illustration (top), story text, 2–3 choice buttons (≥ 48 dp); back opens a pause menu (resume / quit Quest) |
| Deck select | Deck list, Leader portrait, validity indicator |
| Opening hand | Starting cards, tap to mark cards to replace, **Redraw** button, then confirm; flavour line "The Norns weave your fate…" |
| **Duel** | Turn counter + Götterdämmerung countdown (from turn 7), enemy Leader + Life (top), enemy board, own board, own hand (bottom fan), Energy counter, end-turn button, Leader ability button, graveyard/deck counters |
| Results | Win/lose, rewards, continue |
| Collection / Deck builder | Card grid, filters, deck list panel, mana curve |
| Settings | Audio volumes, language, animation speed, reset progress |

## Duel screen layout (portrait draft)

```
┌──────────────────────────────┐
│ [Enemy Leader ♥20]  deck 22  │
│ ▢ ▢ ▢ ▢ ▢ ▢   enemy board    │
│ ─────────── artifacts ────── │
│ ▢ ▢ ▢ ▢ ▢ ▢   your board     │
│ [Your Leader ♥20] [Ability]  │
│ Energy ●●●●○○      [END TURN]│
│   ╭──╮╭──╮╭──╮╭──╮╭──╮       │
│   hand (fanned, scrollable)  │
└──────────────────────────────┘
```

## Gestures

| Action | Gesture |
|--------|---------|
| Inspect card | Long press → zoomed card with full text and trait tooltips |
| Play card | Drag from hand onto board (or onto a target) |
| Attack | Drag from own unit to target; valid targets highlighted |
| Cancel | Release outside a valid target |
| Accessibility alternative | Tap card → tap target (no drag required) |

## Feedback

- Valid targets glow; invalid ones dim.
- Every rules event has an animation + sound (damage numbers, death, draw).
- AI turn is visible step by step; speed configurable (1×, 2×, instant).
- Log of the last actions accessible from the duel screen.

## Accessibility

- Text size option; colour-blind safe faction colours (don't rely on colour alone — use icons).
- No time pressure on the player's turn.
- Haptic feedback toggle.
