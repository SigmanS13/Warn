local guard = dofile('data/actor_guard.lua');

assert(guard.is_hostile_entity({ SpawnFlags=0x10 }) == true, 'hostile spawn flag accepted');
assert(guard.is_hostile_entity({ SpawnFlags=0x11 }) == true, 'hostile flag accepted with other flags');
assert(guard.is_hostile_entity({ SpawnFlags=0x01 }) == false, 'friendly entity rejected');
assert(guard.is_hostile_entity({}) == false, 'entity without verified flags rejected');
assert(guard.is_hostile_entity(nil) == false, 'missing entity rejected');

assert(guard.classify_entity({ SpawnFlags=0x10 }) == 'hostile', 'hostile entity classified');
assert(guard.classify_entity({ SpawnFlags=0x01 }) == 'non_hostile', 'Trust/friendly entity classified');
assert(guard.classify_entity(nil) == 'unknown', 'missing entity remains unresolved');
assert(guard.allows_encounter_action('hostile') == true, 'hostile encounter action accepted');
assert(guard.allows_encounter_action('non_hostile') == false, 'Trust/friendly encounter action rejected');
assert(guard.allows_encounter_action('unknown') == false, 'unresolved actor fails closed');

assert(guard.rule_matches_zone({}, 291) == true, 'unscoped rule remains portable');
assert(guard.rule_matches_zone({ zone_ids={ 259 } }, 259) == true, 'scoped rule accepted in its zone');
assert(guard.rule_matches_zone({ zone_ids={ 259 } }, 135) == false, 'scoped rule rejected in Dynamis Xarcabard');
assert(guard.rule_matches_zone({ zone_ids={ 259 } }, 291) == false, 'scoped rule rejected in Reisenjima');
assert(guard.rule_matches_zone({ zone_ids={ 259 } }, nil) == false, 'scoped rule rejects unknown zone');

local sinister = dofile('data/rules/sinister_reign.lua');
for _, rule in ipairs(sinister.ability_rules or {}) do
    assert(guard.rule_matches_zone(rule, 259) == true, tostring(rule.id) .. ' missing Sinister Reign zone');
    assert(guard.rule_matches_zone(rule, 135) == false, tostring(rule.id) .. ' leaks into Dynamis Xarcabard');
    assert(guard.rule_matches_zone(rule, 291) == false, tostring(rule.id) .. ' leaks into Reisenjima');
end

print('actor_guard_spec: hostile actor and encounter-zone safeguards passed');
