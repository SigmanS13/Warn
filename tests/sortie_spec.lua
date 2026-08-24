local sortie = dofile('data/rules/sortie.lua');

local function assert_equal(actual, expected, label)
    if (actual ~= expected) then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
    end
end

assert_equal(#(sortie.encounters or {}), 17, 'Sortie encounter catalog count');
assert_equal(#(sortie.ability_rules or {}), 44, 'Sortie actionable rule count');
assert_equal(#(sortie.state_rules or {}), 2, 'Sortie state rule count');

local encounters = {};
for _, entry in ipairs(sortie.encounters or {}) do encounters[entry.encounter] = true; end
for _, name in ipairs({'Abject Obdella', 'Haughty Tulittia', 'Ghatjot', 'Aita', 'Aminon'}) do
    assert_equal(encounters[name], true, name .. ' indexed');
end

local rules = {};
for _, rule in ipairs(sortie.ability_rules or {}) do
    if rules[rule.id] ~= nil then error('duplicate Sortie rule id: ' .. tostring(rule.id)); end
    assert_equal(rule.verified, true, rule.id .. ' verification');
    rules[rule.id] = rule;
end
for _, rule in ipairs(sortie.state_rules or {}) do
    if rules[rule.id] ~= nil then error('duplicate Sortie rule id: ' .. tostring(rule.id)); end
    assert_equal(rule.verified, true, rule.id .. ' verification');
    rules[rule.id] = rule;
end

assert_equal(rules.sortie_skomora_setting_stage.prediction, 'scripted', 'Skomora timing classification');
assert_equal(rules.sortie_degei_fire_mode.event, 'uses', 'Degei mode transition event');
assert_equal(rules.sortie_aita_vivisection.severity, 'critical', 'Aita Vivisection severity');
assert_equal(rules.sortie_aminon_wind_mode.message, 'WIND MODE!\nPROC WITH ICE DAMAGE', 'Aminon wind response');
assert_equal(rules.sortie_dhartok_water_absorb.type, 'entity_present', 'Dhartok water warning type');
assert_equal(rules.sortie_aminon_bane_tartarus.timer.interval, 240, 'Aminon Bane verified interval');
assert_equal(rules.sortie_aminon_fire_mode.mode.response, 'water', 'Aminon fire response runtime metadata');

print('sortie_spec: all checks passed');
