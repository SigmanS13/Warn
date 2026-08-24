-- Pure automatic encounter detection and lifecycle helpers for Warn 3.0.
--
-- This module never creates alerts. It only associates observed, verified actors/actions
-- with curated encounter profiles. Indexed-only catalog entries remain available for
-- manual selection, but are deliberately excluded from automatic detection.

local detector = {};

local function clean(value)
    local result = tostring(value or ''):gsub('^%s+', '');
    result = result:gsub('%s+$', '');
    return result;
end

local function lower(value)
    return clean(value):lower();
end

local function profile_key(content, group, encounter)
    return lower(content) .. '|' .. lower(group) .. '|' .. lower(encounter);
end

local function catalog_group(catalog_lookup, rule)
    if (clean(rule.group) ~= '') then return clean(rule.group); end
    local lookup = lower(rule.content) .. '|' .. lower(rule.encounter or rule.actor);
    local entry = catalog_lookup[lookup];
    if (entry ~= nil and clean(entry.group) ~= '') then return clean(entry.group); end
    local encounter = clean(rule.encounter or rule.actor);
    if (encounter:find('Volume 1', 1, true)) then return 'Volume 1'; end
    if (encounter:find('Volume 2', 1, true)) then return 'Volume 2'; end
    return 'General';
end

local function append_unique(list, value)
    for _, existing in ipairs(list) do
        if (existing == value) then return; end
    end
    table.insert(list, value);
end

local function copy_zones(values)
    local result = {};
    for _, value in ipairs(values or {}) do result[tonumber(value) or value] = true; end
    return next(result) ~= nil and result or nil;
end

local function evidence_matches_zone(evidence, zone_id)
    if (evidence.zones == nil) then return true; end
    zone_id = tonumber(zone_id) or zone_id;
    return evidence.zones[zone_id] == true;
end

local function add_evidence(target, name, key, zones)
    local normalized = lower(name);
    if (normalized == '') then return; end
    target[normalized] = target[normalized] or {};
    table.insert(target[normalized], { key=key, zones=copy_zones(zones) });
end

local function add_rule(index, rule, rule_type)
    if (rule == nil or rule.verified ~= true) then return; end
    local content = clean(rule.content) ~= '' and clean(rule.content) or 'Other';
    local encounter = clean(rule.encounter or rule.actor) ~= '' and clean(rule.encounter or rule.actor) or 'General';
    local group = catalog_group(index.catalog_lookup, rule);
    local key = profile_key(content, group, encounter);
    local profile = index.profiles[key];
    if (profile == nil) then
        profile = { key=key, content=content, group=group, encounter=encounter, status='verified', rules={}, actors={} };
        index.profiles[key] = profile;
        table.insert(index.profile_list, profile);
    end
    rule.__encounter_key = key;
    rule.__rule_type = rule.__rule_type or rule_type;
    table.insert(profile.rules, rule);

    local actors = {};
    if (clean(rule.actor) ~= '') then table.insert(actors, clean(rule.actor)); end
    for _, alias in ipairs(rule.actor_aliases or {}) do table.insert(actors, clean(alias)); end
    for _, actor in ipairs(actors) do
        append_unique(profile.actors, actor);
        add_evidence(index.actor_index, actor, key, rule.zone_ids);
    end

    if (rule_type == 'ability' and clean(rule.ability) ~= '') then
        local abilities = { clean(rule.ability) };
        for _, alias in ipairs(rule.aliases or {}) do table.insert(abilities, clean(alias)); end
        for _, actor in ipairs(actors) do
            for _, ability in ipairs(abilities) do
                local action_key = lower(actor) .. '|' .. lower(ability) .. '|' .. lower(rule.event or '*');
                add_evidence(index.action_index, action_key, key, rule.zone_ids);
                add_evidence(index.action_index, lower(actor) .. '|' .. lower(ability) .. '|*', key, rule.zone_ids);
            end
        end
    end
end

function detector.build_index(catalog, ability_rules, state_rules)
    local index = { profiles={}, profile_list={}, actor_index={}, action_index={}, catalog_lookup={} };
    for _, entry in ipairs(catalog or {}) do
        local content = clean(entry.content) ~= '' and clean(entry.content) or 'Other';
        local group = clean(entry.group) ~= '' and clean(entry.group) or 'General';
        local encounter = clean(entry.encounter) ~= '' and clean(entry.encounter) or 'General';
        local key = profile_key(content, group, encounter);
        if (index.profiles[key] == nil) then
            local profile = {
                key=key, content=content, group=group, encounter=encounter,
                family=entry.family, status=entry.status or 'indexed', rules={}, actors={}, catalog_entry=entry,
            };
            index.profiles[key] = profile;
            table.insert(index.profile_list, profile);
        end
        index.catalog_lookup[lower(content) .. '|' .. lower(encounter)] = entry;
    end
    for _, rule in ipairs(ability_rules or {}) do add_rule(index, rule, 'ability'); end
    for _, rule in ipairs(state_rules or {}) do add_rule(index, rule, 'state'); end
    table.sort(index.profile_list, function(a, b)
        local al = lower(a.content .. ' ' .. a.group .. ' ' .. a.encounter);
        local bl = lower(b.content .. ' ' .. b.group .. ' ' .. b.encounter);
        return al < bl;
    end);
    return index;
end

function detector.new_state()
    return {
        active_key=nil, confidence=nil, evidence=nil, actor=nil, manual=false,
        activated_at=nil, last_evidence_at=nil, absent_since=nil, candidates={},
        last_transition=nil, unknown={}, unknown_order={},
    };
end

function detector.get_profile(index, state_or_key)
    if (index == nil) then return nil; end
    local key = type(state_or_key) == 'table' and state_or_key.active_key or state_or_key;
    return key ~= nil and index.profiles[key] or nil;
end

local function set_candidates(state, keys)
    state.candidates = {};
    for key in pairs(keys or {}) do table.insert(state.candidates, key); end
    table.sort(state.candidates);
end

local function activate(state, key, confidence, evidence, actor, now, manual)
    local changed = state.active_key ~= key or state.manual ~= (manual == true);
    state.active_key = key;
    state.confidence = confidence;
    state.evidence = evidence;
    state.actor = clean(actor) ~= '' and clean(actor) or state.actor;
    state.manual = manual == true;
    state.activated_at = changed and now or state.activated_at;
    state.last_evidence_at = now;
    state.absent_since = nil;
    state.candidates = {};
    if (changed) then state.last_transition = { kind='started', key=key, at=now, evidence=evidence }; end
    return changed;
end

function detector.clear(state, reason, now)
    if (state == nil) then return false; end
    local old = state.active_key;
    if (old == nil and #(state.candidates or {}) == 0) then return false; end
    state.active_key = nil;
    state.confidence = nil;
    state.evidence = nil;
    state.actor = nil;
    state.manual = false;
    state.activated_at = nil;
    state.last_evidence_at = nil;
    state.absent_since = nil;
    state.candidates = {};
    state.last_transition = { kind='ended', key=old, at=now, reason=reason or 'cleared' };
    return true;
end

function detector.activate_manual(index, state, key, now)
    if (index == nil or state == nil or index.profiles[key] == nil) then return false; end
    return activate(state, key, 'manual', 'manual selection', nil, now, true);
end

local function matching_keys(evidence_rows, zone_id)
    local keys = {};
    for _, evidence in ipairs(evidence_rows or {}) do
        if (evidence_matches_zone(evidence, zone_id)) then keys[evidence.key] = true; end
    end
    return keys;
end

local function key_count(keys)
    local count, only = 0, nil;
    for key in pairs(keys or {}) do count = count + 1; only = key; end
    return count, only;
end

function detector.observe_action(index, state, actor, ability, event_type, zone_id, now)
    if (index == nil or state == nil or lower(actor) == '') then return { kind='none' }; end
    now = tonumber(now) or 0;
    local action = lower(actor) .. '|' .. lower(ability) .. '|' .. lower(event_type);
    local wildcard = lower(actor) .. '|' .. lower(ability) .. '|*';
    local keys = matching_keys(index.action_index[action], zone_id);
    for key in pairs(matching_keys(index.action_index[wildcard], zone_id)) do keys[key] = true; end
    if (next(keys) == nil) then keys = matching_keys(index.actor_index[lower(actor)], zone_id); end

    local count, only = key_count(keys);
    if (count == 1) then
        if (state.manual and state.active_key ~= only) then return { kind='manual_retained', key=state.active_key }; end
        local changed = activate(state, only, 'confirmed', clean(actor) .. ' used ' .. clean(ability), actor, now, false);
        return { kind=changed and 'started' or 'refreshed', key=only };
    end
    if (count > 1) then
        if (state.active_key ~= nil and keys[state.active_key]) then
            state.last_evidence_at = now;
            state.actor = clean(actor);
            state.absent_since = nil;
            return { kind='refreshed', key=state.active_key };
        end
        if (not state.manual) then set_candidates(state, keys); end
        return { kind='ambiguous', candidates=state.candidates };
    end
    return { kind='unknown' };
end

function detector.observe_entities(index, state, names, zone_id, now, dismiss_seconds)
    if (index == nil or state == nil) then return { kind='none' }; end
    now = tonumber(now) or 0;
    dismiss_seconds = math.max(2, tonumber(dismiss_seconds) or 12);
    local keys, active_seen, actor_for_key = {}, false, {};
    for name, present in pairs(names or {}) do
        local actor = type(name) == 'number' and present or name;
        if (type(name) == 'number') then present = true; end
        if (present) then
            local actor_keys = matching_keys(index.actor_index[lower(actor)], zone_id);
            for key in pairs(actor_keys) do keys[key] = true; actor_for_key[key] = clean(actor); end
            if (state.active_key ~= nil and actor_keys[state.active_key]) then active_seen = true; end
        end
    end

    if (state.active_key ~= nil) then
        if (state.manual) then
            if (active_seen) then state.last_evidence_at = now; state.absent_since = nil; end
            return { kind=active_seen and 'refreshed' or 'manual_retained', key=state.active_key };
        end
        if (active_seen) then
            state.last_evidence_at = now;
            state.absent_since = nil;
            return { kind='refreshed', key=state.active_key };
        end
        if (state.absent_since == nil) then state.absent_since = now; end
        if ((now - state.absent_since) >= dismiss_seconds) then
            local old = state.active_key;
            detector.clear(state, 'actor absent', now);
            return { kind='ended', key=old };
        end
        return { kind='grace', key=state.active_key };
    end

    local count, only = key_count(keys);
    if (count == 1) then
        activate(state, only, 'nearby', actor_for_key[only] .. ' present', actor_for_key[only], now, false);
        return { kind='started', key=only };
    elseif (count > 1) then
        set_candidates(state, keys);
        return { kind='ambiguous', candidates=state.candidates };
    end
    state.candidates = {};
    return { kind='none' };
end

function detector.record_unknown(state, actor, ability, event_type, now)
    if (state == nil or state.active_key == nil or lower(actor) == '' or lower(ability) == '') then return nil; end
    local key = lower(actor) .. '|' .. lower(ability);
    local entry = state.unknown[key];
    if (entry == nil) then
        entry = { actor=clean(actor), ability=clean(ability), event=clean(event_type), count=0, encounter_key=state.active_key, first_seen=now };
        state.unknown[key] = entry;
        table.insert(state.unknown_order, key);
    end
    entry.count = (tonumber(entry.count) or 0) + 1;
    entry.last_seen = now;
    while (#state.unknown_order > 40) do
        local remove = table.remove(state.unknown_order, 1);
        state.unknown[remove] = nil;
    end
    return entry;
end

function detector.search(index, term, limit)
    local result = {};
    term = lower(term);
    limit = math.max(1, tonumber(limit) or 12);
    for _, profile in ipairs((index and index.profile_list) or {}) do
        local haystack = lower(profile.content .. ' ' .. profile.group .. ' ' .. profile.encounter .. ' ' .. tostring(profile.family or ''));
        if (term == '' or haystack:find(term, 1, true) ~= nil) then
            table.insert(result, profile);
            if (#result >= limit) then break end
        end
    end
    return result;
end

function detector.rules_for_active(index, state)
    local profile = detector.get_profile(index, state);
    return profile ~= nil and profile.rules or {};
end

function detector.select_matching_rule(index, state, matches)
    if (#(matches or {}) == 0) then return nil; end
    if (state ~= nil and state.active_key ~= nil) then
        for _, rule in ipairs(matches) do
            if (rule.__encounter_key == state.active_key) then return rule; end
        end
        return nil;
    end
    if (#matches == 1) then return matches[1]; end
    return nil;
end

return detector;
