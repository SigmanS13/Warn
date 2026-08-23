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
    abilities.txt
    community.json
    community.lua
    debuffs.lua
    json.lua
    mechanics.lua
    sha256.lua
    timer_learning.lua
    rules.lua
    rules/
      catalog.lua
      generic.lua
      ambuscade_v1.lua
      ambuscade_v2.lua
      high_tier_battlefields.lua
      COVERAGE.md
  sounds/
    *.wav
  themes/
    vana_tactical/
      theme.txt
      launcher.png
  ui/
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

- **Encounters** — a metadata-driven browser for verified mechanics, plus a collapsed **Custom Watches** fallback
- **Options** — Responsibilities, Learning, Database, Debuffs, Alerts, Appearance, and Sound

The default configuration is intended to work without setup; advanced customization is optional.

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

Live messages use three visual levels: **Important**, **Danger**, and **Critical**. The warning
card's background opacity is independently adjustable under **Options → Appearance**; lowering
it does not dim the alert text or the critical screen-edge cue. Card size, edge intensity,
duration, and Reduced Motion are configurable separately, with test buttons for every level.
The positioning preview appears only when explicitly requested and closes automatically when
leaving Appearance; **Reset Warning Position** restores its normal placement.

Advanced theme overrides are data-only. A custom `theme.txt` and optional `launcher.png` can
be placed in `Ashita/config/addons/warn/themes/<name>/`; theme files cannot execute Lua.

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

## Job-specific counters

The current verified capability engine supports normal magic and Blue Magic. A spell suggestion is
only appended when Warn confirms that the current character knows the spell, the current
main/sub job can cast it at its level, there is enough MP, and the spell is off recast. For
Blue Magic, Warn additionally verifies that the spell is currently set before recommending it.

Mechanical capability is not the same as a party assignment. **Options → Responsibilities**
stores a separate background profile for each character and main job/subjob combination. A
counter instruction appears only when its responsibility is enabled and Ashita confirms the
action is currently available. Critical factual mechanic warnings remain visible regardless
of responsibility settings.

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
