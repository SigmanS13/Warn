-- Validation and merge logic for Warn's non-executable community encounter database.

local community = {};

local allowedEvents = { readies = true, uses = true, starts_casting = true, casts = true };
local allowedSeverities = { important = true, danger = true, critical = true };
local allowedStateTypes = { entity_present = true, entity_movement = true, debuff_maintenance = true };
local allowedCounterTypes = { spell = true, blu_spell = true };
local allowedResponsibilities = {
    primary_healer = true, tank = true, interrupt = true, cleanse = true,
    crowd_control = true, support = true, damage = true,
};
local allowedPredictions = { reactive = true, readiness = true, scripted = true };
local allowedTargetShapes = {
    unspecified = true, self = true, single = true, cone = true, radial = true,
    party = true, gaze = true, ground = true,
};
local allowedDatabasePrefix = 'https://raw.githubusercontent.com/SigmanS13/Warn/';

local function fail(message)
    return nil, message;
end

local function string_field(value, field, required, maximum)
    if (value == nil) then
        if (required) then return fail(field .. ' is required'); end
        return nil;
    end
    if (type(value) ~= 'string') then return fail(field .. ' must be a string'); end
    if (required and value == '') then return fail(field .. ' cannot be empty'); end
    if (#value > maximum) then return fail(field .. ' is too long'); end
    return value;
end

local function number_field(value, field, minimum, maximum, required)
    if (value == nil) then
        if (required) then return fail(field .. ' is required'); end
        return nil;
    end
    if (type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge) then
        return fail(field .. ' must be a finite number');
    end
    if (value < minimum or value > maximum) then return fail(field .. ' is out of range'); end
    return value;
end

local function boolean_field(value, field, required)
    if (value == nil) then
        if (required) then return fail(field .. ' is required'); end
        return nil;
    end
    if (type(value) ~= 'boolean') then return fail(field .. ' must be a boolean'); end
    return value;
end

local function string_array(value, field, maximumItems, maximumLength)
    if (value == nil) then return nil; end
    if (type(value) ~= 'table') then return fail(field .. ' must be an array'); end
    if (#value > maximumItems) then return fail(field .. ' has too many entries'); end
    local result = {};
    for index, item in ipairs(value) do
        local valid, err = string_field(item, field .. '[' .. index .. ']', true, maximumLength);
        if (valid == nil) then return fail(err); end
        result[index] = valid;
    end
    return result;
end

local function validate_id(value, field)
    local result, err = string_field(value, field, true, 96);
    if (result == nil) then return fail(err); end
    if (not result:match('^[a-z0-9][a-z0-9_%.%-]*$')) then
        return fail(field .. ' contains unsupported characters');
    end
    return result;
end

local function validate_source(value, field)
    local result, err = string_field(value, field, true, 512);
    if (result == nil) then return fail(err); end
    if (not result:match('^https://')) then return fail(field .. ' must use HTTPS'); end
    return result;
end

local function validate_sound(value, field)
    if (value == nil) then return nil; end
    local result, err = string_field(value, field, false, 128);
    if (result == nil and err ~= nil) then return fail(err); end
    if (result:find('[/\\]') or not result:lower():match('%.wav$')) then
        return fail(field .. ' must be a WAV filename without a path');
    end
    return result;
end

local function validate_counter(value, field)
    if (value == nil) then return nil; end
    if (type(value) ~= 'table') then return fail(field .. ' must be an object'); end
    local counterType, err = string_field(value.type, field .. '.type', true, 32);
    if (counterType == nil) then return fail(err); end
    if (not allowedCounterTypes[counterType]) then return fail(field .. '.type is unsupported'); end
    local name; name, err = string_field(value.name, field .. '.name', true, 128);
    if (name == nil) then return fail(err); end
    local label; label, err = string_field(value.label, field .. '.label', false, 160);
    if (label == nil and err ~= nil) then return fail(err); end
    local responsibility; responsibility, err = string_field(value.responsibility, field .. '.responsibility', false, 32);
    if (responsibility == nil and err ~= nil) then return fail(err); end
    if (responsibility ~= nil and not allowedResponsibilities[responsibility]) then
        return fail(field .. '.responsibility is unsupported');
    end
    return { type = counterType, name = name, label = label, responsibility = responsibility };
end

local function validate_counters(value, field)
    if (value == nil) then return nil; end
    if (type(value) ~= 'table' or #value > 12) then return fail(field .. ' must contain at most 12 counters'); end
    local result = {};
    for index, item in ipairs(value) do
        local counter, err = validate_counter(item, field .. '[' .. index .. ']');
        if (counter == nil) then return fail(err); end
        result[index] = counter;
    end
    return result;
end

local function common_rule_fields(source, prefix)
    local result = {};
    local err;
    result.id, err = validate_id(source.id, prefix .. '.id'); if (result.id == nil) then return fail(err); end
    result.content, err = string_field(source.content, prefix .. '.content', true, 128); if (result.content == nil) then return fail(err); end
    result.encounter, err = string_field(source.encounter, prefix .. '.encounter', true, 160); if (result.encounter == nil) then return fail(err); end
    result.group, err = string_field(source.group, prefix .. '.group', false, 128); if (result.group == nil and err ~= nil) then return fail(err); end
    result.actor, err = string_field(source.actor, prefix .. '.actor', false, 128); if (result.actor == nil and err ~= nil) then return fail(err); end
    result.actor_aliases, err = string_array(source.actor_aliases, prefix .. '.actor_aliases', 16, 128); if (result.actor_aliases == nil and err ~= nil) then return fail(err); end
    result.message, err = string_field(source.message, prefix .. '.message', true, 512); if (result.message == nil) then return fail(err); end
    result.severity, err = string_field(source.severity, prefix .. '.severity', true, 24); if (result.severity == nil) then return fail(err); end
    if (not allowedSeverities[result.severity]) then return fail(prefix .. '.severity is unsupported'); end
    result.sound, err = validate_sound(source.sound, prefix .. '.sound'); if (result.sound == nil and err ~= nil) then return fail(err); end
    result.verified, err = boolean_field(source.verified, prefix .. '.verified', true); if (result.verified == nil) then return fail(err); end
    if (result.verified ~= true) then return fail(prefix .. ' must be verified before publication'); end
    result.source, err = validate_source(source.source, prefix .. '.source'); if (result.source == nil) then return fail(err); end
    result.notes, err = string_field(source.notes, prefix .. '.notes', false, 1024); if (result.notes == nil and err ~= nil) then return fail(err); end
    result.duration, err = number_field(source.duration, prefix .. '.duration', 0.1, 120, false); if (result.duration == nil and err ~= nil) then return fail(err); end
    result.counter, err = validate_counter(source.counter, prefix .. '.counter'); if (result.counter == nil and err ~= nil) then return fail(err); end
    result.counters, err = validate_counters(source.counters, prefix .. '.counters'); if (result.counters == nil and err ~= nil) then return fail(err); end
    result.prediction, err = string_field(source.prediction, prefix .. '.prediction', false, 32); if (result.prediction == nil and err ~= nil) then return fail(err); end
    if (result.prediction ~= nil and not allowedPredictions[result.prediction]) then return fail(prefix .. '.prediction is unsupported'); end
    result.target_shape, err = string_field(source.target_shape, prefix .. '.target_shape', false, 32); if (result.target_shape == nil and err ~= nil) then return fail(err); end
    if (result.target_shape ~= nil and not allowedTargetShapes[result.target_shape]) then return fail(prefix .. '.target_shape is unsupported'); end
    result.audience, err = string_array(source.audience, prefix .. '.audience', 8, 32); if (result.audience == nil and err ~= nil) then return fail(err); end
    if (result.audience ~= nil) then
        for _, audience in ipairs(result.audience) do
            if (audience ~= 'everyone' and not allowedResponsibilities[audience]) then return fail(prefix .. '.audience contains an unsupported value'); end
        end
    end
    return result;
end

local function validate_ability_rule(source, prefix)
    if (type(source) ~= 'table') then return fail(prefix .. ' must be an object'); end
    local result, err = common_rule_fields(source, prefix);
    if (result == nil) then return fail(err); end
    result.event, err = string_field(source.event, prefix .. '.event', true, 32); if (result.event == nil) then return fail(err); end
    if (not allowedEvents[result.event]) then return fail(prefix .. '.event is unsupported'); end
    result.ability, err = string_field(source.ability, prefix .. '.ability', true, 160); if (result.ability == nil) then return fail(err); end
    result.aliases, err = string_array(source.aliases, prefix .. '.aliases', 16, 160); if (result.aliases == nil and err ~= nil) then return fail(err); end
    return result;
end

local function validate_state_rule(source, prefix)
    if (type(source) ~= 'table') then return fail(prefix .. ' must be an object'); end
    local result, err = common_rule_fields(source, prefix);
    if (result == nil) then return fail(err); end
    result.type, err = string_field(source.type, prefix .. '.type', true, 48); if (result.type == nil) then return fail(err); end
    if (not allowedStateTypes[result.type]) then return fail(prefix .. '.type is unsupported'); end
    result.status, err = string_field(source.status, prefix .. '.status', false, 96); if (result.status == nil and err ~= nil) then return fail(err); end
    result.loss_message, err = string_field(source.loss_message, prefix .. '.loss_message', false, 512); if (result.loss_message == nil and err ~= nil) then return fail(err); end
    result.gain_messages, err = string_array(source.gain_messages, prefix .. '.gain_messages', 32, 256); if (result.gain_messages == nil and err ~= nil) then return fail(err); end
    result.loss_messages, err = string_array(source.loss_messages, prefix .. '.loss_messages', 32, 256); if (result.loss_messages == nil and err ~= nil) then return fail(err); end
    result.movement_threshold, err = number_field(source.movement_threshold, prefix .. '.movement_threshold', 0, 100, false); if (result.movement_threshold == nil and err ~= nil) then return fail(err); end
    result.rearm_stationary_seconds, err = number_field(source.rearm_stationary_seconds, prefix .. '.rearm_stationary_seconds', 0, 600, false); if (result.rearm_stationary_seconds == nil and err ~= nil) then return fail(err); end
    result.once_per_spawn, err = boolean_field(source.once_per_spawn, prefix .. '.once_per_spawn', false); if (result.once_per_spawn == nil and err ~= nil) then return fail(err); end
    result.only_if_counter_available, err = boolean_field(source.only_if_counter_available, prefix .. '.only_if_counter_available', false); if (result.only_if_counter_available == nil and err ~= nil) then return fail(err); end
    return result;
end

local function validate_catalog_entry(source, prefix)
    if (type(source) ~= 'table') then return fail(prefix .. ' must be an object'); end
    local result = {};
    local err;
    result.content, err = string_field(source.content, prefix .. '.content', true, 128); if (result.content == nil) then return fail(err); end
    result.group, err = string_field(source.group, prefix .. '.group', true, 128); if (result.group == nil) then return fail(err); end
    result.encounter, err = string_field(source.encounter, prefix .. '.encounter', true, 160); if (result.encounter == nil) then return fail(err); end
    result.family, err = string_field(source.family, prefix .. '.family', false, 160); if (result.family == nil and err ~= nil) then return fail(err); end
    result.key, err = string_field(source.key, prefix .. '.key', false, 96); if (result.key == nil and err ~= nil) then return fail(err); end
    result.status, err = string_field(source.status, prefix .. '.status', true, 32); if (result.status == nil) then return fail(err); end
    if (result.status ~= 'indexed' and result.status ~= 'verified') then return fail(prefix .. '.status is unsupported'); end
    return result;
end

function community.validate_manifest(value)
    if (type(value) ~= 'table') then return fail('Manifest root must be an object.'); end
    local result = {};
    local err;
    result.schema_version, err = number_field(value.schema_version, 'schema_version', 1, 1, true); if (result.schema_version == nil) then return fail(err); end
    result.database_version, err = number_field(value.database_version, 'database_version', 1, 1000000000, true); if (result.database_version == nil) then return fail(err); end
    if (result.database_version ~= math.floor(result.database_version)) then return fail('database_version must be an integer'); end
    result.minimum_warn_version, err = string_field(value.minimum_warn_version, 'minimum_warn_version', true, 32); if (result.minimum_warn_version == nil) then return fail(err); end
    if (not result.minimum_warn_version:match('^%d+%.%d+%.%d+$')) then return fail('minimum_warn_version must be semantic version text'); end
    result.published_at, err = string_field(value.published_at, 'published_at', true, 64); if (result.published_at == nil) then return fail(err); end
    result.database_url, err = string_field(value.database_url, 'database_url', true, 512); if (result.database_url == nil) then return fail(err); end
    if (result.database_url:sub(1, #allowedDatabasePrefix) ~= allowedDatabasePrefix) then
        return fail('database_url must point to the official SigmanS13/Warn repository');
    end
    result.sha256, err = string_field(value.sha256, 'sha256', true, 64); if (result.sha256 == nil) then return fail(err); end
    result.sha256 = result.sha256:lower();
    if (not result.sha256:match('^[0-9a-f]+$') or #result.sha256 ~= 64) then return fail('sha256 must contain 64 hexadecimal characters'); end
    result.encounter_count, err = number_field(value.encounter_count, 'encounter_count', 0, 100000, true); if (result.encounter_count == nil) then return fail(err); end
    result.rule_count, err = number_field(value.rule_count, 'rule_count', 0, 100000, true); if (result.rule_count == nil) then return fail(err); end
    result.release_notes, err = string_field(value.release_notes, 'release_notes', false, 1024); if (result.release_notes == nil and err ~= nil) then return fail(err); end
    return result;
end

function community.validate_database(value)
    if (type(value) ~= 'table') then return fail('Database root must be an object.'); end
    local version, err = number_field(value.database_version, 'database_version', 1, 1000000000, true);
    if (version == nil) then return fail(err); end
    if (version ~= math.floor(version)) then return fail('database_version must be an integer'); end
    local publishedAt; publishedAt, err = string_field(value.published_at, 'published_at', true, 64);
    if (publishedAt == nil) then return fail(err); end
    local result = { database_version = version, published_at = publishedAt, ability_rules = {}, state_rules = {}, catalog = {} };
    local seenIds = {};

    local abilityRules = value.ability_rules or {};
    local stateRules = value.state_rules or {};
    local catalog = value.catalog or {};
    if (type(abilityRules) ~= 'table' or #abilityRules > 5000) then return fail('ability_rules must contain at most 5000 entries'); end
    if (type(stateRules) ~= 'table' or #stateRules > 2000) then return fail('state_rules must contain at most 2000 entries'); end
    if (type(catalog) ~= 'table' or #catalog > 10000) then return fail('catalog must contain at most 10000 entries'); end

    for index, rule in ipairs(abilityRules) do
        local valid; valid, err = validate_ability_rule(rule, 'ability_rules[' .. index .. ']');
        if (valid == nil) then return fail(err); end
        if (seenIds[valid.id]) then return fail('duplicate rule id: ' .. valid.id); end
        seenIds[valid.id] = true;
        result.ability_rules[index] = valid;
    end
    for index, rule in ipairs(stateRules) do
        local valid; valid, err = validate_state_rule(rule, 'state_rules[' .. index .. ']');
        if (valid == nil) then return fail(err); end
        if (seenIds[valid.id]) then return fail('duplicate rule id: ' .. valid.id); end
        seenIds[valid.id] = true;
        result.state_rules[index] = valid;
    end
    for index, entry in ipairs(catalog) do
        local valid; valid, err = validate_catalog_entry(entry, 'catalog[' .. index .. ']');
        if (valid == nil) then return fail(err); end
        result.catalog[index] = valid;
    end
    return result;
end

local function merge_by_id(base, updates)
    local result = {};
    local indexes = {};
    for _, item in ipairs(base or {}) do
        table.insert(result, item);
        if (item.id ~= nil) then indexes[tostring(item.id):lower()] = #result; end
    end
    for _, item in ipairs(updates or {}) do
        local key = tostring(item.id):lower();
        if (indexes[key] ~= nil) then
            result[indexes[key]] = item;
        else
            table.insert(result, item);
            indexes[key] = #result;
        end
    end
    return result;
end

local function catalog_key(entry)
    return (tostring(entry.content or '') .. '|' .. tostring(entry.group or '') .. '|' .. tostring(entry.encounter or '')):lower();
end

function community.merge(base, updates)
    local result = {
        ability_rules = merge_by_id(base.ability_rules, updates.ability_rules),
        state_rules = merge_by_id(base.state_rules, updates.state_rules),
        catalog = {},
    };
    local indexes = {};
    for _, entry in ipairs(base.catalog or {}) do
        table.insert(result.catalog, entry);
        indexes[catalog_key(entry)] = #result.catalog;
    end
    for _, entry in ipairs(updates.catalog or {}) do
        local key = catalog_key(entry);
        if (indexes[key] ~= nil) then result.catalog[indexes[key]] = entry;
        else table.insert(result.catalog, entry); indexes[key] = #result.catalog; end
    end
    return result;
end

function community.compare_versions(left, right)
    local function parse(value)
        local major, minor, patch = tostring(value or ''):match('^(%d+)%.(%d+)%.(%d+)$');
        return tonumber(major), tonumber(minor), tonumber(patch);
    end
    local la, lb, lc = parse(left);
    local ra, rb, rc = parse(right);
    if (la == nil or ra == nil) then return nil; end
    if (la ~= ra) then return (la < ra) and -1 or 1; end
    if (lb ~= rb) then return (lb < rb) and -1 or 1; end
    if (lc ~= rc) then return (lc < rc) and -1 or 1; end
    return 0;
end

return community;
