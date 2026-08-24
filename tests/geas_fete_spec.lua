local geas = dofile('data/rules/geas_fete.lua');

local function assert_equal(actual, expected, label)
    if actual ~= expected then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
    end
end

assert_equal(#(geas.encounters or {}), 85, 'complete Aeonic Geas Fete catalog');
assert_equal(#(geas.ability_rules or {}), 34, 'verified Geas Fete alert count');
assert_equal(#(geas.state_rules or {}), 2, 'Geas Fete transition state count');

local zone_counts = { zitah=0, ruaun=0, reisenjima=0 };
for _, entry in ipairs(geas.encounters or {}) do
    if entry.group:find("Escha %- Zi'Tah") then zone_counts.zitah = zone_counts.zitah + 1
    elseif entry.group:find("Escha %- Ru'Aun") then zone_counts.ruaun = zone_counts.ruaun + 1
    elseif entry.group:find('Reisenjima') then zone_counts.reisenjima = zone_counts.reisenjima + 1 end
end
assert_equal(zone_counts.zitah, 25, "Escha - Zi'Tah encounter count");
assert_equal(zone_counts.ruaun, 32, "Escha - Ru'Aun encounter count");
assert_equal(zone_counts.reisenjima, 28, 'Reisenjima encounter count');

local rules = {};
for _, rule in ipairs(geas.ability_rules or {}) do
    if rules[rule.id] then error('duplicate Geas Fete id: ' .. tostring(rule.id)); end
    assert_equal(rule.verified, true, rule.id .. ' verification');
    rules[rule.id] = rule;
end
for _, rule in ipairs(geas.state_rules or {}) do rules[rule.id] = rule; end
assert_equal(rules.geas_albumen_fatal_scream.severity, 'critical', 'Albumen Doom severity');
assert_equal(rules.geas_ony_fire_mode.event, 'uses', 'Onychophora mode switches after cast');
assert_equal(rules.geas_teles_death.counter.responsibility, 'interrupt', 'Teles Death role filter');
assert_equal(rules.geas_zerde_just_desserts.counter.name, 'Stun', 'Zerde interrupt');
assert_equal(rules.geas_kirin_kouryu_transition.type, 'entity_hp_threshold', 'Kirin transition threshold type');
assert_equal(rules.geas_kirin_kouryu_transition.threshold, 52, 'Kirin transition prewarning threshold');
assert_equal(rules.geas_kouryu_spawn_transition.zone_ids[1], 289, 'Kouryu transition scoped to Escha RuAun');

print('geas_fete_spec: all checks passed');
