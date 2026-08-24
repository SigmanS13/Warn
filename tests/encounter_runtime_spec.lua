local runtime = dofile('data/encounter_runtime.lua');

local function eq(actual, expected, label)
    if actual ~= expected then error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual))); end
end

local state = runtime.new_state();
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

print('encounter_runtime_spec: all checks passed');
