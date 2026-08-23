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

print('mechanics_spec: all checks passed');
