# AI opponent

> How the computer opponent chooses its moves. Supports [functional/05-game-modes.md](../functional/05-game-modes.md).
> Status: In progress · Last updated: 2026-10-16

## Requirements

- Plays only legal moves (uses `Match.get_legal_actions()`).
- **Does not cheat**: no access to the human's hand or deck order (works on a state where hidden information is masked/randomised).
- Decides within **≤ 1 s** per action on a mid-range phone; runs on a worker thread so the UI never freezes ([Threading](#threading)).
- Difficulty is tunable; campaign bosses can have personalities.

## Interface

```gdscript
class_name AIController
extends RefCounted

func _init(profile: AIProfile) -> void
func choose_action(state: GameState, legal: Array[Action]) -> Action
```

`AIProfile` (Resource): difficulty, evaluation weights, search depth, randomness, scripted overrides.

## Approach (incremental)

1. **v0 — Easy heuristic (implemented)**: score legal actions using own-card value, board trades, lethal attacks, play effects and Ring value; select the highest score. Effects are scored only when their condition will be met, buffs on enemy units and damage to own units count as losses, Charge on a unit that could not attack is valued as an attack, and faction damage bonuses (Spear-breaker) are counted. *Resurrect* is worth something only when a Valhalla unit waits in the graveyard and the board has room; *return the Ring* and *take the Ring* only when the opponent holds it (taking never creates it).
2. **v1 — Greedy heuristic**: for each legal action, simulate on a copy of the state, score with an evaluation function, pick the best. Repeat until `EndTurn` is best.
3. **v2 — Turn planning**: search sequences of actions within the turn (beam search / limited depth), still with a heuristic evaluation.
4. *(Optional)* **v3 — Determinised MCTS** for Hard difficulty.

### Evaluation function (draft)

```
score = w_life   * (my_life - enemy_life)
      + w_board  * (sum my unit value - sum enemy unit value)
      + w_hand   * (my hand size - enemy hand size)
      + w_energy * unused_energy_penalty
      + w_ring   * ring_value(turns_held)
      + lethal bonus / lethal-threat penalty
```

Unit value ≈ `attack + health` + keyword bonuses. Weights live in `AIProfile` so they can be tuned without code changes.

## Difficulty levels

| Level | Strategy | Noise |
|-------|----------|-------|
| Easy | Shallow legal-action scoring with basic tactical cues | None |
| Normal | Greedy with full evaluation | Low |
| Hard | Turn planning (+ MCTS if implemented) | None |

## Campaign personalities

`AIProfile` overrides per boss, e.g.:
- *Alberich*: prioritises Energy and the Ring.
- *Fafner*: defensive, keeps Guard units.
- *Hagen*: targets the strongest enemy unit.

## Threading

> **Decision (2026-10-09):** AI runs off the main thread. The first bounded Easy selector uses a dedicated `Thread`; see [ADR-0003](../adr/0003-ai-on-worker-thread.md) for the implementation update.

Rules that make this safe:

1. The current Easy AI receives only serialized records from `Match.get_legal_actions()`. It does not inspect the live `Match`, game state, hidden hand or deck.
2. Legal-action records are immutable input to the worker; the AI returns one record.
3. The main thread rebuilds the `Action` and applies it with `Match.apply()` — the live state is only mutated on the main thread.
4. No Node, signal emission to the scene tree, or autoload access from inside the AI code.
5. Current selection is bounded by the number of legal actions and takes less than a second; search cancellation and a deeper time budget are not needed for this first heuristic.

For debugging and tests, the selector can also run **synchronously** on the calling thread (same `choose_action()` function).

The main thread builds compact, serializable action records with scores from the AI's own hand and public board state. The worker only compares those records; it never receives the live match, the opponent's hand, or either deck order.
