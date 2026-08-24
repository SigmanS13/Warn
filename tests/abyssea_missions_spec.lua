local abyssea = dofile('data/rules/abyssea.lua');
local missions = dofile('data/rules/missions_bcnms.lua');

local function assert_equal(actual, expected, label)
    if actual ~= expected then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
    end
end

assert_equal(#(abyssea.encounters or {}), 39, 'Abyssea major encounter index');
assert_equal(#(abyssea.ability_rules or {}), 26, 'Abyssea action rules');
assert_equal(#(abyssea.state_rules or {}), 0, 'Abyssea state rules');
assert_equal(#(missions.encounters or {}), 42, 'Mission and BCNM encounter index');
assert_equal(#(missions.ability_rules or {}), 5, 'Mission action rules');
assert_equal(#(missions.state_rules or {}), 1, 'BCNM state rules');

local seen = {};
for _, module in ipairs({ abyssea, missions }) do
    for _, rule in ipairs(module.ability_rules or {}) do
        if seen[rule.id] then error('duplicate Abyssea/mission rule id: ' .. tostring(rule.id)); end
        assert_equal(rule.verified, true, rule.id .. ' verification');
        seen[rule.id] = rule;
    end
    for _, rule in ipairs(module.state_rules or {}) do
        if seen[rule.id] then error('duplicate Abyssea/mission rule id: ' .. tostring(rule.id)); end
        assert_equal(rule.verified, true, rule.id .. ' verification');
        seen[rule.id] = rule;
    end
end

assert_equal(seen.abyssea_glavoid_disgorge.counter.name, 'Stun', 'Glavoid Disgorge counter');
assert_equal(seen.abyssea_kukulkan_grim_glower.target_shape, 'gaze', 'Kukulkan gaze warning');
assert_equal(seen.abyssea_cirein_mayhem_lantern.severity, 'critical', 'Cirein-croin charm severity');
assert_equal(seen.abyssea_amphitrite_palsynyxis.message, 'PHYSICAL ABSORB MODE!\nUSE MAGIC DAMAGE', 'Amphitrite physical absorb mode');
assert_equal(seen.mission_mammet_transmogrification.actor_aliases[1], 'Mammett-19 Epsilon', 'Mammet retail spelling alias');
assert_equal(seen.mission_diabolos_nightmare.counter.name, 'Stun', 'Diabolos Nightmare counter');
assert_equal(seen.bcnm_up_in_arms_fee.sound, 'msg.wav', 'BCNM guidance sound');

print('abyssea_missions_spec: all checks passed');
