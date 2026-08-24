-- Pure runtime helpers for verified encounter timers and compact tactical state.
-- This module deliberately contains no Ashita or ImGui calls so its certainty rules can be tested.

local runtime = {};
local objectiveRuntime = require('data.objective_runtime');

runtime.bumba_elements = {
    { id='unknown', label='Unknown' },
    { id='fire', label='Fire' },
    { id='ice', label='Ice' },
    { id='wind', label='Wind' },
    { id='earth', label='Earth' },
    { id='thunder', label='Thunder' },
    { id='water', label='Water' },
    { id='light', label='Light' },
    { id='dark', label='Dark' },
};

runtime.bumba_vengeance = {
    { id='v0_15', label='V0-V15', fetter_seconds=240 },
    { id='v20', label='V20', fetter_seconds=150 },
    { id='v25', label='V25', fetter_seconds=60 },
};

local function find_by_id(rows, id)
    for _, row in ipairs(rows or {}) do
        if row.id == id then return row; end
    end
    return nil;
end

function runtime.new_state()
    return {
        timers = {},
        objectives = {
            aminon=objectiveRuntime.new('aminon_elemental_proc'),
            ongo=objectiveRuntime.new('ongo_fetter_proc'),
        },
        aminon = { active=false, mode=nil, response=nil, started_at=nil, proc_confirmed=false, proc_at=nil },
        ongo = { active=false, cycle=0, started_at=nil, shock_active=false, proc_confirmed=false, proc_at=nil },
        bumba = { active=false, element='unknown', element_started_at=nil, vengeance='v25', engaged_at=nil },
        circles = { active=false, alive=0, max_seen=0, reliable=false, cleared=nil, last_seen_at=nil,
            pulses={}, last_player_warning_at=0 },
        shinryu = {
            active=false, wings='unknown', wings_observed_at=nil, next_shift_at=nil, wings_evidence=nil,
            doom={ active=false, pending=false, readied_at=nil, started_at=nil, expires_at=nil,
                visible_until=nil, targets={} },
        },
        diagnostics = { bumba_packets={}, last_signature=nil },
    };
end

function runtime.schedule_timer(state, definition, now)
    if state == nil or definition == nil or definition.id == nil then return nil; end
    local interval = tonumber(definition.interval or definition.duration);
    if interval == nil or interval <= 0 then return nil; end
    now = tonumber(now) or 0;
    local timer = {
        id = tostring(definition.id),
        label = tostring(definition.label or definition.id),
        source_rule_id = definition.source_rule_id,
        started_at = now,
        next_at = now + interval,
        interval = interval,
        prewarn = math.max(0, tonumber(definition.prewarn) or 0),
        prewarn_message = definition.prewarn_message,
        due_message = definition.due_message,
        severity = definition.severity or 'critical',
        prewarned = false,
        due_fired = false,
        certainty = definition.certainty or 'verified',
    };
    state.timers[timer.id] = timer;
    return timer;
end

function runtime.update_timers(state, now)
    local events = {};
    if state == nil then return events; end
    now = tonumber(now) or 0;
    for _, timer in pairs(state.timers or {}) do
        local remaining = timer.next_at - now;
        if not timer.prewarned and timer.prewarn > 0 and remaining <= timer.prewarn and remaining > 0 then
            timer.prewarned = true;
            table.insert(events, { kind='prewarn', timer=timer, remaining=remaining });
        end
        if not timer.due_fired and remaining <= 0 then
            timer.due_fired = true;
            table.insert(events, { kind='due', timer=timer, remaining=remaining });
        end
    end
    table.sort(events, function(a, b) return tostring(a.timer.id) < tostring(b.timer.id); end);
    return events;
end

function runtime.timer_rows(state, now)
    local rows = {};
    now = tonumber(now) or 0;
    for _, timer in pairs((state and state.timers) or {}) do
        table.insert(rows, {
            id=timer.id, label=timer.label, remaining=timer.next_at - now,
            certainty=timer.certainty, due=timer.due_fired,
        });
    end
    table.sort(rows, function(a, b) return a.remaining < b.remaining; end);
    return rows;
end

function runtime.set_aminon_mode(state, mode, response, now)
    if state == nil then return; end
    state.aminon.active = true;
    state.aminon.mode = tostring(mode or 'unknown'):lower();
    state.aminon.response = tostring(response or 'unknown'):lower();
    state.aminon.started_at = tonumber(now) or 0;
    state.aminon.proc_confirmed = false;
    state.aminon.proc_at = nil;
    objectiveRuntime.start(state.objectives.aminon, {
        id='aminon_elemental_proc', label='AMINON ELEMENTAL PROC',
        instruction='LAND FIVE CONSECUTIVE ' .. state.aminon.response:upper() .. ' ELEMENTAL HITS',
        hazard='Uncleared mode accumulates approximately 5% DT every 30 seconds.',
        evidence_type='elemental_hit', element=state.aminon.response, required=5,
        cycle=1, certainty='verified-mechanic/packet-evidence',
    }, now);
end

function runtime.mark_aminon_proc(state, now)
    if state == nil or not state.aminon.active then return false; end
    state.aminon.proc_confirmed = true;
    state.aminon.proc_at = tonumber(now) or 0;
    objectiveRuntime.confirm(state.objectives.aminon, now, 'confirmed');
    return true;
end

function runtime.observe_aminon_element(state, evidence, now)
    if (state == nil or not state.aminon.active) then return false, false; end
    if (tostring(evidence and evidence.element or ''):lower() ~= tostring(state.aminon.response or ''):lower()) then
        objectiveRuntime.reset_progress(state.objectives.aminon, now);
        return false, false, true;
    end
    local added, threshold = objectiveRuntime.observe(state.objectives.aminon, evidence, now);
    if (threshold) then runtime.mark_aminon_proc(state, now); end
    return added, threshold;
end

function runtime.start_ongo_proc(state, now)
    if (state == nil) then return nil; end
    state.ongo.active = true;
    state.ongo.cycle = math.max(0, tonumber(state.ongo.cycle) or 0) + 1;
    state.ongo.started_at = tonumber(now) or 0;
    state.ongo.shock_active = true;
    state.ongo.proc_confirmed = false;
    state.ongo.proc_at = nil;
    local required = math.min(3, 1 + state.ongo.cycle);
    return objectiveRuntime.start(state.objectives.ongo, {
        id='ongo_fetter_proc', label='ONGO FETTER PROC',
        instruction='LAND EARTH MAGIC BURSTS',
        hazard='Fetters active; Shock is approximately 150 HP per tick.',
        evidence_type='magic_burst', element='earth', required=required,
        cycle=state.ongo.cycle, certainty='verified-mechanic/packet-evidence',
    }, now);
end

function runtime.observe_ongo_burst(state, evidence, now)
    if (state == nil or not state.ongo.active) then return false, false; end
    return objectiveRuntime.observe(state.objectives.ongo, evidence, now);
end

function runtime.mark_ongo_proc(state, now)
    if (state == nil or not state.ongo.active) then return false; end
    state.ongo.proc_confirmed = true;
    state.ongo.proc_at = tonumber(now) or 0;
    state.ongo.shock_active = false;
    return objectiveRuntime.confirm(state.objectives.ongo, now, 'blue-proc-confirmed');
end

function runtime.aminon_dt_estimate(state, now)
    if state == nil or not state.aminon.active or state.aminon.started_at == nil then return 0, 0; end
    local stop = state.aminon.proc_confirmed and state.aminon.proc_at or (tonumber(now) or 0);
    local age = math.max(0, stop - state.aminon.started_at);
    local stacks = math.floor(age / 30);
    return stacks * 5, age;
end

function runtime.set_bumba_element(state, element, now)
    if state == nil then return nil; end
    local row = find_by_id(runtime.bumba_elements, element) or runtime.bumba_elements[1];
    state.bumba.active = true;
    state.bumba.element = row.id;
    state.bumba.element_started_at = tonumber(now) or 0;
    return row;
end

function runtime.start_bumba(state, vengeance, now)
    if state == nil then return nil; end
    local row = find_by_id(runtime.bumba_vengeance, vengeance) or runtime.bumba_vengeance[3];
    state.bumba.active = true;
    state.bumba.vengeance = row.id;
    state.bumba.engaged_at = tonumber(now) or 0;
    return runtime.schedule_timer(state, {
        id='bumba_fetters', label='BUMBA FETTER MODE', interval=row.fetter_seconds,
        prewarn=10, severity='critical', certainty='verified-by-vengeance',
        prewarn_message='BUMBA FETTERS IN 10 SECONDS!\nPREPARE FOR BACK-TO-BACK TP MOVES',
        due_message='BUMBA FETTER TIMER REACHED!\nWATCH FOR RANDOM PROC REQUIREMENT',
    }, now);
end

function runtime.observe_circles(state, alive, now)
    if state == nil then return nil; end
    alive = math.max(0, math.min(8, math.floor(tonumber(alive) or 0)));
    local circles = state.circles;
    if alive > 0 then circles.active = true; end
    circles.alive = alive;
    circles.max_seen = math.max(circles.max_seen or 0, alive);
    circles.last_seen_at = tonumber(now) or 0;
    circles.reliable = circles.max_seen >= 8;
    circles.cleared = circles.reliable and (8 - alive) or nil;
    return circles;
end

function runtime.circle_damage_reduction(state)
    local circles = state and state.circles or nil;
    if circles == nil or circles.cleared == nil then return nil; end
    return math.max(0, 80 - (circles.cleared * 10));
end

function runtime.observe_circle_pulse(state, actorId, now, position)
    if (state == nil or state.circles == nil) then return nil; end
    local circles = state.circles;
    circles.active = true;
    local key = tostring(tonumber(actorId) or actorId or 'unknown');
    circles.pulses[key] = {
        actor_id=tonumber(actorId) or 0, at=tonumber(now) or 0,
        x=position and tonumber(position.x) or nil,
        y=position and tonumber(position.y) or nil,
        z=position and tonumber(position.z) or nil,
    };
    return circles.pulses[key];
end

function runtime.nearest_recent_circle_pulse(state, playerPosition, now, maximumAge)
    local circles = state and state.circles or nil;
    if (circles == nil or type(playerPosition) ~= 'table') then return nil; end
    now = tonumber(now) or 0;
    maximumAge = math.max(0.5, tonumber(maximumAge) or 6.0);
    local nearest = nil;
    for key, pulse in pairs(circles.pulses or {}) do
        if ((now - (tonumber(pulse.at) or 0)) > maximumAge) then
            circles.pulses[key] = nil;
        elseif (pulse.x ~= nil and pulse.y ~= nil and pulse.z ~= nil) then
            local dx = pulse.x - (tonumber(playerPosition.x) or 0);
            local dy = pulse.y - (tonumber(playerPosition.y) or 0);
            local dz = pulse.z - (tonumber(playerPosition.z) or 0);
            local distance = math.sqrt(dx * dx + dy * dy + dz * dz);
            if (nearest == nil or distance < nearest.distance) then
                nearest = { actor_id=pulse.actor_id, at=pulse.at, distance=distance };
            end
        end
    end
    return nearest;
end

function runtime.record_bumba_packet(state, signature, details)
    if state == nil or signature == nil or signature == state.diagnostics.last_signature then return false; end
    state.diagnostics.last_signature = signature;
    table.insert(state.diagnostics.bumba_packets, 1, details);
    while #state.diagnostics.bumba_packets > 12 do table.remove(state.diagnostics.bumba_packets); end
    return true;
end

function runtime.set_shinryu_wings(state, wings, now, evidence)
    if (state == nil or state.shinryu == nil) then return false; end
    wings = tostring(wings or 'unknown'):lower();
    if (wings ~= 'spread' and wings ~= 'down') then wings = 'unknown'; end
    now = tonumber(now) or 0;
    local changed = state.shinryu.wings ~= wings;
    state.shinryu.active = true;
    state.shinryu.wings = wings;
    state.shinryu.wings_observed_at = now;
    -- Meteor/Comet proves the current stance but not the exact moment the model
    -- changed. A hard countdown would therefore be false precision until a
    -- dedicated transition packet signature is verified.
    state.shinryu.next_shift_at = evidence == 'verified-transition' and (now + 180) or nil;
    state.shinryu.wings_evidence = evidence;
    return changed;
end

function runtime.prepare_shinryu_supernova(state, now)
    if (state == nil or state.shinryu == nil) then return nil; end
    local doom = state.shinryu.doom;
    state.shinryu.active = true;
    doom.active = true;
    doom.pending = true;
    doom.readied_at = tonumber(now) or 0;
    doom.started_at = nil;
    doom.expires_at = nil;
    doom.visible_until = doom.readied_at + 15;
    doom.targets = {};
    return doom;
end

local function target_key(id, name)
    local numeric = tonumber(id) or 0;
    if (numeric ~= 0) then return tostring(numeric); end
    return tostring(name or 'unknown'):lower();
end

function runtime.observe_shinryu_supernova_targets(state, targets, now)
    if (state == nil or state.shinryu == nil) then return nil; end
    local doom = state.shinryu.doom;
    now = tonumber(now) or 0;
    state.shinryu.active = true;
    if (not doom.active) then runtime.prepare_shinryu_supernova(state, now); doom = state.shinryu.doom; end
    doom.pending = false;
    doom.started_at = now;
    doom.expires_at = now + 10;
    doom.visible_until = now + 15;

    for _, target in ipairs(targets or {}) do
        local key = target_key(target.id, target.name);
        doom.targets[key] = {
            id=tonumber(target.id) or 0,
            name=tostring(target.name or ('Target ' .. key)),
            status='exposed',
            observed_at=now,
            message=target.message,
            reaction=target.reaction,
        };
    end
    return doom;
end

function runtime.observe_shinryu_doom(state, targetId, targetName, active, now)
    if (state == nil or state.shinryu == nil or not state.shinryu.doom.active) then return false; end
    local doom = state.shinryu.doom;
    local key = target_key(targetId, targetName);
    local target = doom.targets[key];
    if (target == nil) then
        target = { id=tonumber(targetId) or 0, name=tostring(targetName or ('Target ' .. key)), observed_at=tonumber(now) or 0 };
        doom.targets[key] = target;
    elseif (targetName ~= nil and tostring(targetName) ~= '') then
        target.name = tostring(targetName);
    end
    target.status = active and 'doomed' or 'cleared';
    target.status_observed_at = tonumber(now) or 0;
    return true;
end

function runtime.shinryu_doom_rows(state, now)
    local rows = {};
    local shinryu = state and state.shinryu or nil;
    if (shinryu == nil or not shinryu.doom.active) then return rows, nil, false; end
    local doom = shinryu.doom;
    now = tonumber(now) or 0;
    if (doom.visible_until ~= nil and now > doom.visible_until) then
        doom.active = false;
        return rows, nil, false;
    end
    for _, target in pairs(doom.targets or {}) do table.insert(rows, target); end
    table.sort(rows, function(a, b) return tostring(a.name):lower() < tostring(b.name):lower(); end);
    local remaining = doom.expires_at ~= nil and (doom.expires_at - now) or nil;
    return rows, remaining, doom.pending == true;
end

return runtime;
