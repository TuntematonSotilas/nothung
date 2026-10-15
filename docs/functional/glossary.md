# Glossary

> Shared vocabulary for game terms (used in docs, code and UI) and lore terms.
> Status: Draft · Last updated: 2026-10-15

## Game terms

| Term | Definition |
|------|------------|
| **Duel / Match** | One game between two players |
| **Quest** | Non-combat campaign stage: a short narrative with choices leading to one of several endings — see [05-game-modes](05-game-modes.md#quests-non-combat-stages) |
| **Leader** | The character representing a player; has Life and a Leader ability |
| **Life** | Leader hit points; 0 = defeat |
| **Energy** | In-match resource used to play cards and Leader abilities |
| **Rhinegold** | Progression currency earned outside matches and spent in the Forge |
| **Forge** | Collection screen where cards are crafted with Rhinegold |
| **Unit / Spell / Artifact** | Card types — see [04-cards](04-cards.md#card-types) |
| **Board** | Zone where units are in play |
| **Graveyard** | Zone for destroyed units and used spells |
| **Banished** | Removed from the game permanently |
| **Ability** | Umbrella term for anything a card or Leader does: traits, triggers, Leader ability |
| **Redraw** | Putting back part of the opening hand and drawing that many, once, before the first turn (genre term: *mulligan*). Screen: **Opening hand** |
| **Trait** | Short named ability with a fixed effect (Guard, Charge…) — see [04-cards](04-cards.md#traits-initial-list) |
| **Trigger** | Ability that fires on an event (On play, On death…) |
| **Götterdämmerung** | End-game clock: from turn 10, each Leader takes increasing damage at the start of its turn |
| **Leitmotif** | Synergy tag linking related cards |
| **Curse** | Drawback attached to the Ring and cursed cards |
| **Relic** | Artifact attached to one of your units (equipment), e.g. Nothung, Tarnhelm |
| **Bearer** | The unit carrying a Relic; *Bearer (X)* restricts which units can carry it |
| **Spear-breaker** | Siegfried's skill: double damage against Gods (he shatters Wotan's spear) |

> **Decision (2026-10-15):** Player-facing terms are **Trait** (not "keyword") and **Redraw** / **Opening hand** (not "mulligan"). Code and data keep their internal names (`keywords` field, `MulliganAction`); only the displayed text changes, through localisation.

## Lore terms

| Term | Definition |
|------|------------|
| **Nibelung** | Race of dwarves living in Nibelheim; Alberich and Mime are Nibelungs |
| **Rhinegold** | Gold guarded by the Rhinemaidens; whoever renounces love can forge it into the Ring |
| **The Ring** | Grants world mastery; cursed by Alberich to bring death to its owners |
| **Tarnhelm** | Magic helmet granting invisibility and transformation |
| **Valhalla** | Fortress of the gods, built by the Giants |
| **Valkyries** | Wotan's warrior daughters who bring fallen heroes to Valhalla |
| **Wälsungs** | Mortal bloodline fathered by Wotan: Siegmund, Sieglinde, Siegfried |
| **Gibichungs** | Rhineland dynasty: Gunther, Gutrune, and their half-brother Hagen |
| **Nothung** | Siegmund's sword, shattered by Wotan's spear, reforged by Siegfried |
| **Norns** | Weavers of fate's rope |
| **Götterdämmerung** | "Twilight of the Gods" — the end of the gods' reign |
