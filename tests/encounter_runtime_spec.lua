local runtime = dofile('data/encounter_runtime.lua');

local function eq(actual, expected, label)
    if actual ~= expected then error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual))); end
end

local state = runtime.new_state();

runtime.set_aminon_mode(state, 'fire', 'water', 0);
eq(state.objectives.aminon.required, 5, 'Aminon objective requires five hits');
for index = 1, 5 do
    runtime.observe_aminon_element(state, {
        key='aminon_' .. index, type='elemental_hit', element='water', target='Aminon',
    }, index);
end
eq(state.aminon.proc_confirmed, true, 'Aminon fifth matching elemental hit confirms proc');
eq(state.objectives.aminon.status, 'complete', 'Aminon objective completes');

runtime.start_ongo_proc(state, 20);
eq(state.objectives.ongo.required, 2, 'Ongo first cycle requires two bursts');
runtime.observe_ongo_burst(state, { key='ongo_1', type='magic_burst', element='earth' }, 21);
runtime.observe_ongo_burst(state, { key='ongo_2', type='magic_burst', element='earth' }, 22);
eq(state.objectives.ongo.status, 'awaiting_confirmation', 'Ongo burst threshold awaits blue proc');
runtime.mark_ongo_proc(state, 23);
eq(state.ongo.shock_active, false, 'Ongo confirmed proc clears Shock state');
runtime.start_ongo_proc(state, 30);
eq(state.objectives.ongo.required, 3, 'Ongo later cycle requires three bursts');

runtime.observe_circle_pulse(state, 77, 40, { x=10, y=0, z=0 });
local pulse = runtime.nearest_recent_circle_pulse(state, { x=0, y=0, z=0 }, 42, 6);
eq(math.floor(pulse.distance), 10, 'Circle pulse exposes live distance');
eq(runtime.nearest_recent_circle_pulse(state, { x=0, y=0, z=0 }, 47, 6), nil, 'Circle pulse expires');
runtime.schedule_timer(state, { id='bane', label='Bane', interval=240, prewarn=15 }, 100);
eq(#runtime.update_timers(state, 324), 0, 'timer quiet before prewarn');
local events = runtime.update_timers(state, 326);
eq(events[1].kind, 'prewarn', 'timer prewarn');
events = runtime.update_timers(state, 340);
eq(events[1].kind, 'due', 'timer due');
eq(#runtime.update_timers(state, 341), 0, 'timer does not repeat without observed trigger');

runtime.set_aminon_mode(state, 'fire', 'water', 200);
local dt, age = runtime.aminon_dt_estimate(state, 265);
eq(dt, 10, 'Aminon accumulated DT estimate');
eq(age, 65, 'Aminon mode age');
runtime.mark_aminon_proc(state, 270);
dt = runtime.aminon_dt_estimate(state, 400);
eq(dt, 10, 'Aminon estimate freezes after confirmed proc');

runtime.set_bumba_element(state, 'fire', 10);
eq(state.bumba.element, 'fire', 'Bumba manual element');
local bumbaTimer = runtime.start_bumba(state, 'v25', 20);
eq(bumbaTimer.next_at, 80, 'Bumba V25 fetter timer');

runtime.observe_circles(state, 5, 1);
eq(state.circles.reliable, false, 'partial Circle observation is uncertain');
eq(state.circles.cleared, nil, 'partial Circle observation has no false cleared count');
runtime.observe_circles(state, 8, 2);
runtime.observe_circles(state, 5, 3);
eq(state.circles.cleared, 3, 'Circle cleared count after complete observation');
eq(runtime.circle_damage_reduction(state), 50, 'Disjoined DT estimate');

eq(runtime.record_bumba_packet(state, 'a', { signature='a' }), true, 'new Bumba diagnostic');
eq(runtime.record_bumba_packet(state, 'a', { signature='a' }), false, 'duplicate Bumba diagnostic');

eq(runtime.set_shinryu_wings(state, 'spread', 100, 'Meteor'), true, 'Shinryu wing state changes');
eq(runtime.set_shinryu_wings(state, 'spread', 101, 'Meteor'), false, 'repeated wing evidence is not a transition');
eq(state.shinryu.next_shift_at, nil, 'spell evidence does not invent a wing-transition countdown');
runtime.set_shinryu_wings(state, 'down', 110, 'verified-transition');
eq(state.shinryu.next_shift_at, 290, 'verified transition starts the three-minute wing cycle');
runtime.prepare_shinryu_supernova(state, 200);
local doomRows, doomRemaining, pending = runtime.shinryu_doom_rows(state, 201);
eq(pending, true, 'Supernova triage waits for target results');
runtime.observe_shinryu_supernova_targets(state, {
    { id=1, name='Alpha', message=1 }, { id=2, name='Beta', message=2 },
}, 202);
runtime.observe_shinryu_doom(state, 1, 'Alpha', true, 203);
runtime.observe_shinryu_doom(state, 2, 'Beta', false, 204);
doomRows, doomRemaining, pending = runtime.shinryu_doom_rows(state, 205);
eq(#doomRows, 2, 'all Supernova targets retained');
eq(doomRows[1].status, 'doomed', 'confirmed Doom retained');
eq(doomRows[2].status, 'cleared', 'cleared Doom retained');
eq(doomRemaining, 7, 'Doom countdown uses observed action completion');
doomRows = runtime.shinryu_doom_rows(state, 218);
eq(#doomRows, 0, 'expired Doom triage is dismissed');

print('encounter_runtime_spec: all checks passed');
