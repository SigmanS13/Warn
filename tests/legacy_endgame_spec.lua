local dynamis = dofile('data/rules/dynamis.lua');
local divergence = dofile('data/rules/dynamis_divergence.lua');
local sinister = dofile('data/rules/sinister_reign.lua');

local function assert_equal(actual, expected, label)
    if actual ~= expected then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
    end
end

assert_equal(#(dynamis.encounters or {}), 26, 'classic Dynamis principal-boss catalog');
assert_equal(#(dynamis.ability_rules or {}), 11, 'classic Dynamis alert count');
assert_equal(#(divergence.encounters or {}), 13, 'Divergence boss catalog');
assert_equal(#(divergence.ability_rules or {}), 5, 'Divergence alert count');
assert_equal(#(divergence.state_rules or {}), 4, 'Divergence state-rule count');
assert_equal(#(sinister.encounters or {}), 9, 'Sinister Reign roster');
assert_equal(#(sinister.ability_rules or {}), 18, 'Sinister Reign alert count');

local seen = {};
for _, module in ipairs({ dynamis, divergence, sinister }) do
    for _, rule in ipairs(module.ability_rules or {}) do
        if seen[rule.id] then error('duplicate legacy-endgame rule id: ' .. tostring(rule.id)); end
        assert_equal(rule.verified, true, rule.id .. ' verification');
        seen[rule.id] = true;
    end
    for _, rule in ipairs(module.state_rules or {}) do
        if seen[rule.id] then error('duplicate legacy-endgame rule id: ' .. tostring(rule.id)); end
        assert_equal(rule.verified, true, rule.id .. ' verification');
        seen[rule.id] = true;
    end
end

assert_equal(seen.dynamis_adl_tera_slash, true, 'Arch Dynamis Lord lethal cone');
assert_equal(seen.divergence_fii_pexu_doom, true, 'Windurst Divergence Doom');
assert_equal(seen.sinister_august_no_quarter, true, 'August No Quarter');

print('legacy_endgame_spec: all checks passed');
