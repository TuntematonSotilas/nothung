# ADR-0001: Godot 4 with GDScript, Android only

- **Status:** Accepted
- **Date:** 2026-10-08
- **Deciders:** Gaël

## Context

We are building a single-player, offline card game for mobile. We need an engine with good 2D/UI support, a free licence, Android export, and a fast iteration loop for a small team.

## Decision

- Engine: **Godot 4.7.2**, pinned for the editor and export templates; upgrades go through a new ADR.
- Scripting language: **GDScript** with mandatory static typing.
- Target platform for v1.0: **Android** only.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Godot + C# | Stronger tooling, performance | C# Android export less mature than GDScript; heavier build |
| Unity | Large ecosystem, mature mobile tooling | Licensing/runtime fee history, heavier editor |
| Flutter / web stack | Great UI tooling | Not a game engine; animation & effects harder |

## Consequences

- No native type system as strict as C#: mitigated by static typing warnings as errors ([technical/08-coding-standards.md](../technical/08-coding-standards.md)).
- Heavy computation (AI search) must be designed with performance in mind (state copies, possible threading) — see [technical/05-ai-opponent.md](../technical/05-ai-opponent.md).
- iOS can be added later with the same codebase (needs a Mac for export and an Apple developer account).
