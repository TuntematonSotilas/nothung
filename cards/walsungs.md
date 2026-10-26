# Wälsungs

Led by Siegfried. Siegmund and Sieglinde, the wolf tribe of their childhood (Siegmund grew up a "Wölfing" in the forest with Wälse, Wotan in a wolf's pelt), and the sword Nothung: brought in pieces by Brünnhilde, drawn by Siegmund, reforged.

| id | name | type | subtypes | rarity | cost | atk | hp | keywords | bearer | abilities | leitmotifs | flavour |
|----|------|------|----------|--------|------|-----|----|----------|--------|-----------|------------|---------|
| wolfing | Wölfing | unit | wolf | common | 1 | 2 | 1 | | | | | |
| forest_wolf | Forest Wolf | unit | wolf | common | 2 | 2 | 2 | charge | | | | |
| siegfrieds_bear | Siegfried's Bear | unit | beast | common | 2 | 2 | 4 | guard | | | | |
| grane | Grane | unit | beast | rare | 3 | 4 | 3 | charge | | | ride | "Grane, my horse, I greet you!" — Brünnhilde, Götterdämmerung |
| sieglinde | Sieglinde | unit | walsung | epic | 3 | 3 | 4 | | | on_play: heal(friendly_leader, 2) | love | "You are the spring." — Sieglinde, Die Walküre |
| walse | Wälse (Wotan) | unit | god, wolf | epic | 4 | 4 | 4 | | | on_play: summon(wolfing) | | |
| brunnhilde_protector | Brünnhilde, Protector | unit | valkyrie | epic | 4 | 3 | 4 | flying | | on_play: create_artifact(nothung_broken) | ride | "The noblest hero in the world you bear, o woman, in your sheltering womb!" — Brünnhilde, Die Walküre |
| siegmund | Siegmund | unit | walsung, hero | epic | 4 | 5 | 4 | valhalla | | on_play[controls(nothung_broken)]: forge(nothung, 0) | sword | "Nothung! Nothung! So I name you, sword." — Siegmund, Die Walküre |
| horn_call | Siegfried's Horn Call | spell | | common | 1 | | | | | on_play: buff(selected_unit, 2, 0, charge) | | |
| winterstuerme | Winterstürme | spell | | common | 2 | | | | | on_play: buff(selected_unit, 2, 2) | love | "Winter storms have yielded to the month of May." — Siegmund, Die Walküre |
| dragons_blood | Dragon's Blood | spell | | common | 2 | | | | | on_play: draw(2) | | |
| sword_in_the_ash_tree | The Sword in the Ash Tree | spell | | rare | 2 | | | | | on_play: draw(1); on_play[controls(siegmund)]: buff(all_friendly_units, 1, 0) | sword | "My father promised me a sword." — Siegmund, Die Walküre |
| notung | Notung! Notung! | spell | | rare | 3 | | | | | on_play[controls(nothung_broken)]: forge(nothung, 0) | sword | "Nothung! Nothung! Coveted sword!" — Siegfried, Siegfried |
| nothung_broken | Nothung (broken) | artifact | weapon | legendary | 1 | | | | | | sword | |
| nothung | Nothung | artifact | relic, weapon | legendary | 0 | 3 | 0 | shatters_into(nothung_broken) | walsung | | sword | |
