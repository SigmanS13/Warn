local guard = dofile('data/alert_guard.lua');

local function eq(actual, expected, label)
    if actual ~= expected then error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual))); end
end

local state = guard.new_state();
local options = { dedupe_window=1.25, queue_limit=3, max_age=5 };
local active = { firing=true, severity='danger' };

local decision = guard.submit(state, { rule_id='aoe', severity='danger' }, active, 10, options);
eq(decision, 'queued', 'first AoE result queues');
decision = guard.submit(state, { rule_id='aoe', severity='danger' }, active, 10.1, options);
eq(decision, 'suppressed', 'rapid duplicate suppressed');
eq(#state.queue, 1, 'duplicate does not grow queue');
decision = guard.submit(state, { rule_id='active_move', severity='danger' },
    { firing=true, severity='danger', rule_id='active_move' }, 10.2, options);
eq(decision, 'suppressed', 'currently displayed card cannot queue a duplicate');

guard.submit(state, { rule_id='one', severity='important' }, active, 11.5, options);
guard.submit(state, { rule_id='two', severity='important' }, active, 11.6, options);
decision = guard.submit(state, { rule_id='three', severity='important' }, active, 11.7, options);
eq(decision, 'dropped', 'bounded queue drops excess routine alert');
eq(#state.queue, 3, 'queue remains bounded');

decision = guard.submit(state, { rule_id='lethal', severity='critical' }, active, 12, options);
eq(decision, 'preempt', 'critical alert preempts danger');
local nextAlert = guard.next(state, 12.1);
eq(nextAlert.rule_id, 'aoe', 'queued danger retains priority');
eq(guard.next(state, 20), nil, 'stale queued alerts expire');
eq(state.suppressed, 2, 'suppression telemetry');
eq(state.dropped, 1, 'drop telemetry');

print('alert_guard_spec: all checks passed');
