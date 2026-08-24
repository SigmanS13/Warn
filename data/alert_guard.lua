-- Pure burst protection for Warn's single live notification card.
--
-- The renderer intentionally shows only one card at a time. This helper deduplicates rapid
-- repeats and keeps a small, priority-aware, expiring queue so large AoE result bursts can
-- never create unbounded work or a long stream of stale notifications.

local guard = {};

local ranks = { important=1, danger=2, critical=3 };

local function rank(alert)
    return ranks[tostring((alert and alert.severity) or 'important'):lower()] or 1;
end

local function key_for(alert)
    if (alert == nil) then return ''; end
    local stable = tostring(alert.dedupe_key or alert.rule_id or '');
    if (stable ~= '') then return stable:lower(); end
    return (tostring(alert.name or '') .. '|' .. tostring(alert.text or '')):lower();
end

function guard.new_state()
    return {
        queue={}, recent={}, accepted=0, suppressed=0, dropped=0, preempted=0,
    };
end

local function prune_recent(state, now, window)
    local cutoff = now - math.max(2, window * 4);
    for key, timestamp in pairs(state.recent or {}) do
        if timestamp < cutoff then state.recent[key] = nil; end
    end
end

local function cap_recent(state, maximum)
    local count = 0;
    for _ in pairs(state.recent or {}) do count = count + 1; end
    while (count > maximum) do
        local oldest_key, oldest_at = nil, nil;
        for key, timestamp in pairs(state.recent) do
            if (oldest_at == nil or timestamp < oldest_at) then oldest_key, oldest_at = key, timestamp; end
        end
        if (oldest_key == nil) then break end
        state.recent[oldest_key] = nil;
        count = count - 1;
    end
end

local function prune_queue(state, now)
    local kept = {};
    for _, alert in ipairs(state.queue or {}) do
        if (tonumber(alert.expires_at) == nil or alert.expires_at > now) then table.insert(kept, alert); end
    end
    state.queue = kept;
end

local function sort_queue(queue)
    table.sort(queue, function(a, b)
        local ar, br = rank(a), rank(b);
        if (ar ~= br) then return ar > br; end
        return (tonumber(a.queued_at) or 0) < (tonumber(b.queued_at) or 0);
    end);
end

-- Returns decision, alert_to_show_now.
-- A suppressed/dropped result is still considered handled by the caller; it should not be
-- retried every frame by state rules.
function guard.submit(state, alert, active, now, options)
    state = state or guard.new_state();
    options = options or {};
    now = tonumber(now) or 0;
    local window = math.max(0.10, tonumber(options.dedupe_window) or 1.25);
    local queue_limit = math.max(1, math.min(10, math.floor(tonumber(options.queue_limit) or 4)));
    local max_age = math.max(1, tonumber(options.max_age) or 6);
    local key = key_for(alert);
    alert.dedupe_key = key;

    prune_recent(state, now, window);
    prune_queue(state, now);
    if (active ~= nil and active.firing == true and key_for(active) == key) then
        state.suppressed = (state.suppressed or 0) + 1;
        return 'suppressed', nil;
    end
    local last = state.recent[key];
    if (last ~= nil and (now - last) < window) then
        state.suppressed = (state.suppressed or 0) + 1;
        return 'suppressed', nil;
    end
    for _, queued in ipairs(state.queue) do
        if (queued.dedupe_key == key) then
            state.suppressed = (state.suppressed or 0) + 1;
            return 'suppressed', nil;
        end
    end

    state.recent[key] = now;
    cap_recent(state, 256);
    state.accepted = (state.accepted or 0) + 1;
    if (active == nil or active.firing ~= true) then return 'show', alert; end
    if (rank(alert) > rank(active)) then
        state.preempted = (state.preempted or 0) + 1;
        return 'preempt', alert;
    end

    alert.queued_at = now;
    alert.expires_at = now + max_age;
    if (#state.queue < queue_limit) then
        table.insert(state.queue, alert);
        sort_queue(state.queue);
        return 'queued', nil;
    end

    sort_queue(state.queue);
    local worst = state.queue[#state.queue];
    if (worst ~= nil and rank(alert) > rank(worst)) then
        state.queue[#state.queue] = alert;
        sort_queue(state.queue);
        state.dropped = (state.dropped or 0) + 1;
        return 'queued_replaced', nil;
    end
    state.dropped = (state.dropped or 0) + 1;
    return 'dropped', nil;
end

function guard.next(state, now)
    if (state == nil) then return nil; end
    now = tonumber(now) or 0;
    prune_queue(state, now);
    sort_queue(state.queue);
    return table.remove(state.queue, 1);
end

function guard.clear(state)
    if (state == nil) then return; end
    state.queue = {};
    state.recent = {};
end

function guard.key_for(alert)
    return key_for(alert);
end

return guard;
