local learner = dofile('data/timer_learning.lua');

local function assert_equal(actual, expected, label)
    if (actual ~= expected) then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
    end
end

local function assert_close(actual, expected, tolerance, label)
    if (math.abs(actual - expected) > tolerance) then
        error(string.format('%s: expected %.3f, got %.3f', label, expected, actual));
    end
end

local options = {
    minimum_uses = 3,
    minimum_interval = 5,
    maximum_interval = 900,
    confidence_threshold = 0.80,
};

-- A ready/use pair is one use, and three consistent uses create one suggestion.
local entries = {};
local entry, changed, suggested, reason = learner.record(entries, 'Odin Prime', 'Gate of Tartarus', 'readies', 100, options);
assert_equal(changed, true, 'first ready recorded');
assert_equal(suggested, false, 'first ready does not suggest');

entry, changed, suggested, reason = learner.record(entries, 'Odin Prime', 'Gate of Tartarus', 'uses', 102, options);
assert_equal(changed, false, 'resolution is deduplicated');
assert_equal(reason, 'duplicate_resolution', 'resolution reason');

learner.record(entries, 'Odin Prime', 'Gate of Tartarus', 'readies', 144, options);
entry, changed, suggested = learner.record(entries, 'Odin Prime', 'Gate of Tartarus', 'readies', 188, options);
assert_equal(suggested, true, 'third consistent use suggests');
assert_equal(entry.status, 'suggested', 'suggested status');
assert_equal(entry.prediction, 'readiness', 'learned timing classified as readiness');
assert_equal(entry.uses, 3, 'deduplicated use count');
assert_close(entry.interval, 44, 0.001, 'learned median interval');
assert_equal(entry.confidence >= 0.80, true, 'consistent confidence threshold');

local suggestedUses = entry.uses;
local pendingEntry, pendingChanged, _, pendingReason = learner.record(entries, 'Odin Prime', 'Gate of Tartarus', 'readies', 3000, options);
assert_equal(pendingChanged, false, 'pending suggestion waits for review');
assert_equal(pendingReason, 'awaiting_review', 'pending review reason');
assert_equal(pendingEntry.uses, suggestedUses, 'pending suggestion preserves evidence');

-- Widely variable timing remains an observation instead of becoming a trusted candidate.
local variable = {};
learner.record(variable, 'Example Boss', 'Random Move', 'uses', 100, options);
learner.record(variable, 'Example Boss', 'Random Move', 'uses', 130, options);
local variableEntry, _, variableSuggested = learner.record(variable, 'Example Boss', 'Random Move', 'uses', 190, options);
assert_equal(variableSuggested, false, 'variable sequence does not suggest');
assert_equal(variableEntry.status, 'observing', 'variable sequence stays observing');

-- A long downtime starts a fresh sequence and cannot be learned as an encounter interval.
local reset = {};
learner.record(reset, 'Example Boss', 'Phase Move', 'uses', 100, options);
learner.record(reset, 'Example Boss', 'Phase Move', 'uses', 140, options);
local resetEntry = learner.record(reset, 'Example Boss', 'Phase Move', 'uses', 2000, options);
assert_equal(resetEntry.uses, 1, 'long gap resets use count');
assert_equal(#resetEntry.intervals, 0, 'long gap clears intervals');

-- Ignored observations remain inert even if the combat log continues producing events.
entry.status = 'ignored';
local ignoredEntry, ignoredChanged, _, ignoredReason = learner.record(entries, 'Odin Prime', 'Gate of Tartarus', 'readies', 232, options);
assert_equal(ignoredEntry.status, 'ignored', 'ignored status remains');
assert_equal(ignoredChanged, false, 'ignored observation is unchanged');
assert_equal(ignoredReason, 'ignored', 'ignored reason');

print('timer_learning_spec: all checks passed');
