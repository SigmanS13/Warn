# warn — Ashita v4 encounter warning addon

Created by **Sigman**.

`warn` is a configurable FFXI encounter assistant for Ashita v4. It retains a manual
ability watch list, but also supports automatic contextual encounter rules that can tell
you what to do when a known mechanic occurs.

## Install

Place the folder at:

```
Ashita/addons/warn/
```

Expected layout:

```
warn/
  warn.lua
  README.md
  CHANGELOG.md
  CONTRIBUTING.md
  data/
    action_packet.lua
    status_packet.lua
    abilities.txt
    community.json
    community.lua
    debuffs.lua
    json.lua
    mechanics.lua
    active_encounter.lua
    alert_guard.lua
    encounter_runtime.lua
    sha256.lua
    timer_learning.lua
    rules.lua
    rules/
      catalog.lua
      generic.lua
      ambuscade_v1.lua
      ambuscade_v2.lua
      ambuscade_v2_history.lua
      geas_fete.lua
      high_tier_battlefields.lua
      omen.lua
      sortie.lua
      odyssey.lua
      skirmish.lua
      unity_wanted.lua
      vagary.lua
      COVERAGE.md
  sounds/
    *.wav
  themes/
    vana_tactical/
      theme.txt
      launcher.png
  ui/
    encounter_browser.lua
    theme.lua
    textures.lua
    portraits.lua
  community/
    manifest.json
    database.json
```

Load or reload with:

```
/addon load warn
/addon reload warn
```

The GUI has two top-level areas:

- **Encounters** — the live Current Encounter card, a metadata-driven browser for verified mechanics, manual encounter fallback, and a collapsed **Custom Watches** fallback
- **Options** — Roles, Learning, Database, Debuffs, Alerts, Appearance, and Sound

The Encounters category pane supports independent `[+] / [-]` sections plus **Collapse All**
and **Expand All**. It shows only groups containing verified alerts by default. Enable
**Show Indexed-Only Groups** to inspect cataloged research targets that do not yet generate
warnings; those entries are labeled explicitly so an empty result cannot be mistaken for a
loading failure.

The default configuration is intended to work without setup; advanced customization is optional.

## Warn 3.0 active encounters

Warn automatically recognizes a known boss from verified entity names and incoming actions. A
nearby recognized boss is labeled **Auto / Nearby**; a matching verified action upgrades that
profile to **Auto / Confirmed**. The Current Encounter card and compact HUD then show only that
profile's most urgent verified mechanics and the responses assigned to, and currently usable by,
this character.

Automatic detection does not turn the encounter index into an alert database. Catalog-only
encounters can be selected manually for reference, but display **Indexed only — no verified
automatic alerts**. Unknown abilities are linked to the active encounter in local Learning data
and remain non-actionable until they are curated and independently verified. When multiple
profiles match the evidence, Warn asks for a manual choice instead of guessing.

The encounter clears immediately when zoning and automatically after its verified actors have
been absent for the configurable grace period. Manual selections remain active until the player
clears them or zones. Detection, the tactical HUD, and the encounter-end grace are available under
**Options → Alerts**.

Warn reads hostile action starts directly from incoming packet `0x028`, independently of chat
formatting. **Options → Alerts → Action Packet Layout** defaults to Auto and supports both the
retail / XiPackets header and the legacy target-count header used by SimpleLog and many
DSP-based servers. A manual layout override is available for unusual server implementations.

## Interface and live alerts

Warn ships with a Vana'diel tactical interface: deep indigo panels, brass details, engraved
corner accents, and a small **W** launcher. Click the launcher to open or close Warn, or drag
it normally to reposition it. It can be resized, reset, or hidden under
**Options → Appearance**.

The interface can scale automatically from display height, or use explicit **1440p**,
**1080p**, and custom scale presets. Controller navigation is available while Warn is open:
shoulder buttons switch **Encounters / Options**, the D-pad navigates the current area, and
the layout-specific back button closes the dashboard. These controls are only consumed while
the dashboard is open.

Live messages use ornate stepped indigo frames with twin brass rails, engraved diamonds, a
Warn crest, and three visual levels: **Important**, **Danger**, and **Critical**. A slim inlaid
rail shows how long the notification will remain visible. The warning card's background opacity
is independently adjustable under **Options → Appearance**; lowering it does not dim the alert
text, brass frame, or critical screen-edge cue. Card size, edge intensity, duration, and Reduced
Motion are configurable separately, with test buttons for every level.
The positioning preview appears only when explicitly requested and closes automatically when
leaving Appearance; **Reset Warning Position** restores its normal placement.

**Options → Appearance** also provides screen-aware layout buttons for the nine common screen
regions plus **Center Horizontally** and **Center Vertically**. Anchored layouts stay aligned when
switching between 1080p, 1440p, or custom interface scaling. Dragging the preview or editing X/Y
returns the card to Custom placement. Critical cards use the same selected placement while keeping
their screen-edge effect.

The dashboard starts at a large 1320×1080 baseline on a fresh installation, capped to the current
display, and preserves later manual resizing. **Keep Warn Dashboard Above Other Addons** is enabled
by default; disable it under Appearance when another addon's controls need to appear over Warn.

## Notification burst protection

Warn displays one notification card at a time. Rapid duplicates from an AoE event are coalesced
into that card and do not replay their sound. Distinct mechanics wait in a small priority-aware
queue: Critical interrupts Danger or Important, queued alerts expire after six seconds, and the
queue is capped at four by default. Global debuff batches are also deduplicated and hard-capped.
These limits prevent a large packet/result burst from producing unbounded work or stale alert spam.

Burst protection is enabled by default. **Options → Alerts** exposes the repeat-suppression window,
maximum queue size, current queue depth, and session suppression/drop counts. Disabling it restores
the original single-card overwrite behavior but still does not create multiple notification windows.

Advanced theme overrides are data-only. A custom `theme.txt`, optional `launcher.png`, and
optional `roles/shield.png`, `roles/potion.png`, `roles/bow.png`, and `roles/harp.png` can be
placed in `Ashita/config/addons/warn/themes/<name>/`; theme files cannot execute Lua.

## Main commands

- `/warn` — open/close GUI
- `/warn <Ability Name>` — add a manual warning
- `/warn off <Ability Name>` — remove a manual warning
- `/warn list` — list manual warnings
- `/warn clear` — clear manual warnings
- `/warn test <Ability Name>` — test the normal warning overlay
- `/warn debug` — parser/state debug output
- `/warn rules` — show contextual rule counts
- `/warn testrule <rule id>` — test a contextual alert
- `/warn capability <spell>` — check whether a normal or Blue Magic spell is usable right now
- `/warn sounds` — rescan `sounds\` for WAV files
- `/warn rule <rule id>` — open the GUI with a specific contextual rule selected
- `/warn rule reset <rule id>` — remove that rule's user overrides
- `/warn teststate <rule id> <gained|lost>` — simulate a maintained-debuff state change
- `/warn debuffs` — list currently tracked global monster debuffs
- `/warn debuffs clear` — clear all global debuff state
- `/warn debuffs preset <recommended|cc|all|off>` — quick global-debuff setup
- `/warn debuffs test <status> [mob]` — simulate a debuff application
- `/warn debuffs lose <status> [mob]` — simulate that tracked debuff ending
- `/warn debuffs soon <status> [mob]` — simulate the estimated pre-expire warning
- `/warn debuffs reload` — reload `data/debuffs.lua`

## Custom sounds

Drop any standard `.wav` file into `warn\sounds\` and click **Refresh Sounds** (or run
`/warn sounds`). **Options → Sound** controls the global/manual warning sound.

The same panel also controls the optional **First GUI Open** cue. It defaults to
`firstopen.wav` and plays only when Warn's GUI is opened for the first time in the current FFXI
process. Closing and reopening the window—or unloading and reloading Warn—does not replay it. A
separate **Test First-Open Sound** button lets you audition the selected file without changing that
per-launch state.

Verified mechanics that call for immediate player healing use `healme.wav` by default. This does
not include enemy self-heals, Zombie/stop-healing mechanics, or encounter instructions where
`/heal` means kneeling. As with every contextual alert, an individual rule's sound can still be
overridden from **Encounters**.

## Per-encounter / per-alert sounds

Open `/warn` → **Encounters**. The Encounter Alerts list is searchable. Select any contextual
rule and choose an **Alert Sound Override**:

- **Default (...)** — use Warn's built-in default for that mechanic
- **None** — make only this mechanic silent
- Any WAV in your `sounds\` folder — use that sound only for this mechanic

Overrides persist separately from `rules.lua`, so database updates do not erase your sound
choices. You can also disable individual automatic alerts without editing the database.

## Contextual rule database

The rule database is split into modules under `data/rules/`. This is intentional: broad FFXI
coverage is a data-curation project and each content family can grow independently.

Current shipped rules are a verified starter set, not a claim of complete FFXI coverage.
Rules should preserve source/provenance metadata and should not guess whether a move is
stunnable, silenceable, avoidable, etc.

The v3.0 bundled database contains **490 ability/spell rules, 29 encounter-state rules, and
512 indexed encounter entries**. Historical Ambuscade Volume 2 has 54 actionable families out
of 67 indexed families. All 30 indexed HTMB categories have direct rules or inherited actor rules,
and all 85 encounters on the Geas Fete Aeonic route are indexed. Sortie includes all 17 named
sector NMs and bosses. Odyssey includes 67 named Sheol/Gaol NMs plus the shared Mimic hazard.

## v2.12 Abyssea, missions, and Alluvion

Abyssea now indexes 39 major encounters across its nine zones. Twenty-six alerts focus on mechanics
that materially change what a player should do: Glavoid and Amphitrite absorption, Kukulkan gaze
states, Cirein-croin and Rani Charm, Briareus Zombie, Resheph and Cirein-croin HP-to-1 hate resets,
and other high-impact cleanse, interrupt, and positioning calls. Indexed-only NMs remain clearly
marked research targets and never produce unverified warnings.

The Missions & BCNMs category indexes 42 milestone and classic battles. Unique original mechanics
now cover the Ancient Vows Mammets, Diabolos in Darkness Named, Snoll Tzar, original Alexander, and
Up in Arms. Warn's existing actor-based HTMB rules already recognize shared actors such as Shadow
Lord, the Ark Angels, Eald'narche, Ouryu, Ultima, Tenzen, Promathia, and Cloud of Darkness during
their original encounters, so they are not duplicated into a second runtime rule set.

Alluvion Skirmish now covers the four Rala Mistmaws, the four Cirdas Mistmaws, Balamor's Adumbration,
Yorcia Stronghold defense, and floor progression. Windrender and Living Cairn observations provide
lightweight objective reminders, including the important instruction to continue before using the
Fenestral Key when the group wants the secondary Mistmaw rewards.

Fresh installations enable sound and select `msg.wav` by default. Upgrades keep the user's saved
choice. Every valid WAV placed in `sounds` is discovered automatically, including filenames with
spaces, so the additional bundled effects are available in the sound selector and per-rule overrides.

## v2.11 reusable live objectives

Warn now has one evidence-gated objective component rather than bespoke progress counters for every
boss. Ongo uses it for Crashing Thunder: completed Earth Magic Bursts advance a cycle-aware two-then-
three burst objective, but the hazard remains active until the blue proc is explicitly confirmed.
Aminon's six modes use the same component for their five consecutive counter-element hits; damaging
wrong-element spells reset the displayed sequence.

Kirin now receives a 52% transition prewarning in Escha - Ru'Aun, with Kouryu's appearance as the
authoritative fallback. The warning prepares the alliance for the 50% transformation, full enmity
reset, initial popper target, and Terror protection without affecting classic Kirin elsewhere.

Dynamis - Divergence Circle proximity is pulse-aware. The compact HUD shows distance only after an
actual Circle action is observed and dismisses that proximity evidence after six seconds. A player
within 45 yalms receives the stylized critical edge/card cue; idle Circle entities do not create a
constant range overlay.

## v2.10 multi-target tactical state

Warn now preserves packet target identity for contextual alerts. Ou's Target warning names the
affected player when the incoming action packet exposes that target, and its previously missing
65% Chainspell event is included.

Verified encounter timers are separate from learned readiness estimates. Aminon's observed Bane
of Tartarus starts a documented four-minute timer with a 15-second prewarning; its six elemental
modes populate a compact tactical HUD with the correct response, mode age, and a clearly labeled
current-mode damage-reduction estimate. v2.11 adds evidence-gated five-hit progress from completed
elemental-damage packets while retaining manual confirmation controls.

Bumba has a Vengeance-aware fetter timer, manual absorbed-element selector, 60-second element-check
cue, and an opt-in in-memory packet signature recorder for future automatic dust-color validation.
The manual selector is the authoritative fallback until a stable retail signature is verified.

Dynamis - Divergence now counts live Elemental Circle entities. It reports cleared progress and the
corresponding Disjoined-boss damage reduction only after all eight Circles have been observed;
partial entity visibility is labeled uncertain instead of being converted into a false clear count.
The compact HUD is optional, positionable, and has independent opacity under Appearance.

Incoming action packets now retain every target and every per-target result rather than only the
first. Shinryu uses this foundation for Supernova: the tactical HUD lists all exposed party/alliance
targets, marks confirmed Doom and observed clears from `0x029` status evidence, and leaves targets
without authoritative status evidence labeled **CHECK DOOM**. Meteor and Comet also confirm the
current wings-spread absorption stance or wings-down damage window. Warn does not start a false
three-minute countdown from those spells because they prove the stance, not the exact transition time.

## v2.8 Skirmish, Unity Wanted, and Vagary

Skirmish originally shipped a 21-entry foundation. v2.12 expands this to 22 entries and adds
verified rules for the complete Rala Mistmaw set, Balamor, and Rala/Cirdas floor progression on top
of the original Rala hazards, four Cirdas Mistmaws, and Yorcia Stronghold-defense objective.

Unity Wanted now has all 56 Wanted NMs organized by level and Wanted category. Twenty-nine alerts
cover the most actionable documented mechanics, including hate resets, Charm, Doom, mine detonation,
buff/food removal, lethal breath attacks, Fulmination, and Tumult Curator's multi-phase threats.

Vagary indexes Palloritus, Putraxia, Rancibus, Perfidien, and Plouton. Its 28 alerts cover Doom,
Death, debilitating auras, full dispels, hate resets, and the documented elemental-response modes
for both hidden mega bosses. Putraxia also receives a once-per-spawn explanation of its initial
elemental absorption system.

## v2.7 Dynamis, Sinister Reign, and Geas Gods

Classic Dynamis now has a focused 26-entry progression-boss index spanning all ten zones: city,
Beaucedine, Xarcabard, Dreamworld, and Tavnazia bosses plus their Arch counterparts. Its initial
alerts emphasize instant-death, Terror, Charm, severe breath, buff-wipe, and Diabolos mechanics.

Dynamis - Divergence indexes all twelve Wave 1-3 bosses across the four cities plus Aurix. Direct
alerts cover the four Wave 2 bosses, while Wave 3 Disjoined bosses remind the alliance to clear
elemental circles before committing damage. These are kept separate from classic Dynamis in the
browser because their encounter structure and preparation needs are different.

Sinister Reign indexes all nine possible opponents by wave. Verified rules cover Darrcuiln,
Ingrid, all three Wave 2 opponents, and all three Wave 3 opponents, including Arciela's mode
switches and Naakual summon, Rosulatia's Charm sequence, Sajj'aka's Denounce, and August's
Daybreak / No Quarter sequence.

Geas Fete retains its complete 85-entry Aeonic index and adds Zi'Tah HELM and Ru'Aun god alerts:
the Alpluachra Pixie trio, Pazuzu, Wrathare, Byakko, Genbu, Seiryu, Suzaku, and Kirin/Kouryu. Blazewing stays
indexed-only because the currently documented proc behavior is not reliable enough for a confident
player-facing instruction.

## Job-specific counters

The current verified capability engine supports normal magic and Blue Magic. A spell suggestion is
only appended when Warn confirms that the current character knows the spell, the current
main/sub job can cast it at its level, there is enough MP, and the spell is off recast. For
Blue Magic, Warn additionally verifies that the spell is currently set before recommending it.

Mechanical capability is not the same as a party assignment. **Options → Roles**
stores a separate background profile for each character and main job/subjob combination. A
counter instruction appears only when its role or special assignment is enabled and Ashita confirms the
action is currently available. Critical factual mechanic warnings remain visible regardless
of role settings.

Additional capability types (job abilities, items, songs, etc.) should be added only after
their Ashita v4 availability checks are verified.

## v2.0 encounter intelligence and reactive recognition

Warn classifies mechanics along independent axes: prediction model, severity, target shape,
and audience. Existing rules safely default to **Reactive**, **Shape Unspecified**, and
**Everyone** until reviewed metadata is added.

Incoming action packet `0x028` is observed passively for monster-skill and spell-start
recognition. Warn never modifies, blocks, injects, or responds to a packet with an automated
player action. Verified rules may alert immediately; unknown abilities only feed local Learning
evidence unless the player explicitly enables a Custom Watch.

The Custom Watches catalog is populated from Ashita's local monster-ability resources. The
packaged `data/abilities.txt` list is retained only as an offline compatibility fallback.

## v2.6 Sortie, Odyssey, and Omen audit

Sortie now indexes all eight sector NMs, all eight A-H major bosses, and Aminon. Its actionable
rules emphasize elemental-response changes, Taint and water-absorption hazards, stack mechanics,
lethal scripted attacks, full dispels, Doom, equipment removal, and Reraise removal. Hidden chest
objectives remain outside the rule engine because Warn cannot yet track their complete state from
combat actions alone.

Odyssey now indexes all named NMs in Sheol A, B, and C, the shared Mimic hazard, and all 17 Sheol
Gaol bosses. The initial actionable layer covers Death Trap / Hell Trap and every Atonement 3-4
boss, where proc windows, fetters, dangerous positioning, full dispels, hate resets, and lethal
abilities benefit most from immediate recognition. Lower Sheol and Atonement 1-2 encounters remain
indexed for future verified curation rather than receiving generic family warnings.

Omen's existing module was audited and remains complete at three Glassy mid-bosses, six Caturae
bosses, and 27 verified alerts. Its fixed HP-gate classifications and reaction rules did not need
replacement or duplication.

## v2.5 database expansion

Historical Ambuscade Volume 2 now has 54 actionable encounter families. Thirty-one formerly
catalog-only battles gained verified mechanics; the remaining 13 stay visible as research targets
without generating speculative alerts.

Head Wind and Legacy of the Lost complete the remaining HTMB research pass. Divine Might continues
to reuse the five Ark Angel actor profiles, so those alerts work in both the individual battles and
the combined battlefield.

Geas Fete now includes a complete 85-encounter Aeonic-route index across Escha - Zi'Tah, Escha -
Ru'Aun, and Reisenjima. The first 24 actionable rules cover Warder of Courage and all seven
Reisenjima HELMs; lower-tier Geas encounters remain indexed for careful future curation.

## v2.4 encounter expansion

Omen has a dedicated data module covering Glassy Craver, Glassy Gorger, Glassy Thinker,
Fu, Kyou, Kei, Gin, Kin, and Ou. Scripted HP-gate mechanics are labeled separately from
ordinary reactive TP moves so the interface does not present uncertain behavior as a timer.

The Shadow Lord profile warns for both immunity switches plus Giga Slash, Bowels of Agony,
Implosion, and Firaja. Because incoming action packets are independent of chat formatting,
Implosion can be recognized even though its action name is not printed in the normal battle log.
Puppet in Peril covers Lancelord Gaheel Ja's most actionable documented mechanics.



## v1.5 database expansion

`/warn coverage` prints indexed encounter counts. v1.5 keeps the complete historical Ambuscade V1/V2 and HTMB catalogs, substantially expands verified Volume 2 mechanics, and broadens HTMB coverage across Ark Angels, Kam'lanaut, Shadow Lord, Ouryu, Eald'narche, avatars, Fenrir and Diabolos.

Encounter rules remain data-driven under `data/rules/`; user sound overrides are stored separately so rule-database updates do not overwrite personal alert choices.

## Contributing encounter rules

See `CONTRIBUTING.md` and `data/rules/README.md`. New rules should use a stable unique `id`, identify the actor/event/ability precisely, give a short actionable message, and include a verification source. Unknown or uncertain mechanics should remain indexed rather than guessed.


## Global Debuff Engine

v1.6 replaces the separate Sleep and Petrify subsystems with one data-driven **Global Debuff Engine**.

For normal use there is almost nothing to configure: open `/warn` → **Debuffs** and leave the
**Recommended** preset enabled. Warn watches hostile monsters throughout the loaded area, not just
your current target, and remembers status applications confirmed by the combat log.

The Recommended preset currently covers:

- **Crowd control:** Sleep, Petrify, Bind, Gravity
- **Smart maintenance:** Silence, Paralyze, Slow, Addle, Blind

Poison and additional maintenance effects such as Dia, Bio, Elegy, Distract and Frazzle are present
as optional/advanced definitions. The advanced effects are disabled by default while more live
retail log variants are collected.

### Smart reapply alerts

Crowd-control loss is important even if your character cannot personally reapply it, so Sleep,
Petrify, Bind and Gravity warn immediately.

Maintenance debuffs use **Smart Reapply Alerts** by default. If Silence, Paralyze, Slow, Addle or
Blind wears off, Warn checks the current character first. When possible it verifies:

- the spell is learned;
- the current main/subjob can use it;
- enough MP is available;
- the spell is off recast;
- for Blue Magic, that the spell is actually set.

If the effect wears off while your counter is temporarily unavailable, Warn can defer the alert
and fire it when a configured counter becomes usable, unless another player has already reapplied
the debuff.

### Simple UI, advanced controls

The Debuffs tab has four quick presets:

- **Recommended** — normal zero-setup mode
- **Crowd Control** — Sleep/Petrify/Bind/Gravity only
- **All Supported** — enable every shipped definition, including experimental maintenance entries
- **Off** — disable individual global status tracking

Enable **Show Advanced Debuff Options** for per-status controls. Each status can have its own
enabled state, smart/always alert behavior, custom WAV sound, test alert and tracked-state reset.

All custom sounds already placed in `warn\sounds\` are available as per-debuff alert sounds.

### Data-driven status definitions

Global status behavior lives in:

```text
warn/data/debuffs.lua
```

A definition contains its stable id, display name, category, known combat-log gain/loss forms,
recommended response and available player counters. This means future statuses can be added or
refined without creating another one-off tracker inside `warn.lua`.

Near-simultaneous losses are batched. If several slept adds wake together, for example, Warn
produces one grouped wake warning rather than repeatedly replacing the overlay and replaying the
sound.

Dead/despawned monsters are removed silently, and all global debuff state clears on zoning.

### Commands and compatibility

```text
/warn debuffs
/warn debuffs clear
/warn debuffs preset recommended
/warn debuffs preset cc
/warn debuffs preset all
/warn debuffs test sleep Bozzetto Scoundrel
/warn debuffs lose sleep Bozzetto Scoundrel
/warn debuffs reload
```

The older `/warn sleep ...` and `/warn petrify ...` commands remain as compatibility aliases and
now operate through the same Debuff Engine.


## v1.7 tracked debuff timers

Warn now keeps an estimated timer for tracked global debuffs when the status definition provides a duration. These timers are deliberately **advisory**:

- a positive countdown such as `~0:42` means the effect is believed active and the estimate has not expired;
- `? +12s` means the estimate has expired, but Warn has not seen a real wear-off/removal packet yet;
- a real 0x029 status-loss packet or recognized loss text still removes the tracked state and triggers the normal loss alert.

This avoids the XIUI-style failure mode where an icon disappears solely because a guessed timer ended. Warn keeps showing the debuff as uncertain until better evidence arrives.

Crowd-control statuses such as Sleep, Petrify, Bind and Gravity can also warn shortly before their estimated expiry. The default is 5 seconds. Configure this in `/warn` → **Debuffs**:

- **Show Estimated Durations**
- **Warn Before Crowd Control Expires**
- global seconds-before-expiry slider
- per-status estimated duration and per-status pre-expire toggle in Advanced options

Test with:

```text
/warn debuffs test sleep Test Monster
/warn debuffs soon sleep Test Monster
/warn debuffs lose sleep Test Monster
```

## v1.8 automatic timer learning

Warn can now learn repeated encounter timing while you play. It observes hostile
`actor + ability` pairs, suppresses duplicate ready/use lines, and compares the recent
intervals. After three consistent uses, a candidate appears in **Options → Learning**.

Learning follows a review-first safety model:

```text
Observe repeated action
        ↓
Confidence-scored suggestion
        ↓
Accept Readiness Window / Keep Observing / Ignore
        ↓
Uncertain personal readiness window only
```

Unreviewed observations never create alerts. Accepted observations display the observed
earliest/latest readiness range after the next use; they are never presented as hard countdowns.

Learned evidence is stored locally in `warn_learning` settings, separately from the curated
rule database. Warn does not upload or submit observations automatically.

## v1.9 community database updates

Open **Options → Database** to check for reviewed encounter-data updates. Warn checks at most
once per day when its GUI opens by default, but it never installs an update without approval.

The update path is data-only:

```text
Official manifest
        ↓
Windows-validated HTTPS + restricted official database URL
        ↓
2 MB limit + SHA-256 verification
        ↓
Strict JSON schema validation
        ↓
Backup current database
        ↓
Install and reload encounter rules
```

Downloaded files cannot execute Lua or replace `warn.lua`. Community rules merge by stable rule
ID, allowing the reviewed database to add rules or correct bundled rules. Personal sound choices,
disabled alerts, normal settings and learned timers remain separate.

If an update behaves unexpectedly, use **Roll Back Database** in the same tab to exchange the
installed database with its most recent validated backup.

## Maintained debuff alerts

Warn can track encounter-specific debuffs when the fight exposes reliable state messages. For the Meeble Ambuscade, Bozzetto Breadwinner's Silence rule now:

- warns when Breadwinner appears only if your current job/subjob has an immediately usable way to apply Silence;
- supports the normal **Silence** spell plus **Silent Storm** / **Chaotic Eye** for BLU, but only when the BLU spell is actually set;
- treats the encounter's projecting/cries messages as confirmation that Silence is active;
- watches for the encounter message that Breadwinner's throat is no longer scratchy, then immediately warns to reapply Silence if one of your current counters is usable;
- keeps the same stable rule id (`ambu_meeble_breadwinner_silence`), so existing per-alert sound overrides continue to apply.

Debug/testing commands:

```text
/warn capability Silence
/warn capability Silent Storm
/warn capability Chaotic Eye
/warn teststate ambu_meeble_breadwinner_silence lost
/warn teststate ambu_meeble_breadwinner_silence gained
```


## Critical crowd-control alerts

Sleep and Petrify loss are treated as critical crowd-control events by default. When a tracked hostile monster wakes up or loses Petrification, Warn uses a dedicated large center-screen alert and plays the configured debuff sound. These alerts are independent from the manual ability-warning sound toggle.

In **Debuffs**, the simple controls are:

- **Play Debuff Alert Sounds** — enabled by default.
- **Center Critical Crowd-Control Alerts** — enabled by default for Sleep/Petrify.

Sleep and Petrify default to `alarm.wav`. Advanced per-status sound overrides still allow any WAV in `warn/sounds/`, or `None` to intentionally silence that status.

The configuration window is resizable as of v1.6.1. If a tab needs more room, drag the window larger; long Debuff content remains inside a scrolling child region.


### Reliable debuff-loss detection

Warn uses FFXI incoming battle-message packet `0x029` as the primary signal when a tracked debuff wears off. This avoids relying only on visible combat-log wording or chat-filter settings. The text parser remains as a fallback and for discovering gain states.
