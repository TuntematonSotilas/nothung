# AI opponent

> How the computer opponent chooses its moves. Supports [functional/05-game-modes.md](../functional/05-game-modes.md).
> Status: Draft · Last updated: 2026-10-09

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

1. **v0 — Random legal**: for testing the engine.
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
| Easy | Greedy, shallow, ignores some keywords | High random choice probability |
| Normal | Greedy with full evaluation | Low |
| Hard | Turn planning (+ MCTS if implemented) | None |

## Campaign personalities

`AIProfile` overrides per boss, e.g.:
- *Alberich*: prioritises Energy and the Ring.
- *Fafner*: defensive, keeps Guard units.
- *Hagen*: targets the strongest enemy unit.

## Threading

> **Decision (2026-10-09):** The AI search runs on a worker thread from the start (`WorkerThreadPool`). See [ADR-0003](../adr/0003-ai-on-worker-thread.md).

Rules that make this safe:

1. The main thread gives the AI a **deep copy** of the `GameState` (`duplicate_state()`), with hidden information masked. The AI never touches the live `Match`.
2. The copy is owned by the worker thread only; nothing else reads or writes it.
3. `CardData` / `AIProfile` resources are shared but **read-only** at runtime.
4. The AI returns only an `Action`. The result is handed back to the main thread (`call_deferred`), which applies it with `Match.apply()` — the live state is only ever mutated on the main thread.
5. No Node, signal emission to the scene tree, or autoload access from inside the AI code.
6. The task can be cancelled (flag checked in the search loop) if the player quits the duel.
7. A time budget (e.g. 800 ms) stops the search and returns the best action found so far.

For debugging and tests, the AI can also run **synchronously** on the calling thread (same code, no `WorkerThreadPool`).
