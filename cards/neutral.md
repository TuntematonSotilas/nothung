# Neutral

Usable by every faction (one faction + Neutral per deck). The Rhinemaidens and the Rhinegold, the Woodbird, the Norns and Erda; the Giants (Fasolt, Fafner) and the Gibichungs (Gunther, Gutrune, Hagen) — candidates for later factions; Hunding and his kinsmen, the Wälsungs' enemies. Fafner, Hagen and *The Giants' Wage* can take the Ring from its holder.

| id | name | type | subtypes | rarity | cost | atk | hp | keywords | bearer | abilities | leitmotifs | flavour |
|----|------|------|----------|--------|------|-----|----|----------|--------|-----------|------------|---------|
| woglinde | Woglinde | unit | rhinemaiden | common | 1 | 1 | 2 | | | | rhinegold | "Weia! Waga! Wave, you billow, roll to the cradle!" — Woglinde, Das Rheingold |
| woodbird | Woodbird | unit | beast | common | 1 | 1 | 1 | flying | | on_play: draw(1) | | "Hey! Siegfried now owns the Nibelungs' hoard!" — Woodbird, Siegfried |
| wellgunde | Wellgunde | unit | rhinemaiden | common | 2 | 2 | 2 | | | | rhinegold | |
| flosshilde | Flosshilde | unit | rhinemaiden | common | 2 | 1 | 4 | guard | | | rhinegold | |
| hundings_kinsmen | Hunding's Kinsmen | unit | human | common | 2 | 2 | 2 | charge | | | | |
| gibichung_vassal | Gibichung Vassal | unit | gibichung | common | 2 | 2 | 3 | | | | | |
| hunding | Hunding | unit | human | rare | 3 | 3 | 4 | | | on_play: damage(selected_unit, 1, walsungs) | | |
| gutrune | Gutrune | unit | gibichung | rare | 3 | 2 | 4 | | | on_play: heal(friendly_leader, 3) | | |
| gunther | Gunther | unit | gibichung | rare | 4 | 3 | 5 | guard | | | | |
| erda | Erda | unit | goddess | epic | 4 | 2 | 5 | | | on_play: draw(2) | | "Yield, Wotan, yield!" — Erda, Das Rheingold |
| hagen | Hagen | unit | gibichung | legendary | 5 | 5 | 4 | | | on_play: steal_ring() | curse | "I have avenged perjury!" — Hagen, Götterdämmerung |
| fasolt | Fasolt | unit | giant | epic | 6 | 6 | 6 | guard | | | valhalla | |
| fafner | Fafner | unit | giant | epic | 7 | 7 | 7 | | | on_play: steal_ring() | curse | "I lie here and I possess." — Fafner, Siegfried |
| rhinegold_lament | Rhinegold! | spell | | common | 2 | | | | | on_play: heal(friendly_leader, 4) | rhinegold | "Rhinegold! Pure gold!" — The Rhinemaidens, Das Rheingold |
| giants_wage | The Giants' Wage | spell | | rare | 2 | | | | | on_play: steal_ring(); on_play: draw(1) | ring | |
| the_norns | The Norns | spell | | rare | 3 | | | | | on_play: draw(2) | | "Do you know what will come of it?" — The Norns, Götterdämmerung |
| hagens_call | Hoiho! Hagen's Call | spell | | common | 4 | | | | | on_play: summon(gibichung_vassal); on_play: summon(gibichung_vassal) | | "Hoiho! Hoihohoho!" — Hagen, Götterdämmerung |
| valhalla_in_flames | Valhalla in Flames | spell | | epic | 6 | | | | | on_play: damage(all_units, 2) | valhalla | |
| the_rhinegold | The Rhinegold | artifact | | rare | 2 | | | | | start_of_turn: gain_energy(1) | rhinegold | |
| hagens_spear | Hagen's Spear | artifact | relic, weapon | rare | 3 | 2 | 0 | | | | curse | |
