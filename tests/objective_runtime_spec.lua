package.path = './?.lua;./?/init.lua;' .. package.path;

local objective = require('data.objective_runtime');

local function eq(actual, expected, label)
    assert(actual == expected, string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
end

local state = objective.new('test');
objective.start(state, { id='test', evidence_type='magic_burst', element='earth', required=2, cycle=1 }, 10);
eq(state.status, 'active', 'objective starts active');

local added, threshold = objective.observe(state, { key='one', type='magic_burst', element='earth' }, 11);
eq(added, true, 'matching evidence accepted');
eq(threshold, false, 'first evidence below threshold');
eq(state.progress, 1, 'progress increments');

added = objective.observe(state, { key='one', type='magic_burst', element='earth' }, 12);
eq(added, false, 'duplicate evidence rejected');
eq(state.progress, 1, 'duplicate does not increment');

added = objective.observe(state, { key='wrong', type='magic_burst', element='fire' }, 13);
eq(added, false, 'wrong element rejected');

added, threshold = objective.observe(state, { key='two', type='magic_burst', element='earth' }, 14);
eq(added, true, 'second evidence accepted');
eq(threshold, true, 'threshold awaits confirmation');
eq(state.status, 'awaiting_confirmation', 'threshold is not silently called complete');

eq(objective.confirm(state, 15, 'blue-proc-confirmed'), true, 'explicit confirmation succeeds');
eq(state.status, 'complete', 'confirmation completes objective');
eq(state.certainty, 'blue-proc-confirmed', 'confirmation certainty retained');

print('objective_runtime_spec: ok');
