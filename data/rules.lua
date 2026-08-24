-- warn contextual rule database loader.
-- Rules are split by content family; catalog.lua tracks encounter coverage even when an
-- encounter does not yet have a verified actionable mechanic.

local modules = {
    'catalog.lua',
    'generic.lua',
    'high_tier_battlefields.lua',
    'omen.lua',
    'sortie.lua',
    'odyssey.lua',
    'geas_fete.lua',
    'dynamis.lua',
    'dynamis_divergence.lua',
    'sinister_reign.lua',
    'skirmish.lua',
    'unity_wanted.lua',
    'vagary.lua',
    'ambuscade_v1.lua',
    'ambuscade_v2.lua',
    'ambuscade_v2_history.lua',
};

local result = {
    version = 12,
    ability_rules = {},
    state_rules = {},
    catalog = {},
};

for _, filename in ipairs(modules) do
    local path = addon.path .. '/data/rules/' .. filename;
    local chunk, loadErr = loadfile(path);
    if (chunk == nil) then
        error('Failed to load rule module ' .. filename .. ': ' .. tostring(loadErr));
    end

    local ok, data = pcall(chunk);
    if (not ok or type(data) ~= 'table') then
        error('Invalid rule module ' .. filename .. ': ' .. tostring(data));
    end

    for _, rule in ipairs(data.ability_rules or {}) do table.insert(result.ability_rules, rule); end
    for _, rule in ipairs(data.state_rules or {}) do table.insert(result.state_rules, rule); end
    for _, entry in ipairs(data.encounters or {}) do table.insert(result.catalog, entry); end
end

return result;
