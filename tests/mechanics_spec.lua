local mechanics = dofile('data/mechanics.lua');

local function assert_equal(actual, expected, label)
    if (actual ~= expected) then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
    end
end

local whm = mechanics.default_profile(3);
assert_equal(whm.primary_healer, true, 'WHM healer default');
assert_equal(whm.cleanse, true, 'WHM cleanse default');
assert_equal(whm.interrupt, false, 'WHM interrupt default');
assert_equal(mechanics.responsibilities[1].id, 'tank', 'primary role ordering');
assert_equal(mechanics.responsibilities[1].group, 'role', 'primary role grouping');
assert_equal(mechanics.responsibilities[5].id, 'cleanse', 'assignment ordering');
assert_equal(mechanics.responsibilities[5].group, 'assignment', 'assignment grouping');

local blu = mechanics.default_profile(16);
assert_equal(blu.interrupt, true, 'BLU interrupt default');
assert_equal(blu.crowd_control, true, 'BLU crowd-control default');

local assigned, responsibility = mechanics.counter_is_assigned({ name = 'Stun' }, whm);
assert_equal(assigned, false, 'WHM Stun prompt suppressed');
assert_equal(responsibility, 'interrupt', 'Stun responsibility');

assigned = mechanics.counter_is_assigned({ name = 'Cursna' }, whm);
assert_equal(assigned, true, 'WHM Cursna prompt enabled');

local rule = mechanics.normalize_rule({ severity = 'critical' });
assert_equal(rule.prediction, 'reactive', 'rule prediction default');
assert_equal(rule.target_shape, 'unspecified', 'rule shape default');
assert_equal(rule.audience[1], 'everyone', 'rule audience default');

assert_equal(mechanics.profile_key('Test Name', 3, 5), 'test_name|3|5', 'stable profile key');

local htbf = dofile('data/rules/high_tier_battlefields.lua');
local odinRules = {};
for _, entry in ipairs(htbf.ability_rules or {}) do
    if entry.actor == 'Odin Prime' then odinRules[entry.id] = entry; end
end
assert_equal(odinRules.htbf_odin_dread_spikes.event, 'starts_casting', 'Dread Spikes warns from packet-visible cast start');
assert_equal(odinRules.htbf_odin_dread_spikes.severity, 'critical', 'Dread Spikes critical severity');
assert_equal(odinRules.htbf_odin_ofnir.ability, 'Ofnir', 'Odin Ofnir coverage');
assert_equal(odinRules.htbf_odin_yggr.counter.name, 'Dispel', 'Odin Yggr Dispel counter');

print('mechanics_spec: all checks passed');
