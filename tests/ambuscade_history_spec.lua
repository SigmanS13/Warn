local history = dofile('data/rules/ambuscade_v2_history.lua');

local function assert_equal(actual, expected, label)
    if actual ~= expected then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
    end
end

assert_equal(#(history.ability_rules or {}), 27, 'historical Volume 2 ability count');
assert_equal(#(history.state_rules or {}), 5, 'historical Volume 2 state count');

local ids = {};
local encounters = {};
for _, collection in ipairs({ history.ability_rules or {}, history.state_rules or {} }) do
    for _, rule in ipairs(collection) do
        if ids[rule.id] then error('duplicate historical Ambuscade id: ' .. tostring(rule.id)); end
        ids[rule.id] = true;
        encounters[rule.encounter] = true;
        assert_equal(rule.verified, true, rule.id .. ' verification');
        assert_equal(rule.group, 'Volume 2', rule.id .. ' browser group');
    end
end

local encounter_count = 0;
for _ in pairs(encounters) do encounter_count = encounter_count + 1; end
assert_equal(encounter_count, 31, 'new actionable Volume 2 encounters');
assert_equal(ids.ambu_v2_voibugard_torment_tusk, true, 'Voibugard lethal mechanic');
assert_equal(ids.ambu_v2_heartwing_crippling_gleam, true, 'Possessed Heartwing reset mechanic');
assert_equal(ids.ambu_v2_ronove_memoirs, true, 'Ronove tome priority');

print('ambuscade_history_spec: all checks passed');
