# Warn encounter database coverage — v2.6.1

This file tracks **index coverage** separately from **verified actionable-rule coverage**. An encounter being indexed means Warn knows it belongs in the research set; it does **not** imply every mechanic has been verified yet.

## Indexed encounter sets

- Ambuscade Volume 1: **24/24 historical encounter families indexed**
- Ambuscade Volume 2: **67/67 historical encounter families indexed**
- High-Tier Mission Battlefields: **30/30 BG-Wiki HTMB categories indexed**
- Omen: **9/9 boss encounters indexed** — three Glassy mid-bosses and six Caturae bosses
- Geas Fete: **85/85 Aeonic-route encounters indexed** — 25 Escha - Zi'Tah, 32 Escha - Ru'Aun, and 28 Reisenjima
- Sortie: **17/17 named NMs and bosses indexed** — eight sector NMs, eight A-H bosses, and Aminon
- Odyssey: **68 encounter entries indexed** — 50 named Sheol A/B/C NMs, one shared Mimic hazard, and all 17 Sheol Gaol bosses

## Verified actionable coverage in v2.6

- Ambuscade Volume 1: **24 encounter families** have one or more contextual rules/state alerts.
- Ambuscade Volume 2: **54 encounter families** now have one or more contextual rules/state alerts.
- HTMB: **30 of 30 categories** have direct encounter rules or inherited actor rules. **Divine Might** benefits from the individual Ark Angel actor rules, because Warn matches those bosses by actor name regardless of which Ark Angel battlefield they appear in.
- Omen: **9 of 9 indexed bosses** have direct verified rules.
- Geas Fete: **8 of 85 indexed encounters** have direct verified rules, comprising 24 alerts for Warder of Courage and all seven Reisenjima HELMs.
- Sortie: **9 of 17 indexed encounters** have direct verified coverage, comprising 44 action alerts and 2 encounter-state warnings for every major boss.
- Odyssey: **8 of 68 indexed entries** have direct verified coverage, comprising 24 alerts for the shared Mimic hazard and all seven Atonement 3-4 bosses.
- Database total: **335 ability/spell rules + 16 encounter-state rules**, across **300 indexed encounter entries**.

### Major Volume 2 additions

Durga, Sowl Devourer, Kauri, Yartsa Gunbu, Gwas-y-neidr, Alluttu, All-Watcher, Natsilane, Chelone, Thillloab, Mnyiri, Sombra Dragon, Bozzetto Bombs, Bozzetto Jody/Julika/Vivian, Pamola, Enigmatic Hypnotist, Lancer Jack, Vengeful Citrullus, Lycaon, Chorister, and Bozzetto Adamantoise.

The v2.5 history pass additionally covers Ravenous Jack, Dastardly Banneret, Swarming Lizard,
Winnower Jack, Scatterbrained Leech, Hunky, Achimi, Possessed Heartwing, Culler Jack, Elecampane,
Aurantia, Ixchel, Carousing Clot, Mukasura, Microcosmus, Reaper Jack, Rigid Porcelain, O Tokata /
Guayota, Voibugard, Hercinia, Khalkotaurus, Ironclad Reoriginator, Kulpercorpion, Turgmam,
Carcinus, Splendid Sakura, Symbiotic Marid, Februus, Ibong Adarna, Goes, and Ronove.

### Major HTMB additions

- All five individual Ark Angels
- Return to Delkfutt
- The Shadow Lord Battle
- Puppet in Peril
- The Savage
- The Celestial Nexus
- All six elemental Avatar Prime trials
- The Moonlit Path
- Waking Dreams
- Waking the Beast
- Existing rules for Cloud of Darkness, Lilith, Odin, Alexander, Cait Sith, Shinryu, Ultima, Promathia, and Tenzen remain intact
- Head Wind
- Legacy of the Lost

### Initial Geas Fete additions

- Warder of Courage
- Albumen
- Erinys
- Onychophora
- Schah
- Teles
- Vinipata
- Zerde

### Sortie additions

- Ghatjot, Leshonn, Skomora, and Degei
- Dhartok, Gartell, Triboulex, and Aita
- Aminon
- All eight sector NMs are indexed as future research targets

### Odyssey additions

- Complete Sheol A, B, and C named-NM index
- Shared Death Trap / Hell Trap Mimic warnings
- Complete 17-boss Sheol Gaol index
- Direct alerts for Xevioso, Ngai, Kalunga, Ongo, Mboze, Arebati, and Bumba

## Verification policy

Rules should be added only when the response is sufficiently supported. Community reaction configs may be used to **discover candidates**, but do not by themselves make a rule verified. Prefer BG-Wiki encounter/bestiary data, official update notes, and corroborated encounter archives.

Do not turn uncertain advice into a confident alert. If a source establishes that a move is dangerous but not the correct response, use a descriptive warning rather than inventing a counter.

## Next research passes

1. Continue Ambuscade V2 from **54 actionable families toward all 67** when precise encounter sources become available. Current indexed-only research targets are Anaximander, Quirinus, Bohun Upas, Celebrant, Delos, Tranquil Treant, Popular Penelope, Gudjewg, Bozzetto Fenrir, Khione, Scithiraptor, Heimdallr, and Kulshedra.
2. Expand Odyssey into Atonement 1-2 and ordinary Sheol NMs only where their altered Odyssey behavior supports a specific, useful reaction rather than a generic family warning.
3. Research Sortie's eight minor sector NMs and hidden-objective messages separately from the completed major-boss pass.
4. Expand Geas Fete from the 8 highest-priority actionable encounters toward the complete 85-entry index, prioritizing mechanics with reliable sources and clear player responses.
5. Add BLU-set-spell capability checks (Sudden Lunge, Blank Gaze, etc.) before surfacing BLU-specific counter prompts.
6. Continue into Vagary, Dynamis-Divergence, and other endgame systems.
