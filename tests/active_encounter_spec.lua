local detector = dofile('data/active_encounter.lua');

local function eq(actual, expected, label)
    if actual ~= expected then error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual))); end
end

local catalog = {
    { content='Omen', group='Bosses', encounter='Ou', status='indexed' },
    { content='Odyssey', group='Gaol', encounter='Bumba', status='indexed' },
    { content='Legacy', group='Research', encounter='Indexed Only', status='indexed' },
};
local rules = {
    { id='ou_target', content='Omen', encounter='Ou', actor='Ou', event='readies', ability='Target', severity='critical', verified=true },
    { id='bumba_move', content='Odyssey', encounter='Bumba', actor='Bumba', event='readies', ability='Example', severity='danger', verified=true },
    { id='shared_ou', content='Omen', encounter='Ou', actor='Ou', event='readies', ability='Shared Move', verified=true },
    { id='shared_bumba', content='Odyssey', encounter='Bumba', actor='Bumba', event='readies', ability='Shared Move', verified=true },
};
local index = detector.build_index(catalog, rules, {});
local state = detector.new_state();

eq(#index.profile_list, 3, 'catalog profiles retained');
eq(detector.observe_entities(index, state, { Ou=true }, nil, 10, 12).kind, 'started', 'entity starts encounter');
eq(detector.get_profile(index, state).encounter, 'Ou', 'Ou profile active');
eq(state.confidence, 'nearby', 'entity confidence is honest');
eq(detector.observe_action(index, state, 'Ou', 'Target', 'readies', nil, 11).kind, 'refreshed', 'action confirms active encounter');
eq(state.confidence, 'confirmed', 'action upgrades confidence');
eq(detector.record_unknown(state, 'Ou', 'Mystery Move', 'readies', 12).count, 1, 'unknown action captured backstage');
eq(detector.observe_entities(index, state, {}, nil, 20, 12).kind, 'grace', 'absence uses grace period');
eq(detector.observe_entities(index, state, {}, nil, 33, 12).kind, 'ended', 'absence ends encounter');
eq(state.active_key, nil, 'encounter cleared');

local indexed_key;
for _, profile in ipairs(index.profile_list) do if (profile.encounter == 'Indexed Only') then indexed_key = profile.key; end end
eq(detector.activate_manual(index, state, indexed_key, 40), true, 'manual indexed selection works');
eq(#detector.rules_for_active(index, state), 0, 'indexed-only profile has no alert rules');
eq(detector.observe_action(index, state, 'Ou', 'Target', 'readies', nil, 41).kind, 'manual_retained', 'manual selection is stable');
detector.clear(state, 'test', 42);

local matches = { rules[3], rules[4] };
eq(detector.select_matching_rule(index, state, matches), nil, 'ambiguous rules do not guess');
detector.observe_action(index, state, 'Ou', 'Target', 'readies', nil, 43);
eq(detector.select_matching_rule(index, state, matches).id, 'shared_ou', 'active encounter scopes duplicate ability');

-- Exercise the detector against the complete shipping database as well as the focused
-- fixtures above. This catches malformed catalog/rule associations before packaging.
addon = { path='.' };
local database = dofile('data/rules.lua');
local full_index = detector.build_index(database.catalog, database.ability_rules, database.state_rules);
if (#full_index.profile_list < 512) then error('full detector index lost catalog profiles'); end
if (next(full_index.actor_index) == nil) then error('full detector index has no verified actor evidence'); end
for _, rule in ipairs(database.ability_rules) do
    if (rule.verified == true and rule.actor ~= nil and rule.__encounter_key == nil) then
        error('verified action rule missing encounter association: ' .. tostring(rule.id));
    end
end
for _, rule in ipairs(database.state_rules) do
    if (rule.verified == true and rule.actor ~= nil and rule.__encounter_key == nil) then
        error('verified state rule missing encounter association: ' .. tostring(rule.id));
    end
end

print('active_encounter_spec: all checks passed');
