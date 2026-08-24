# Warn contextual rule modules

Warn's encounter knowledge is intentionally kept outside `warn.lua` so the database can grow without repeatedly rewriting the addon core.

## Modules

- `catalog.lua` — complete indexed encounter lists, including encounters that still need research
- `generic.lua` — mechanics safe enough to apply regardless of actor
- `ambuscade_v1.lua` — historical Volume 1 rules
- `ambuscade_v2.lua` — historical Volume 2 rules
- `ambuscade_v2_history.lua` — additional verified historical Volume 2 profiles
- `high_tier_battlefields.lua` — HTMB rules
- `omen.lua` — Omen Glassy mid-boss and Caturae boss rules
- `sortie.lua` — complete Sortie NM/boss index and verified major-boss mechanics
- `odyssey.lua` — complete named Sheol/Gaol NM index and verified high-impact Gaol rules
- `geas_fete.lua` — complete Aeonic-route Geas Fete index and verified high-impact rules
- `COVERAGE.md` — progress tracker and research queue

`../rules.lua` loads these modules and merges their `ability_rules`, `state_rules`, and catalog entries.

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
