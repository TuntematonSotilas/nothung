# Persistence

> What is saved on the device, in which format, and how saves evolve across versions.
> Status: Draft · Last updated: 2026-10-28

## What is saved

| Data | File | Written when |
|------|------|--------------|
| Player profile: collection, Rhinegold, unlocks, achievements | `user://profile.json` | After each reward / change |
| Decks | `user://profile.json` (section `decks`) | On deck save |
| Campaign progress | `user://profile.json` (section `campaign`) | After each campaign duel or Quest ending |
| Settings: volumes (`audio`), language (`display`), last Quick match choices (`quick_match`) | `user://settings.cfg` (`ConfigFile`) | On change (every setter of the Settings screen) |
| Match in progress | `user://current_match.json` (seed + decks + action list) | After each action, and when the app goes to background |

On Android `user://` maps to the app's private internal storage.

## Format

**JSON** (via `JSON.stringify` / `JSON.parse_string`) rather than saving `Resource`s:
- `.tres` loading can execute embedded scripts → unsafe if a save file is tampered with.
- JSON is human-readable for debugging and easy to migrate.

```json
{
  "version": 2,
  "rhinegold": 320,
  "collection": { "alberich_lord": 1, "fafner": 1, "loge_fire": 3 },
  "decks": [
    { "name": "Hoard of Nibelheim", "leader": "alberich", "cards": ["alberich_lord", "..."] }
  ],
  "campaign": { "rheingold": { "completed": true, "duels_won": ["rg_01", "rg_02"], "quest_endings": { "rg_q1": ["hoard_found"] } } },
  "achievements": ["renunciation_of_love"]
}
```

## Safety

- Atomic writes: write to `profile.json.tmp`, then rename over `profile.json`; keep `profile.json.bak`.
- On load error: fall back to `.bak`, then to a fresh profile (and log it).
- Unknown card IDs in a save (card removed) are converted to Rhinegold instead of crashing.

## Versioning & migration

- `version` field at the root. `SaveManager` runs migrations `v1 → v2 → …` sequentially on load.
- The `v1 → v2` migration renames the progression balance from `hoard` to `rhinegold` without changing its value.
- Every change to the save schema requires a migration function + a unit test with a sample old save.

## Resume an interrupted match

Because the engine is deterministic, a match is saved as **seed + decks + list of actions** and replayed on resume. This also serves as the format for bug reports.

> **Decision (2026-10-15):** Resume is **in v1.0** (replaces the 2026-10-09 decision that postponed it). On a phone, a call, a notification or Android killing the app in background must not cost the player their match.

### What is saved

```json
{
  "version": 1,
  "content_hash": "3f9a…",
  "mode": "campaign",
  "campaign_duel": "rg_03",
  "difficulty": "normal",
  "seed": 184467,
  "decks": [
    { "leader": "wotan", "cards": ["wotan_spear", "..."] },
    { "leader": "alberich", "cards": ["alberich_lord", "..."] }
  ],
  "actions": [ { "type": "redraw", "player": 0, "cards": [3, 7] }, { "type": "play_card", "player": 0, "uid": 12 } ]
}
```

- **Decks are snapshots** (card IDs), not references to the player's deck slots: editing a deck later can't change a saved match.
- **AI moves are recorded as actions** like the player's. Replay never re-runs the AI search, so it doesn't depend on thread timing or on AI tuning changes.
- `content_hash` is a hash of the card data at match start. Card stats can change in an update; replaying old actions on new data could diverge.

### When it is written

- After each action applied by the `Match` (atomic write, same as the profile).
- On `NOTIFICATION_APPLICATION_PAUSED` (app sent to background) and `NOTIFICATION_WM_CLOSE_REQUEST`, in case an action was applied but not yet flushed.
- **Deleted** when the match ends (win, loss or the player quits from the pause menu).

### Resume flow

1. At launch, `SaveManager` finds `current_match.json` → the main menu shows a **Resume match** prompt (Resume / Abandon).
2. **Resume:** rebuild the `Match` from seed + decks, re-apply every action **without animations**, then open the duel screen on the resulting state. If the AI's turn was interrupted, the AI simply starts thinking again.
3. **Abandon:** delete the file. The match counts neither as a win nor a loss (no reward, no penalty).
4. **Cannot resume** (`content_hash` differs after an update, unknown card ID, an action is rejected as illegal during replay): delete the file, show a short message ("This match can't be resumed after the update"), and keep a copy as `current_match.failed.json` for bug reports.

An unfinished **Quest** is lighter: the profile stores the current Quest ID and step (`campaign.<chapter>.quest_in_progress`), and the Quest restarts at that step.

## Backup

Android Auto Backup can back up `user://` to the user's Google account — enable it in the export settings and document it in the privacy policy.
