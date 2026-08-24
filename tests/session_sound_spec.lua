local engine = dofile('data/session_sound.lua');

local cfg = {
    first_open_enabled = true,
    first_open_selected = 'firstopen.wav',
    first_open_session = '',
};

local play, filename, consumed = engine.consume(cfg, '100:20:30');
assert(play == true and filename == 'firstopen.wav' and consumed == true,
    'first GUI open should consume and play the configured cue');

play, filename, consumed = engine.consume(cfg, '100:20:30');
assert(play == false and filename == nil and consumed == false,
    'same FFXI process must never replay the cue');

play, filename, consumed = engine.consume(cfg, '101:21:31');
assert(play == true and filename == 'firstopen.wav' and consumed == true,
    'a new FFXI process should allow one new cue');

local disabled = {
    first_open_enabled = false,
    first_open_selected = 'firstopen.wav',
    first_open_session = '',
};
play, filename, consumed = engine.consume(disabled, '200:40:50');
assert(play == false and consumed == true and disabled.first_open_session == '200:40:50',
    'disabled cue should still consume this launch so enabling it later cannot surprise the player');

disabled.first_open_enabled = true;
play, filename, consumed = engine.consume(disabled, '200:40:50');
assert(play == false and consumed == false, 'enabling after the first GUI open must not replay the cue');

print('session_sound_spec: first-open cue is process-scoped and reload-safe');
