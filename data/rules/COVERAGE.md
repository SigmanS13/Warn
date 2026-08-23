# Warn encounter database coverage — v1.5.0

This file tracks **index coverage** separately from **verified actionable-rule coverage**. An encounter being indexed means Warn knows it belongs in the research set; it does **not** imply every mechanic has been verified yet.

## Indexed encounter sets

- Ambuscade Volume 1: **24/24 historical encounter families indexed**
- Ambuscade Volume 2: **67/67 historical encounter families indexed**
- High-Tier Mission Battlefields: **30/30 BG-Wiki HTMB categories indexed**

## Verified actionable coverage in v1.5

- Ambuscade Volume 1: **24 encounter families** have one or more contextual rules/state alerts.
- Ambuscade Volume 2: **23 encounter families** now have one or more contextual rules/state alerts.
- HTMB: **27 of the 30 categories** have direct encounter rules. **Divine Might** also benefits from the individual Ark Angel actor rules, because Warn matches those bosses by actor name regardless of which Ark Angel battlefield they appear in.
- Database total: **169 ability/spell rules + 9 encounter-state rules**.

### Major Volume 2 additions

Durga, Sowl Devourer, Kauri, Yartsa Gunbu, Gwas-y-neidr, Alluttu, All-Watcher, Natsilane, Chelone, Thillloab, Mnyiri, Sombra Dragon, Bozzetto Bombs, Bozzetto Jody/Julika/Vivian, Pamola, Enigmatic Hypnotist, Lancer Jack, Vengeful Citrullus, Lycaon, Chorister, and Bozzetto Adamantoise.

### Major HTMB additions

- All five individual Ark Angels
- Return to Delkfutt
- The Shadow Lord Battle
- The Savage
- The Celestial Nexus
- All six elemental Avatar Prime trials
- The Moonlit Path
- Waking Dreams
- Waking the Beast
- Existing rules for Cloud of Darkness, Lilith, Odin, Alexander, Cait Sith, Shinryu, Ultima, Promathia, and Tenzen remain intact

## Remaining high-priority HTMB research

The main HTMB categories still lacking their own direct rule set are:

1. Head Wind
2. Legacy of the Lost
3. Puppet in Peril

Divine Might is indexed separately but already inherits the five Ark Angel actor-specific rule sets.

## Verification policy

Rules should be added only when the response is sufficiently supported. Community reaction configs may be used to **discover candidates**, but do not by themselves make a rule verified. Prefer BG-Wiki encounter/bestiary data, official update notes, and corroborated encounter archives.

Do not turn uncertain advice into a confident alert. If a source establishes that a move is dangerous but not the correct response, use a descriptive warning rather than inventing a counter.

## Next research passes

1. Continue Ambuscade V2 from **23 actionable families toward all 67**, prioritizing encounters with documented lethal/gaze/charm/phase/add mechanics.
2. Finish Head Wind, Legacy of the Lost, and Puppet in Peril HTMB rules.
3. Add BLU-set-spell capability checks (Sudden Lunge, Blank Gaze, etc.) before surfacing BLU-specific counter prompts.
4. Expand state/message triggers where mechanics happen before a normal `readies` line.
5. After Ambuscade + HTMB mature, move into Omen, Sortie, Odyssey, Vagary, Geas Fete, Dynamis-Divergence, and other endgame systems.
