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
    sound='alarm.wav',
    verified=true,
    source='https://example.com/source',
},
```

## Job-specific counter example

```lua
counter={ type='spell', name='Stun', label='STUN IT!' }
```

Only use a counter when the encounter mechanic supports it. Warn's capability engine decides whether to show the suggestion to the current player.

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
