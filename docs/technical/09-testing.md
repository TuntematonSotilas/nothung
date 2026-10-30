# Testing

> Test strategy and tooling.
> Status: Draft · Last updated: 2026-10-30

## Framework

> **Decision (2026-10-09):** [gdUnit4](https://github.com/MikeSchulze/gdUnit4) — richer assertions and mocking, VS Code integration, headless CLI runner. See [ADR-0004](../adr/0004-gdunit4.md).

- Addon in `game/addons/gdUnit4/`: **v6.2.2** (supports Godot 4.5 → 4.7.x), enabled as an editor plugin. The folder is **git-ignored** and installed by `bash tools/install_gdunit4.sh` (pinned version; does nothing if already installed). Run it after cloning, **before opening the editor** (otherwise Godot reports the enabled plugin as missing).
- The project configures gdUnit4 to look in `tests/` and enables automatic discovery when the editor opens. To rediscover manually, use the circular-arrows button in the gdUnit4 inspector.
- Upgrade: change `GDUNIT4_VERSION` in the script to a release that lists Godot 4.7 as compatible, rerun it, and commit the script.
- Test files: `tests/**/test_*.gd`, classes extending `GdUnitTestSuite`.
- Tests that touch files use `create_temp_dir()` with a **unique name per test** (e.g. suffixed with `Time.get_ticks_usec()`): gdUnit4 keeps the same temp folder across the tests of a suite, so leftovers from one test would leak into the next.
- Autoload scripts are tested on fresh instances (`preload(...).new()` + `auto_free`), with their file path pointed at the temp folder — never on the live autoloads.

## Test pyramid

| Level | Scope | Location | Run |
|-------|-------|----------|-----|
| Unit | Effects, keywords, rules validation, save migration | `tests/unit/` | Before each commit |
| Integration | Full scripted matches: seed + action list → expected final state | `tests/integration/` | Before each commit |
| Card data | Validation of every `CardData` ([03-data-model](03-data-model.md#validation)) | `tests/unit/` | Before each commit |
| AI soak | AI vs AI for N matches: no crash, no illegal move, no infinite loop; win-rate stats per deck | `tests/soak/` | Nightly / manual |
| Manual | UI, feel, device testing | Checklist below | Before each release |

## What must be tested

- Every keyword and every effect type has at least one unit test.
- Every rule in [functional/03-game-rules.md](../functional/03-game-rules.md) has a test named after its section.
- Each bug fix adds a regression test (often a recorded action list from the debug log).

## Determinism helpers

- Tests create matches with a fixed seed and stacked decks (`Match.create_for_test(deck_order_a, deck_order_b)`).
- A replay test re-applies a saved action list and compares the final state hash.
- `tests/unit/test_match_record.gd` replays a recorded match (after a JSON round trip, with an undone play) to the same state hash, and checks what must not replay (changed card data, unknown card, rejected action).
- **Resume tests** ([07-persistence](07-persistence.md#resume-an-interrupted-match)): save `current_match.json` at random points of scripted matches, rebuild, and check the state hash equals the live one; a file with a wrong `content_hash` or an illegal action is rejected cleanly.

## Running headless

gdUnit4 ships a command-line runner in its addon folder (`runtest.sh` / `runtest.cmd`), which uses the Godot binary given by the `GODOT_BIN` environment variable:

```sh
# from game/
export GODOT_BIN=/path/to/godot-4.7.2
"$GODOT_BIN" --headless --path . --import   # once first: also generates the .translation files
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests
```

On Windows, `GODOT_BIN` must point to the main `Godot.exe`, not the `_console.exe` wrapper (the wrapper looks for the main exe under its full versioned name).

- `--ignoreHeadlessMode` is required: gdUnit4 refuses headless runs by default because input events don't work there. Our tests don't simulate input; UI interaction tests, if any, will need a non-headless run.
- The `Remote Debugger: Unable to connect to host '127.0.0.1:0'` errors are expected: the runner uses port 0 on purpose to disable the interactive debugger.
- The runner exits with 0 when everything passes, 100 on failures. Reports (JUnit XML + HTML) go to `game/reports/` (git-ignored).
- On a fresh clone, the first `--import` logs `Cannot open file 'res://localization/strings.*.translation'` before generating them; a second run is clean.

Threaded AI ([05-ai-opponent](05-ai-opponent.md#threading)) is tested in **synchronous mode**, so tests stay deterministic.

### AI soak

Run the seeded Easy-AI vs Easy-AI baseline from `game/`:

```sh
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests/soak
```

The soak alternates the two starter decks between player positions, verifies every selected action with `Match.is_legal()`, requires every match to finish within the action limit, and prints aggregate turn and action counts plus win rates and draws per deck.

Initial first-legal-action Easy-AI baseline (40 seeded matches, 2026-10-18):

| Metric | Result |
|--------|--------|
| Average match length | 16.2 turns |
| Average actions | 60.7 |
| Gods starter wins | 39 / 40 (97.5%) |
| Nibelungs starter wins | 1 / 40 (2.5%) |
| Draws | 0 |

The first-legal-action baseline is not a balance conclusion: deck matchup and AI decision quality are confounded.

After adding the Easy action-scoring heuristic, before the mulligan heuristic, the same seeds produced:

| Metric | Result |
|--------|--------|
| Average match length | 15.5 turns |
| Average actions | 62.7 |
| Gods starter wins | 36 / 40 (90%) |
| Nibelungs starter wins | 4 / 40 (10%) |
| Draws | 0 |

The Nibelungs win rate improved from 2.5% to 10% under the heuristic, but Gods still dominate this mirrored-AI sample. Treat this as an initial signal rather than a deck-balance verdict.

With the mulligan heuristic enabled, the same 40 seeds produce:

| Metric | Result |
|--------|--------|
| Average match length | 16.6 turns |
| Average actions | 68.2 |
| Gods starter wins | 38 / 40 (95%) |
| Nibelungs starter wins | 2 / 40 (5%) |
| Draws | 0 |

The opening-hand policy did not improve the Nibelungs result in this small sample. More matchups and a stronger Normal profile are needed before changing card or turn-balance rules.

After the Gods canon rename (2026-10-19: same stats, except *Loge's Fire*, a 3-cost common spell, becoming **Loge**, a 4-cost rare 2/3 unit with the same on-play effect), the same 40 seeds produce:

| Metric | Result |
|--------|--------|
| Average match length | 15.6 turns |
| Average actions | 63.0 |
| Gods starter wins | 37 / 40 (92.5%) |
| Nibelungs starter wins | 3 / 40 (7.5%) |
| Draws | 0 |

Loge as a unit barely moves the balance; the Gods starter still dominates.

**Nibelungs rebalance (2026-10-19).** The Nibelungs starter was rewritten from the libretto (Mime, Hoard Bearers, Smiths of Nibelheim, Alberich's Whip, Mime's Brew, The Giant Serpent…) and Alberich's ability, which cost 2 Energy to gain 2, now summons a Nibelung Miner. Still 38 / 40 for the Gods. A diagnostic run over the same seeds showed two causes:

- **The Ring curse**: the Nibelungs created the Ring in 39 / 40 matches and lost 12.6 Life per match to it, since no Gods card can take it back.
- **Wotan's ability** (2 damage for 2 Energy) was used 96 times and removed the small dwarves every turn.

Variants measured in memory (same 40 seeds, Gods wins / Nibelungs wins):

| Variant | Result |
|---------|--------|
| Rewritten Nibelungs, Ring card in the deck | 38 / 2 |
| Ring card removed | 26 / 14 |
| Ring kept, no curse | 26 / 14 |
| Curse capped at 1 | 31 / 9 |
| Ring card removed + Wotan's ability at 3 Energy | 18 / 22 |
| Wotan's ability dealing 1 damage | 11–14 / 26–29 |

Retained ([game rules](../functional/03-game-rules.md#the-ring-signature-mechanic)): Ring card out of the starter deck, replaced by *Nibelung Host* (2/3 Guard, +1 Energy on death); Wotan's ability at 3 Energy. Result:

| Metric | Result |
|--------|--------|
| Average match length | 21.3 turns (~10.6 per player) |
| Average actions | 82.6 |
| Gods starter wins | 24 / 40 (60%) |
| Nibelungs starter wins | 16 / 40 (40%) |
| Draws | 0 |

Matches are slightly above the 8–10 turns per player target.

**First-turn Energy 2 (2026-10-21).** Starting max Energy raised from 1 to 2 for both players ([game rules](../functional/03-game-rules.md#resource-energy)). Same 40 seeds:

| Metric | Result |
|--------|--------|
| Average match length | 19.7 turns (~9.9 per player) |
| Average actions | 80.0 |
| Gods starter wins | 27 / 40 (67.5%) |
| Nibelungs starter wins | 13 / 40 (32.5%) |
| Draws | 0 |

Matches are back inside the 8–10 turns per player target, but the Gods gain more from the extra Energy (their 2-cost units come down on turn 1). Next lever if needed: *Nibelung Host* at 2/4.

**400-match baseline and the Wälsungs (2026-10-26).** 40 matches are too few to judge balance: the same Gods vs Nibelungs decks over **400 seeded matches** give 56 % / 44 % (not 67.5 / 32.5), 9.6 turns per player, and the Götterdämmerung fires in 58 % of matches. Balance runs now use 400 matches per pairing; the soak test keeps 40 per pairing for speed and plays all three starter decks against each other.

Easy AI fixes in the same pass (see [AI opponent](05-ai-opponent.md)): conditional effects only count when their condition is met, buffs on enemy units and damage to own units count as losses, Charge on a unit that could not attack is valued as an attack. They do not change the Gods vs Nibelungs figures.

Wälsungs starter variants (400 matches per pairing, Wälsungs win rate):

| Variant | vs Gods | vs Nibelungs |
|---------|---------|--------------|
| First draft, Spear-breaker 2 damage (×2 vs Gods), before the AI fixes | 18 % | 4 % |
| Same, after the AI fixes | 84 % | 4 % |
| Sturdier units, Spear-breaker 1 damage, cost 3 | 13 % | 6 % |
| + Spear-breaker cost 2, *Winterstürme* +2/+2, *Horn Call* +2/+0, *Siegfried's Bear* Guard | 40 % | 25 % |
| Same with Spear-breaker 2 damage, cost 3 | 94 % | 38 % |
| + *Wolf Cub* (now *Wölfing*) 2/1, *Sword in the Ash Tree*: with Siegmund, units +1/+0 | 43 % | 26 % |
| **+ stronger key units (Sieglinde 3/4, Wälse 4/4, Siegmund 5/4, Grane 4/3, Brünnhilde 3/4) — retained** | **59 %** | **44 %** |

The ×2 against the Gods is very sensitive: the Spear-breaker stays at 1 damage. Retained triangle (row wins against column, 400 matches each):

| | vs Gods | vs Nibelungs | vs Wälsungs |
|---|---|---|---|
| Gods | — | 56 % | 41 % |
| Nibelungs | 44 % | — | 56 % |
| Wälsungs | 59 % | 44 % | — |

Average length 8.7–9.6 turns per player; the Götterdämmerung fires in 45–58 % of matches, so its start stays at turn 10.

**One Legendary per faction (2026-10-26).** *Wotan's Spear* joins the Gods starter (replacing one *Blessing of Valhalla*), the *Tarnhelm* the Nibelungs starter (replacing one *Nibelung Hoard*); Siegmund became Epic. Variants (400 matches per pairing, row deck's win rate):

| Variant | Gods vs Nibelungs | Wälsungs vs Gods | Wälsungs vs Nibelungs |
|---------|-------------------|------------------|-----------------------|
| Spear (4): start of turn, 1 damage to all enemy units · Tarnhelm (3): +1/+1, Invisible | 66 % | 57 % | 46 % |
| Spear (4): start of turn, 1 damage to the enemy Leader | 65 % | 52 % | 46 % |
| Spear (4): on play, 1 damage to all enemy units; start of turn, heal 1 | 72 % | 45 % | 46 % |
| Spear (4, Leader version) with the Nibelungs keeping 2 Hoards (no Tarnhelm) | 61 % | — | — |
| No Spear (2 Blessings), Tarnhelm (3) in the Nibelungs deck | 60 % | — | — |
| Spear (5, Leader version) · Tarnhelm (2): +2/+1 | 60 % | 53 % | 46 % |
| **Spear (5, Leader version) · Tarnhelm (2): +2/+2 — retained** | **59 %** | **53 %** | **45 %** |

Both cards shift the Gods vs Nibelungs matchup by 4–5 points each, so both were tuned. Retained triangle: Gods 59 % vs Nibelungs, Wälsungs 53 % vs Gods, Nibelungs 55 % vs Wälsungs.

**The Valkyries (2026-10-26).** Fourth starter deck, led by Brünnhilde. The Easy AI now values *resurrect* only when a Valhalla unit waits in the graveyard, and *return the Ring* only when it takes the Ring from the opponent. Variants (400 matches per pairing, Valkyries win rate):

| Variant | vs Gods | vs Nibelungs | vs Wälsungs |
|---------|---------|--------------|-------------|
| Draft; Leader ability: resurrect a Valhalla unit (3 Energy) | 31 % | 32 % | 41 % |
| Sturdier sisters (Gerhilde 2/2, Rossweisse 2/3, Schwertleite 3/3, Siegrune 3/3, Helmwige 4/4); resurrect for 2 Energy | 35 % | 34 % | 36 % |
| **Same sisters; Leader ability: summon a *Fallen Hero* (3 Energy) — retained** | **60 %** | **47 %** | **47 %** |

A Leader ability that only works once a hero has died was the main weakness: the other Leaders act from the first turn.

Retained matrix (row deck's win rate, 400 matches each; average length 8.0–9.5 turns per player):

| | vs Gods | vs Nibelungs | vs Wälsungs | vs Valkyries |
|---|---|---|---|---|
| Gods | — | 59 % | 48 % | 40 % |
| Nibelungs | 41 % | — | 55 % | 53 % |
| Wälsungs | 53 % | 45 % | — | 53 % |
| Valkyries | 60 % | 47 % | 47 % | — |

**Neutral cards (2026-10-27).** No starter deck contains Neutral cards, so the soak test adds a **Neutral test deck**: Alberich with 20 of the Neutral cards once (all but *Woglinde*; *Potion of Forgetfulness* replaced her on 2026-10-27, same win rates), against the Gods and Nibelungs starters. It checks that the AI only plays legal Neutral actions (Ring theft, relic, double summons, damage to all units). As a pure-Neutral deck it wins about a third of its matches (32.5 % vs Gods, 35 % vs Nibelungs, 40 matches each), which is expected: Neutral cards complete a faction deck. Their real balance comes with built decks (milestone 5).

**Gods and Nibelungs at 15 cards (2026-10-27).** New cards in the starter decks: Gods — *The Wanderer* (replacing a *Fricka*) and *Rainbow Bridge* (replacing the last *Blessing of Valhalla*); Nibelungs — *Alberich, the Toad* (replacing a *Nibelung Miner*) and *The Anvils of Nibelheim* (replacing an *Alberich's Whip*). *Froh*, *Fricka's Rams* and *Mime's Forge* (now *Mime's Cave*) stay in the card pool. Variants (400 matches per pairing):

| Variant | Gods vs Nibelungs | Gods vs Wälsungs | Gods vs Valkyries |
|---------|-------------------|------------------|-------------------|
| Wanderer 4/5 draws 2, Rainbow Bridge +0/+2, Toad 2/2, Anvils cost 4 | 68 % | 58 % | 59 % |
| Wanderer 4/4 draws 1, Rainbow Bridge +0/+1 | 64 % | 53 % | 50 % |
| **+ Toad 2/3, Anvils cost 3 — retained** | **57 %** | **53 %** | **50 %** |

Retained matrix (row deck's win rate, 400 matches each; 8.0–9.5 turns per player):

| | vs Gods | vs Nibelungs | vs Wälsungs | vs Valkyries |
|---|---|---|---|---|
| Gods | — | 57 % | 53 % | 50 % |
| Nibelungs | 43 % | — | 56 % | 55 % |
| Wälsungs | 47 % | 44 % | — | 53 % |
| Valkyries | 50 % | 45 % | 47 % | — |

**Difficulty ladder (2026-10-27).** `test_difficulty_ladder` plays each difficulty against the one below it with the Gods and Nibelungs starters, alternating decks and who goes first, and checks that every action is legal. Hard uses a fixed **60 iterations** per action instead of its time budget, so the result is reproducible (seeded) and the test takes about 20 s. Current result: Normal beats Easy **29 / 40** (asserted > 60 %), Hard beats Normal **7 / 10** (asserted > 50 %). With 200 iterations, Hard beats Normal 18 / 20 (≈ 180 ms per action on desktop). The starter balance matrix above stays measured Easy vs Easy.

`tests/unit/test_ai.gd` covers the hidden-information mask (the opponent's hand is redealt from their own cards, the live state is untouched), lethal attacks for Normal and Hard, Normal refusing a losing trade, and Hard's time budget.

## Manual test checklist (release)

- [ ] Install on reference device + one low-end device + one tall-aspect (20:9+) device
- [ ] Complete tutorial
- [ ] Play one match per difficulty
- [ ] Kill app mid-match / mid-save → profile intact, match resumes at the same state (incl. during the AI's turn)
- [ ] Rotate / background / resume
- [ ] Back button on every screen
- [ ] Switch language to each of DE, ES, FR → no text overflow, no missing key
