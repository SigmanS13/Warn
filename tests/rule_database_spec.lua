local module_files = {
    'data/rules/catalog.lua',
    'data/rules/generic.lua',
    'data/rules/high_tier_battlefields.lua',
    'data/rules/omen.lua',
    'data/rules/sortie.lua',
    'data/rules/odyssey.lua',
    'data/rules/geas_fete.lua',
    'data/rules/dynamis.lua',
    'data/rules/dynamis_divergence.lua',
    'data/rules/sinister_reign.lua',
    'data/rules/skirmish.lua',
    'data/rules/unity_wanted.lua',
    'data/rules/vagary.lua',
    'data/rules/ambuscade_v1.lua',
    'data/rules/ambuscade_v2.lua',
    'data/rules/ambuscade_v2_history.lua',
};

local ability_count = 0;
local state_count = 0;
local catalog_count = 0;
local ids = {};

for _, file in ipairs(module_files) do
    local module = dofile(file);
    for _, rule in ipairs(module.ability_rules or {}) do
        if ids[rule.id] ~= nil then error('duplicate rule id: ' .. tostring(rule.id)); end
        ids[rule.id] = true;
        ability_count = ability_count + 1;
    end
    for _, rule in ipairs(module.state_rules or {}) do
        if ids[rule.id] ~= nil then error('duplicate rule id: ' .. tostring(rule.id)); end
        ids[rule.id] = true;
        state_count = state_count + 1;
    end
    catalog_count = catalog_count + #(module.encounters or {});
end

if ability_count < 440 then error('unexpectedly low ability rule count'); end
if state_count < 24 then error('unexpectedly low state rule count'); end
if catalog_count < 430 then error('unexpectedly low encounter catalog count'); end

print(string.format('rule_database_spec: %d ability rules, %d state rules, %d catalog entries; all IDs unique', ability_count, state_count, catalog_count));
