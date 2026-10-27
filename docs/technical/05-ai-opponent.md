# AI opponent

> How the computer opponent chooses its moves. Supports [functional/05-game-modes.md](../functional/05-game-modes.md).
> Status: In progress · Last updated: 2026-10-27

## Requirements

- Plays only legal moves (uses `Match.get_legal_actions()`).
- **Does not cheat**: no access to the human's hand or deck order (works on a state where hidden information is masked/randomised).
- Decides within **≤ 1 s** per action on a mid-range phone; runs on a worker thread so the UI never freezes ([Threading](#threading)).
- Difficulty is tunable; campaign bosses can have personalities.

## Interface

```gdscript
# game/ai/ai_player.gd
static func prepare(engine: Match, player_id: int, profile: AIProfile, seed: int) -> Dictionary  # main thread
static func choose(job: Dictionary) -> Dictionary                                                # worker thread
```

- `prepare()` builds a **job** from copies only: the Easy scores of the legal actions and, for Normal and Hard, a **masked copy** of the state ([Hidden information](#hidden-information)).
- `choose()` returns one action record (`Action.to_record()`); the main thread rebuilds the `Action` and applies it.

`AIProfile` (Resource, `game/ai/ai_profile.gd`): difficulty, personality, noise, time budget / iteration cap, UCB1 exploration and evaluation weights. `AIProfile.preset(difficulty, personality)` returns the default profile; campaign bosses will use saved profiles.

| File | Role |
|------|------|
| `ai/ai_player.gd` | Entry point, job building, hidden-information mask |
| `ai/easy_ai.gd` | Easy: heuristic action scoring (also the playout policy of Hard and the opening-hand Redraw of every level) |
| `ai/state_evaluator.gd` | Scores a whole state from one player's point of view (Normal and Hard) |
| `ai/greedy_ai.gd` | Normal |
| `ai/mcts_ai.gd` | Hard |

## Difficulty levels

| Level | Strategy | Noise | Cost per action (desktop) |
|-------|----------|-------|---------------------------|
| Easy | Scores each legal action with a heuristic, plays the best one | None | < 1 ms |
| Normal | Simulates each legal action on the masked state and keeps the best evaluated result; ends its turn when nothing improves its position | 2 evaluation points (Gaussian) | ~2 ms |
| Hard | Information-set MCTS over its own turn, with the opponent's reply played out | None | 700 ms time budget |

All levels use the Easy heuristic for the opening-hand Redraw.

Measured ladder (AI vs AI, Gods and Nibelungs starters, alternating decks and first player): Normal beats Easy 29 / 40, Hard (only 60 iterations per action) beats Normal 7 / 10; with 200 iterations Hard beats Normal 18 / 20 ([AI soak](09-testing.md#ai-soak)).

### Easy — action heuristic

Scores each legal action using own-card value, board trades, lethal attacks, play effects and Ring value; selects the highest score. Effects are scored only when their condition will be met, buffs on enemy units and damage to own units count as losses, Charge on a unit that could not attack is valued as an attack, and faction damage bonuses (Spear-breaker) are counted. *Resurrect* is worth something only when a Valhalla unit waits in the graveyard and the board has room; *return the Ring* and *take the Ring* only when the opponent holds it (taking never creates it). It plays every useful action and attacks with every ready unit.

### Normal — greedy with full evaluation

For each legal action (Concede excluded), apply it with `Match.from_state()` on a copy and score the result with `StateEvaluator`. *End turn* scores the current state, so the AI stops as soon as no action improves its position (it keeps a spell, does not throw a small unit into a big one). The decision is one action at a time; the next action is chosen on the new state.

### Hard — information-set MCTS

Each iteration:

1. **Sample** the hidden cards again (`AIPlayer.reshuffle_hidden()`): the opponent's hand is redealt from their hand and deck, both decks are reshuffled, the rules RNG is reseeded.
2. **Select / expand** in the tree of the AI's own actions for this turn, with UCB1 (exploration 0.7). Actions are keyed by their record; a child's UCB uses the number of times it was *available* (legal in the sample), as in information-set MCTS.
3. **Play out** the rest of the AI's turn, then the opponent's whole turn, with the Easy heuristic (at most 30 actions each).
4. **Evaluate** with `StateEvaluator`; the reward is a sigmoid of the gain over the starting state (20 evaluation points ≈ 0.73).

When the time budget (or the iteration cap, used by tests and the soak) runs out, the most visited first action is played. If only *End turn* is legal, no search runs. One iteration takes about 2 ms on desktop; a phone is expected to run ~100 iterations in the budget.

### Evaluation function

`StateEvaluator.evaluate(state, player, profile)`, from `player`'s point of view; a won match is +10000, a lost one −10000:

```
score = own_life_weight   * life_value(my_life)
      - enemy_life_weight * life_value(enemy_life)
      + board_weight      * (Σ my unit value − Σ enemy unit value)
      + hand_weight       * 3 * (my hand size − enemy hand size)
      + artifact_weight   * (Σ my artifacts − Σ enemy artifacts)     # 2 + 1.5 × cost each
      + ring_weight       * ring value                                # next bonus − next curse, for the holder
      − 30 if the enemy board can kill me next turn (Guard soaks the smallest attackers, Flying ignores Guard)
      + 10 if my board can kill the enemy next turn
```

- `life_value(l) = 2·l`, minus 1.5 per point below 8 (the last points lose the match).
- Unit value = `1.8 × attack + 1.2 × health` (current stats, relic included) + 2 Guard, + 2 Flying, + 1 Valhalla, + 2 while hidden (Invisible).

Weights live in `AIProfile`, so they can be tuned without code changes.

## Hidden information

The AI never reads the opponent's hand or either deck order. `prepare()` hands the worker a copy in which the opponent's hand is redealt at random from their **hand + deck** (same hand size), both decks are shuffled and the rules RNG is reseeded. The AI therefore knows which cards the opponent has left (their decklist, as a player who knows the starter decks), not which ones are in hand nor what either player draws next. Hard resamples at every iteration.

## Personalities

`AIProfile.Personality` changes the evaluation weights:

| Personality | Weights |
|-------------|---------|
| Balanced | All 1 |
| Aggressive | Enemy Life 1.6, own Life 0.7 |
| Defensive | Own Life 1.5, board 1.2 |

Campaign bosses (milestone 7) will pick one, e.g.:
- *Alberich*: prioritises Energy and the Ring (higher `ring_weight`).
- *Fafner*: defensive, keeps Guard units.
- *Hagen*: aggressive, targets the strongest enemy unit.

## Threading

> **Decision (2026-10-09):** AI runs off the main thread. See [ADR-0003](../adr/0003-ai-on-worker-thread.md) for the implementation updates.

Rules that make this safe:

1. The worker only receives the job: action records and a masked **copy** of the state. It never touches the live `Match`.
2. The worker builds its own `Match` objects on copies (`Match.from_state()`); card resources are shared read-only.
3. The main thread rebuilds the `Action` and applies it with `Match.apply()` — the live state is only mutated on the main thread.
4. No Node, signal emission to the scene tree, or autoload access from inside the AI code.
5. The duel screen starts the worker, waits for the short AI pause and then for the thread **one frame at a time** (no blocking `wait_to_finish()` while it runs). Leaving the screen joins the thread; Hard stops on its own time budget. A rematch started meanwhile discards the result.

For debugging and tests, `AIPlayer.choose()` can also run **synchronously** on the calling thread.

The duel uses **Normal** until the quick match menu (milestone 5) lets the player choose (`duel.gd: ai_difficulty`).
