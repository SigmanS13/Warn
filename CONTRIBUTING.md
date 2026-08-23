# Contributing to Warn

Warn is an Ashita v4 encounter-warning addon created by **Sigman**. Contributions are welcome, especially verified encounter mechanics and corrections.

## Rule principles

1. **Do not guess.** If a mechanic is uncertain, leave it indexed and document what still needs verification.
2. **Prefer actionable alerts.** Warn should tell the player what matters: turn away, move out, stack, stop attacking, dispel, stun, silence, rebuff, etc.
3. **Use actor-specific rules when behavior differs by encounter.** The same ability name can mean different things on different monsters.
4. **Preserve stable rule IDs.** User enable/sound overrides are keyed by rule ID. Changing an existing ID resets that user's customization.
5. **Include provenance.** Every verified rule should include a useful source URL. Community reaction configs are excellent discovery material but should be corroborated before a rule is marked verified.
6. **Do not automate player actions.** Warn is designed to alert and advise; it should not automatically cast spells, move the player, turn the character, or execute combat actions.

## Rule example

```lua
{
    id='example_boss_dangerous_gaze',
    content='Example Content',
    encounter='Example Encounter',
    actor='Example Boss',
    event='readies',
    ability='Dangerous Gaze',
    message='TURN AROUND!\nGAZE PETRIFY',
    severity='critical',
    prediction='reactive',           -- reactive / readiness / scripted
    target_shape='gaze',             -- self / single / cone / radial / party / gaze / ground
    audience={ 'everyone' },
    sound='alarm.wav',
    verified=true,
    source='https://example.com/source',
},
```

## Job-specific counter example

```lua
counter={ type='spell', name='Stun', label='STUN IT!', responsibility='interrupt' }
```

Only use a counter when the encounter mechanic supports it. Warn shows the suggestion only when
the associated responsibility is enabled and its capability engine confirms the action is usable.
Keep the factual mechanic in `message`; keep the assigned call to action in the counter label.

## Testing

Use:

```text
/warn rules
/warn coverage
/warn testrule <rule-id>
/warn debug
```

Before submitting a database change, verify that the addon loads with no Lua error and that new rule IDs are unique.


## Global debuff definitions

Global monster-status tracking is defined in `data/debuffs.lua`, separately from encounter rules.

A debuff definition should have a stable `id`, a display `name`, a category, known gain/loss log
fragments, and an alert policy. Prefer status-result messages over guessing from a spell cast: a
resisted or interrupted spell must not create a false tracked debuff.

When adding a player counter, use only capability types Warn can verify. Current verified types are:

- `spell`
- `blu_spell` (also checks that the Blue Magic spell is currently set)

For log wording that has not been validated on retail, mark the definition `experimental=true`,
leave it disabled by default, and document the wording that still needs live testing.

Use:

```text
/warn debuffs reload
/warn debuffs test <status> <mob>
/warn debuffs lose <status> <mob>
/warn debug
```

to test changes without editing the encounter database.

## Learned readiness observations

Warn's Learning section records local timing evidence, not verified encounter truth. A learned
candidate should only be promoted into the curated rule database after confirming that the
interval is repeatable and understanding any phase, HP, difficulty, or random-usage conditions.

When proposing a learned observation, include the actor, ability, observed intervals, sample count,
content context, and an external verification source when one exists. Do not convert a local
suggestion directly into a verified rule solely because its confidence score is high.

## Community database publication

Reviewed community rules are published as JSON in `community/database.json`; the addon never
executes downloaded Lua. The database supports `ability_rules`, `state_rules`, and `catalog`
arrays using the same stable fields documented above. Every published rule must have
`verified: true` and an HTTPS provenance source.

Before publishing a new database version:

1. Increase the integer `database_version` in both the database and manifest.
2. Set the publication timestamps.
3. Recalculate the database file's exact SHA-256 and place it in `community/manifest.json`.
4. Set the manifest rule and encounter counts to the exact JSON array totals.
5. Run `tests/community_spec.lua` and parse every Lua file.

Do not publish executable code, local learned observations, user settings, or unreviewed timer
guesses through the community database channel.
