# ADR-0003: AI search runs on a worker thread

- **Status:** Accepted
- **Date:** 2026-10-09
- **Deciders:** Gaël

## Context

The AI must choose actions within ~1 s on a mid-range Android phone without ever freezing the UI ([technical/05-ai-opponent.md](../technical/05-ai-opponent.md)). Harder difficulties will simulate many game states.

## Decision

The AI search runs on a worker thread (`WorkerThreadPool`) from the start, on a deep copy of the game state. Only the resulting `Action` crosses back to the main thread, where it is applied. A synchronous mode (same code, no thread) exists for tests and debugging.

> **Implementation update (2026-10-16):** The first Easy opponent uses a dedicated `Thread` rather than `WorkerThreadPool`: its bounded legal-action selection returns a value directly through `wait_to_finish()`, avoiding shared result state. The AI receives serialized legal actions rather than a game-state copy. Deeper search can move to the pool if it needs task scheduling/cancellation.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Time-sliced search on the main thread | No concurrency bugs | Search code must be resumable; competes with rendering for frame time |
| **Worker thread** | UI stays smooth; full CPU core for the search; scales to Hard AI | Concurrency discipline required; harder to debug |

## Consequences

- The rules engine must stay free of Nodes and global state ([technical/01-architecture.md](../technical/01-architecture.md)) — already a core principle; this ADR makes it mandatory.
- `duplicate_state()` must be a true deep copy and fast; it needs its own unit tests.
- Resources (`CardData`, `AIProfile`) are read-only at runtime.
- Tests run the AI in synchronous mode to stay deterministic.
