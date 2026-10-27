# Valkyries

Led by Brünnhilde. One card per sister (*Die Walküre*, Act III), told apart by role, not by an invented story: riding, carrying the fallen heroes to Valhalla, guarding Brünnhilde's rock. The heroes they carry (*Fallen Hero*, *Slain Warrior*) come back to the board.

| id | name | type | subtypes | rarity | cost | atk | hp | keywords | bearer | abilities | leitmotifs | flavour |
|----|------|------|----------|--------|------|-----|----|----------|--------|-----------|------------|---------|
| gerhilde | Gerhilde | unit | valkyrie | common | 2 | 2 | 2 | flying, charge | | | ride | "Hojotoho! Heiaha!" — Gerhilde, Die Walküre |
| rossweisse | Rossweisse | unit | valkyrie | common | 2 | 2 | 3 | flying | | | ride | |
| ortlinde | Ortlinde | unit | valkyrie | common | 2 | 1 | 4 | guard | | | ride | |
| fallen_hero | Fallen Hero | unit | hero | common | 2 | 2 | 3 | valhalla | | | valhalla | |
| schwertleite | Schwertleite | unit | valkyrie | common | 3 | 3 | 3 | flying | | | ride | |
| slain_warrior | Slain Warrior | unit | hero | common | 3 | 3 | 3 | valhalla | | | valhalla | |
| siegrune | Siegrune | unit | valkyrie | rare | 3 | 3 | 3 | flying | | on_play: resurrect() | ride | |
| grimgerde | Grimgerde | unit | valkyrie | common | 4 | 3 | 5 | guard | | | ride | |
| helmwige | Helmwige | unit | valkyrie | rare | 4 | 4 | 4 | flying | | | ride | |
| waltraute | Waltraute | unit | valkyrie | epic | 4 | 3 | 4 | flying | | on_play: return_ring() | ride | |
| hojotoho | Hojotoho! | spell | | common | 2 | | | | | on_play: buff(all_friendly_units, 1, 0) | ride | "Hojotoho! Hojotoho! Heiaha!" — Brünnhilde, Die Walküre |
| magic_fire | Magic Fire | spell | | rare | 3 | | | | | on_play: buff(selected_unit, 0, 3, guard) | magic_fire | "Whoever fears the tip of my spear shall never pass through the fire!" — Wotan, Die Walküre |
| annunciation_of_death | Annunciation of Death | spell | | rare | 4 | | | | | on_play: damage(selected_unit, 4) | | "Siegmund! Look at me!" — Brünnhilde, Die Walküre |
| ride_of_the_valkyries | Ride of the Valkyries | spell | | legendary | 5 | | | | | on_play: resurrect(); on_play: resurrect() | ride | |
| valkyrie_rock | The Valkyrie Rock | artifact | | common | 3 | | | | | start_of_turn: heal(friendly_leader, 2) | magic_fire | |
