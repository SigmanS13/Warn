# Warn contextual rule modules

Warn's encounter knowledge is intentionally kept outside `warn.lua` so the database can grow without repeatedly rewriting the addon core.

## Modules

- `catalog.lua` — complete indexed encounter lists, including encounters that still need research
- `generic.lua` — mechanics safe enough to apply regardless of actor
- `ambuscade_v1.lua` — historical Volume 1 rules
- `ambuscade_v2.lua` — historical Volume 2 rules
- `ambuscade_v2_history.lua` — additional verified historical Volume 2 profiles
- `high_tier_battlefields.lua` — HTMB rules
- `missions_bcnms.lua` — original story encounters and classic orb battlefields
- `abyssea.lua` — major Abyssea NM index and verified high-impact mechanics
- `omen.lua` — Omen Glassy mid-boss and Caturae boss rules
- `sortie.lua` — complete Sortie NM/boss index and verified major-boss mechanics
- `odyssey.lua` — complete named Sheol/Gaol NM index and verified high-impact Gaol rules
- `geas_fete.lua` — complete Aeonic-route Geas Fete index and verified high-impact rules
- `dynamis.lua` — classic Dynamis progression-boss index and lethal boss mechanics
- `dynamis_divergence.lua` — four-zone, three-wave Divergence boss index and mechanics
- `sinister_reign.lua` — complete three-wave Sinister Reign roster and mechanics
- `skirmish.lua` — original/Alluvion Skirmish objective and NM index with documented mechanics
- `unity_wanted.lua` — complete Unity Wanted roster and high-impact NM mechanics
- `vagary.lua` — five Vagary mega bosses, elemental responses, and lethal mechanics
- `COVERAGE.md` — progress tracker and research queue

`../rules.lua` loads these modules and merges their `ability_rules`, `state_rules`, and catalog entries.

Warn 3.0 builds a runtime profile index from this same curated data through
`../active_encounter.lua`. Only verified rules contribute automatic actor/action evidence.
Catalog-only entries remain available for manual selection but never become automatic alerts.
If an actor or ability could refer to more than one profile, the runtime must resolve it through
the current profile or request a manual choice; it must not select the first database row.

Verified scripted timers can be attached to an ability rule without turning learned repetition into
a hard countdown:

```lua
timer = {
    id='example_verified_timer', label='EXAMPLE MECHANIC', interval=240, prewarn=15,
    prewarn_message='EXAMPLE MECHANIC IN 15 SECONDS!',
}
```

Use timer metadata only for a documented fixed interval. Runtime state and certainty handling live
in `../encounter_runtime.lua`; learned observations remain uncertain readiness windows.

Reusable live objectives are evidence-gated in `../objective_runtime.lua`. Encounter rules should
start them through small declarative adapters instead of implementing a new progress counter for
each boss. For example, Ongo uses `objective={kind='ongo_fetter_proc'}`; completed packet evidence
advances progress, while a separately observed or manual blue-proc confirmation completes it.

The `0x028` runtime now retains every packet target and every per-target action result. Rules may
continue using `{target}` for the primary target; encounter-specific runtimes can consume the full
`context.targets` collection when a verified party/alliance mechanic requires triage. Raw `0x029`
status observations are parsed separately and must be constrained to a verified encounter window
before they are interpreted as a gain or loss.

After the bundled modules load, Warn can merge the validated data-only database at
`../community.json`. Community entries with an existing stable rule ID replace that bundled rule;
new IDs are appended. The downloaded file is strict JSON and is never executed as Lua.

## Ability/spell rule fields

Common fields:

```lua
{
    id        = 'stable_unique_rule_id',
    content   = 'Ambuscade',
    encounter = 'Example Encounter',
    actor     = 'Example Boss',       -- nil for a genuinely generic mechanic
    actor_aliases = { 'Boss Form II' }, -- optional alternate actor names
    event     = 'readies',            -- readies / uses / starts_casting / casts
    ability   = 'Example Ability',
    aliases   = { 'Old Name' },       -- optional log/resource aliases
    message   = 'MOVE AWAY!',
    severity  = 'critical',           -- critical / danger / important
    prediction = 'reactive',          -- reactive / readiness / scripted
    target_shape = 'radial',          -- self / single / cone / radial / party / gaze / ground
    audience  = { 'everyone' },       -- or one or more responsibility ids
    sound     = 'alarm.wav',
    verified  = true,
    source    = 'https://...',
}
```

Capability prompts can use normal magic or set Blue Magic:

```lua
counter = { type='spell', name='Stun', label='STUN IT!', responsibility='interrupt' }

counters = {
    { type='spell', name='Silence', label='CAST SILENCE!' },
    { type='blu_spell', name='Silent Storm', label='CAST SILENT STORM!' },
}
```

Warn only appends a counter label when its responsibility is enabled and the current character
can actually use it now. Blue Magic counters also require the spell to be currently set.
Critical factual messages remain visible even when the action label is filtered.

## State rules

State rules may be scoped to exact client zone IDs with `zone_ids={...}`. HP transitions use
`type='entity_hp_threshold'` plus `threshold=<percent>` and the read-only Ashita entity HP getter.
Always include a presence/action fallback when the HP sample may arrive after the transition.

State rules cover mechanics that are useful **before** an ability is readied, or aren't represented by a TP move at all. Current types include entity-presence, entity-movement, and maintained-debuff alerts.

Maintained debuffs can use encounter log fragments to track state:

```lua
{
    id='example_silence_maintenance',
    type='debuff_maintenance',
    actor='Example Boss',
    status='Silence',
    message='BOSS NOT SILENCED!',
    loss_message='SILENCE WORE OFF!',
    only_if_counter_available=true,
    counters={ {type='spell',name='Silence',label='CAST SILENCE!'} },
    gain_messages={'boss is silenced'},
    loss_messages={'silence wears off'},
}
```

Use this type only when the encounter exposes reliable state messages; do not estimate a debuff timer when the game provides an explicit state transition.

## Stable IDs matter

User enable/disable choices and per-alert sound overrides are stored by rule ID. **Do not rename an existing rule ID casually.** Change the rule data while preserving its ID unless it is truly a different mechanic.

## Source quality

Reaction addons and community configs are excellent candidate lists, but every rule marked `verified=true` should be corroborated. When the best action is uncertain, prefer a factual warning (`FULL DISPEL INCOMING`) over an unsupported command (`STUN NOW`).
