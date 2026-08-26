-- Shared encounter-actor safety checks.
--
-- Encounter rules describe hostile mechanics.  Friendly actors, including players,
-- Trusts and pets, must never activate those rules even when their names and actions
-- are identical to an encounter NPC (for example Trust: August using Daybreak).

local guard = {};

function guard.is_hostile_entity(entity)
    if (entity == nil) then return false; end
    local ok, value = pcall(function () return entity.SpawnFlags; end);
    local flags = ok and tonumber(value) or nil;
    if (flags == nil) then return false; end
    return math.floor(flags / 0x10) % 2 == 1;
end

function guard.classify_entity(entity)
    if (entity == nil) then return 'unknown'; end
    return guard.is_hostile_entity(entity) and 'hostile' or 'non_hostile';
end

function guard.allows_encounter_action(disposition)
    return disposition == 'hostile';
end

function guard.rule_matches_zone(rule, zone_id)
    if (type(rule) ~= 'table' or type(rule.zone_ids) ~= 'table' or #rule.zone_ids == 0) then
        return true;
    end

    local current = tonumber(zone_id);
    if (current == nil) then return false; end
    for _, id in ipairs(rule.zone_ids) do
        if (tonumber(id) == current) then return true; end
    end
    return false;
end

return guard;
