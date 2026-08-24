local odyssey = dofile('data/rules/odyssey.lua');

local function assert_equal(actual, expected, label)
    if (actual ~= expected) then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
    end
end

assert_equal(#(odyssey.encounters or {}), 68, 'Odyssey encounter catalog count');
assert_equal(#(odyssey.ability_rules or {}), 24, 'Odyssey actionable rule count');

local groups = {};
local encounters = {};
for _, entry in ipairs(odyssey.encounters or {}) do
    groups[entry.group] = (groups[entry.group] or 0) + 1;
    encounters[entry.encounter] = true;
end
assert_equal(groups['Sheol A'], 16, 'Sheol A NM count');
assert_equal(groups['Sheol B'], 27, 'Sheol B NM count');
assert_equal(groups['Sheol C'], 7, 'Sheol C NM count');
assert_equal(groups['Sheol Gaol / Atonement 1'], 4, 'Atonement 1 count');
assert_equal(groups['Sheol Gaol / Atonement 2'], 6, 'Atonement 2 count');
assert_equal(groups['Sheol Gaol / Atonement 3'], 6, 'Atonement 3 count');
assert_equal(groups['Sheol Gaol / Atonement 4'], 1, 'Atonement 4 count');
assert_equal(encounters.Bumba, true, 'Bumba indexed');

local rules = {};
for _, rule in ipairs(odyssey.ability_rules or {}) do
    if rules[rule.id] ~= nil then error('duplicate Odyssey rule id: ' .. tostring(rule.id)); end
    assert_equal(rule.verified, true, rule.id .. ' verification');
    rules[rule.id] = rule;
end

assert_equal(rules.odyssey_mimic_hell_trap.severity, 'critical', 'Hell Trap severity');
assert_equal(rules.odyssey_ngai_marine_mayhem.target_shape, 'radial', 'Marine Mayhem shape');
assert_equal(rules.odyssey_kalunga_batholithic_shell.counter.responsibility, 'support', 'Kalunga Dispel role filter');
assert_equal(rules.odyssey_ongo_crashing_thunder.event, 'uses', 'Ongo proc window event');
assert_equal(rules.odyssey_ongo_crashing_thunder.objective.kind, 'ongo_fetter_proc', 'Ongo reusable objective metadata');
assert_equal(rules.odyssey_bumba_dispelga.event, 'starts_casting', 'Bumba Dispelga cast warning');

print('odyssey_spec: all checks passed');
