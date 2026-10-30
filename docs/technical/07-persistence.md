# Persistence

> What is saved on the device, in which format, and how saves evolve across versions.
> Status: Draft · Last updated: 2026-10-30

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
  "version": 3,
  "rhinegold": 320,
  "collection": { "loge": 2, "fafner": 1, "wotans_spear": 1 },
  "leaders": ["wotan", "alberich", "siegfried", "brunnhilde"],
  "decks": [
    { "name": "Hoard of Nibelheim", "leader": "alberich", "cards": ["alberich_lord", "..."] }
  ],
  "campaign": { "rheingold": { "completed": true, "duels_won": ["rg_01", "rg_02"], "quest_endings": { "rg_q1": ["hoard_found"] } } },
  "achievements": ["renunciation_of_love"],
  "starter_collection_granted": true
}
```

## Safety

- Atomic writes: write to `profile.json.tmp`, then rename over `profile.json`; keep `profile.json.bak`.
- On load error: fall back to `.bak`, then to a fresh profile (and log it). After a restore from `.bak`, the next save **deletes** the unreadable `profile.json` instead of rotating it into `.bak`, so the good backup is not lost.
- A missing or wrongly typed key (hand-edited or damaged save) gets its default value. JSON reads numbers back as floats: `rhinegold` and the collection counts are turned back into ints on load.
- Unknown card IDs in a save (card removed) are converted to Rhinegold instead of crashing: each owned copy is refunded at the Common crafting price (`SaveManager.REMOVED_CARD_VALUE` = 40; the rarity of a removed card is unknown). They are removed from decks; a deck whose Leader is gone is dropped.

## Reset progress

*Settings → Reset progress* (after confirmation) calls `SaveManager.reset_profile()`: fresh profile, `profile.json.bak` deleted (no way back), new `profile.json` written. `settings.cfg` is kept.

## Versioning & migration

- `version` field at the root. `SaveManager` runs migrations `v1 → v2 → …` sequentially on load.
- The `v1 → v2` migration renames the progression balance from `hoard` to `rhinegold` without changing its value.
- The `v2 → v3` migration adds the owned `leaders` and `starter_collection_granted: false`.
- **Starter collection:** while `starter_collection_granted` is false, loading (or resetting) the profile adds the starter decks' Leaders and cards (`SaveManager.add_starter_decks()`: each card up to the copies a deck uses, not the sum) and saves. See [progression](../functional/06-progression.md#starting-collection).
- Every change to the save schema requires a migration function + a unit test with a sample old save.

## Resume an interrupted match

Because the engine is deterministic, a match is saved as **seed + decks + list of actions** and replayed on resume. This also serves as the format for bug reports.

> **Decision (2026-10-15):** Resume is **in v1.0** (replaces the 2026-10-09 decision that postponed it). On a phone, a call, a notification or Android killing the app in background must not cost the player their match.

### What is saved

`MatchRecord` (`core/match/match_record.gd`) holds it and writes it with `to_dict()`:

```json
{
  "version": 1,
  "content_hash": "3f9a…",
  "mode": "quick_match",
  "player_deck": "gods_starter",
  "opponent_deck": "nibelungs_starter",
  "difficulty": 1,
  "seed": 184467,
  "decks": [
    { "leader": "wotan", "cards": ["wotans_spear", "..."] },
    { "leader": "alberich", "cards": ["nibelung_miner", "..."] }
  ],
  "actions": [
    { "type": "redraw", "player": 0, "card_uids": [3, 7] },
    { "type": "play_card", "player": 0, "card_uid": 12, "target_uid": -1, "target_player": -1 },
    { "type": "undo_play", "card_uid": 12 }
  ]
}
```

- `actions` are `Action.to_record()` entries, plus `undo_play` when the player undoes a card play (the screen restores the state before the play and puts the card on top of the deck: `MatchRecord.undo_play()`, used by the duel and the replay alike).
- `player_deck` / `opponent_deck` / `difficulty` rebuild the Quick match setup, so **Rematch** after a resume plays the same decks. Campaign duels will add `campaign_duel`.

- **Decks are snapshots** (card IDs), not references to the player's deck slots: editing a deck later can't change a saved match.
- **AI moves are recorded as actions** like the player's. Replay never re-runs the AI search, so it doesn't depend on thread timing or on AI tuning changes.
- `content_hash` is a SHA-256 of the card data at match start (every stored property of the Leaders and cards in both decks, art excluded; a card met inside another one, like *Nothung* ↔ *Nothung (broken)*, counts by its ID). Card stats can change in an update; replaying old actions on new data could diverge.

### When it is written

- At match start, after each action applied by the `Match` (the player's and the AI's) and after an undo (atomic write via a `.tmp` file, no backup).
- On `NOTIFICATION_APPLICATION_PAUSED` (app sent to background) and `NOTIFICATION_WM_CLOSE_REQUEST`, in case an action was applied but not yet flushed.
- **Deleted** when the match ends (win, loss, draw) or the player leaves it (pause menu → Leave, results → Home). Undoing the last play from the results screen brings the match back, and it is saved again.

### Resume flow

1. At launch, `SaveManager` finds `current_match.json` → the main menu replays it (`MatchRecord.replay()`) to check it, then shows a **Resume match** prompt (Resume / Abandon).
2. **Resume:** rebuild the `Match` from seed + decks, re-apply every action **without animations**, then open the duel screen on the resulting state (battle log empty). If the AI's turn was interrupted, the AI simply starts thinking again. The Götterdämmerung explanation is not shown again if it has already started.
3. **Abandon:** delete the file. The match counts neither as a win nor a loss (no reward, no penalty).
4. **Cannot resume** (`content_hash` differs after an update, unknown card ID, an action is rejected as illegal during replay): delete the file, show a short message ("Your last match can't be resumed after the update"), and keep a copy as `current_match.failed.json` for bug reports (the file is moved, so the message shows once).

An unfinished **Quest** is lighter: the profile stores the current Quest ID and step (`campaign.<chapter>.quest_in_progress`), and the Quest restarts at that step.

## Backup

Android Auto Backup can back up `user://` to the user's Google account — enable it in the export settings and document it in the privacy policy.
