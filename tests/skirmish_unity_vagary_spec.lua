local skirmish = dofile('data/rules/skirmish.lua');
local unity = dofile('data/rules/unity_wanted.lua');
local vagary = dofile('data/rules/vagary.lua');

local function assert_equal(actual, expected, label)
    if actual ~= expected then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
    end
end

assert_equal(#(skirmish.encounters or {}), 21, 'Skirmish encounter index');
assert_equal(#(skirmish.ability_rules or {}), 6, 'Skirmish action rules');
assert_equal(#(skirmish.state_rules or {}), 2, 'Skirmish state rules');
assert_equal(#(unity.encounters or {}), 56, 'Unity Wanted complete roster');
assert_equal(#(unity.ability_rules or {}), 29, 'Unity Wanted action rules');
assert_equal(#(unity.state_rules or {}), 1, 'Unity Wanted state rules');
assert_equal(#(vagary.encounters or {}), 5, 'Vagary mega-boss roster');
assert_equal(#(vagary.ability_rules or {}), 28, 'Vagary action rules');
assert_equal(#(vagary.state_rules or {}), 1, 'Vagary state rules');

local seen = {};
for _, module in ipairs({ skirmish, unity, vagary }) do
    for _, rule in ipairs(module.ability_rules or {}) do
        if seen[rule.id] then error('duplicate expansion rule id: ' .. tostring(rule.id)); end
        assert_equal(rule.verified, true, rule.id .. ' verification');
        seen[rule.id] = rule;
    end
    for _, rule in ipairs(module.state_rules or {}) do
        if seen[rule.id] then error('duplicate expansion rule id: ' .. tostring(rule.id)); end
        assert_equal(rule.verified, true, rule.id .. ' verification');
        seen[rule.id] = rule;
    end
end

assert_equal(seen.skirmish_aatxe_awful_eye.target_shape, 'gaze', 'Aatxe gaze warning');
assert_equal(seen.unity_shedu_fulmination.severity, 'critical', 'Shedu Fulmination severity');
assert_equal(seen.unity_bambrox_goblin_mines.type, 'entity_present', 'Bambrox mine detection');
assert_equal(seen.vagary_perfidien_flaming_kick.message, 'FIRE MODE ACTIVE!\nUSE WATER DAMAGE', 'Perfidien fire response');
assert_equal(seen.vagary_plouton_blast_reticence.message, 'WIND MODE + SILENCE!\nUSE ICE DAMAGE', 'Plouton wind response');

print('skirmish_unity_vagary_spec: all checks passed');
