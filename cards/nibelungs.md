# Nibelungs

| id | name | type | subtypes | rarity | cost | atk | hp | keywords | bearer | abilities | leitmotifs | flavour |
|----|------|------|----------|--------|------|-----|----|----------|--------|-----------|------------|---------|
| nibelung_miner | Nibelung Miner | unit | dwarf | common | 1 | 1 | 2 | | | on_death: gain_energy(1) | forge | |
| mime | Mime | unit | dwarf | common | 2 | 1 | 3 | | | on_play: draw(1) | forge | "Endless drudgery! Toil without purpose!" — Mime, Siegfried |
| hoard_bearers | Hoard Bearers | unit | dwarf | common | 2 | 2 | 4 | guard | | | hoard | |
| nibelung_host | Nibelung Host | unit | dwarf | common | 2 | 2 | 3 | guard | | on_death: gain_energy(1) | hoard | |
| smiths_of_nibelheim | Smiths of Nibelheim | unit | dwarf | common | 3 | 2 | 2 | | | on_play: summon(nibelung_miner) | forge | |
| renunciation_of_love | Renunciation of Love | spell | | common | 2 | | | | | on_play: create_ring(); on_play: draw(1) | ring | "Only he who forswears the power of love…" — Woglinde, Das Rheingold |
| nibelung_hoard | The Nibelung Hoard | spell | | common | 1 | | | | | on_play: gain_energy(2) | hoard | |
| alberichs_whip | Alberich's Whip | spell | | common | 3 | | | | | on_play: buff(all_friendly_units, 1, 1) | ring | |
| alberichs_curse | Alberich's Curse | spell | | rare | 3 | | | | | on_play: damage(selected_unit, 2); on_play: draw(1) | ring | "Cursed be this ring!" — Alberich, Das Rheingold |
| mimes_brew | Mime's Brew | spell | | rare | 3 | | | | | on_play: damage(selected_unit, 3) | | |
| giant_serpent | The Giant Serpent | unit | beast | rare | 5 | 5 | 5 | | | | tarnhelm | |
| tarnhelm | Tarnhelm | artifact | relic | legendary | 2 | 2 | 2 | invisible | | | ring | "Night and mist, like no one!" — Alberich, Das Rheingold |
| alberich_toad | Alberich, the Toad | unit | dwarf | epic | 2 | 2 | 3 | invisible | | | ring | "There, the toad — seize it quickly!" — Loge, Das Rheingold |
| mimes_forge | Mime's Forge | artifact | | common | 2 | | | | | start_of_turn: heal(friendly_leader, 1) | | |
| anvils_of_nibelheim | The Anvils of Nibelheim | artifact | | rare | 3 | | | | | start_of_turn: summon(nibelung_miner) | | |
