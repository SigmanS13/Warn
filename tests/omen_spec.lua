local omen = dofile('data/rules/omen.lua');

local function assert_equal(actual, expected, label)
    if (actual ~= expected) then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
    end
end

assert_equal(#(omen.encounters or {}), 9, 'Omen encounter catalog count');
assert_equal(#(omen.ability_rules or {}), 28, 'Omen actionable rule count');

local rules = {};
for _, rule in ipairs(omen.ability_rules or {}) do
    if rules[rule.id] ~= nil then
        error('duplicate Omen rule id: ' .. tostring(rule.id));
    end
    assert_equal(rule.verified, true, rule.id .. ' verification');
    rules[rule.id] = rule;
end

assert_equal(rules.omen_thinker_pain_sync.event, 'readies', 'Pain Sync reaction event');
assert_equal(rules.omen_thinker_pain_sync.severity, 'critical', 'Pain Sync severity');
assert_equal(rules.omen_kyou_unfaltering_bravado.prediction, 'scripted', 'Kyou threshold classification');
assert_equal(rules.omen_kei_dancing_fullers.target_shape, 'radial', 'Dancing Fullers shape');
assert_equal(rules.omen_kin_target.event, 'uses', 'Kin Target activation event');
assert_equal(rules.omen_ou_prophylaxis.severity, 'critical', 'Ou Prophylaxis severity');
assert_equal(rules.omen_ou_chainspell.ability, 'Chainspell', 'Ou 65 percent Chainspell');
assert_equal(rules.omen_ou_target.event, 'readies', 'Ou Target packet-visible event');
assert_equal(rules.omen_ou_target.message:find('{target}', 1, true) ~= nil, true, 'Ou Target dynamic name placeholder');

print('omen_spec: all checks passed');
