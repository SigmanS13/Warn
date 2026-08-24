# Warn encounter database coverage — v2.5.0

This file tracks **index coverage** separately from **verified actionable-rule coverage**. An encounter being indexed means Warn knows it belongs in the research set; it does **not** imply every mechanic has been verified yet.

## Indexed encounter sets

- Ambuscade Volume 1: **24/24 historical encounter families indexed**
- Ambuscade Volume 2: **67/67 historical encounter families indexed**
- High-Tier Mission Battlefields: **30/30 BG-Wiki HTMB categories indexed**
- Omen: **9/9 boss encounters indexed** — three Glassy mid-bosses and six Caturae bosses
- Geas Fete: **85/85 Aeonic-route encounters indexed** — 25 Escha - Zi'Tah, 32 Escha - Ru'Aun, and 28 Reisenjima

## Verified actionable coverage in v2.5

- Ambuscade Volume 1: **24 encounter families** have one or more contextual rules/state alerts.
- Ambuscade Volume 2: **54 encounter families** now have one or more contextual rules/state alerts.
- HTMB: **30 of 30 categories** have direct encounter rules or inherited actor rules. **Divine Might** benefits from the individual Ark Angel actor rules, because Warn matches those bosses by actor name regardless of which Ark Angel battlefield they appear in.
- Omen: **9 of 9 indexed bosses** have direct verified rules.
- Geas Fete: **8 of 85 indexed encounters** have direct verified rules, comprising 24 alerts for Warder of Courage and all seven Reisenjima HELMs.
- Database total: **267 ability/spell rules + 14 encounter-state rules**, across **215 indexed encounter entries**.

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

## Verification policy

Rules should be added only when the response is sufficiently supported. Community reaction configs may be used to **discover candidates**, but do not by themselves make a rule verified. Prefer BG-Wiki encounter/bestiary data, official update notes, and corroborated encounter archives.

Do not turn uncertain advice into a confident alert. If a source establishes that a move is dangerous but not the correct response, use a descriptive warning rather than inventing a counter.

## Next research passes

1. Continue Ambuscade V2 from **54 actionable families toward all 67** when precise encounter sources become available. Current indexed-only research targets are Anaximander, Quirinus, Bohun Upas, Celebrant, Delos, Tranquil Treant, Popular Penelope, Gudjewg, Bozzetto Fenrir, Khione, Scithiraptor, Heimdallr, and Kulshedra.
2. Expand Geas Fete from the 8 highest-priority actionable encounters toward the complete 85-entry index, prioritizing mechanics with reliable sources and clear player responses.
3. Add BLU-set-spell capability checks (Sudden Lunge, Blank Gaze, etc.) before surfacing BLU-specific counter prompts.
4. Expand state/message triggers where mechanics happen before a normal `readies` line.
5. Continue into Sortie, Odyssey, Vagary, Dynamis-Divergence, and other endgame systems.
