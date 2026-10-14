# Persistence

> What is saved on the device, in which format, and how saves evolve across versions.
> Status: Draft · Last updated: 2026-10-14

## What is saved

| Data | File | Written when |
|------|------|--------------|
| Player profile: collection, Rhinegold, unlocks, achievements | `user://profile.json` | After each reward / change |
| Decks | `user://profile.json` (section `decks`) | On deck save |
| Campaign progress | `user://profile.json` (section `campaign`) | After each campaign duel or Quest ending |
| Settings | `user://settings.cfg` (`ConfigFile`) | On change |
| Match in progress (post-launch) | `user://current_match.json` (seed + action list) | After each action |

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

> **Decision (2026-10-09):** Resume is **post-launch**. In v1.0 an interrupted match is lost (counted neither as a win nor a loss). The deterministic engine keeps the door open: the replay format above is still used for bug reports.

## Backup

Android Auto Backup can back up `user://` to the user's Google account — enable it in the export settings and document it in the privacy policy.
