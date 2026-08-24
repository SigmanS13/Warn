-- Reusable, evidence-gated encounter objective progress.
-- Pure Lua: no Ashita or ImGui dependencies, so certainty behavior is testable offline.

local objectives = {};

local function clamp_required(value)
    return math.max(1, math.floor(tonumber(value) or 1));
end

function objectives.new(id)
    return {
        id=tostring(id or 'objective'), active=false, label='', instruction='', hazard='',
        evidence_type=nil, element=nil, required=1, progress=0, cycle=0,
        status='idle', certainty='verified-rule', started_at=nil, completed_at=nil,
        evidence={}, last_evidence_at=nil,
    };
end

function objectives.start(state, definition, now)
    if (state == nil or type(definition) ~= 'table') then return nil; end
    state.id = tostring(definition.id or state.id or 'objective');
    state.active = true;
    state.label = tostring(definition.label or state.id);
    state.instruction = tostring(definition.instruction or '');
    state.hazard = tostring(definition.hazard or '');
    state.evidence_type = definition.evidence_type;
    state.element = definition.element ~= nil and tostring(definition.element):lower() or nil;
    state.required = clamp_required(definition.required);
    state.progress = 0;
    state.cycle = math.max(1, math.floor(tonumber(definition.cycle) or 1));
    state.status = 'active';
    state.certainty = tostring(definition.certainty or 'verified-rule');
    state.started_at = tonumber(now) or 0;
    state.completed_at = nil;
    state.evidence = {};
    state.last_evidence_at = nil;
    return state;
end

function objectives.observe(state, evidence, now)
    if (state == nil or not state.active or state.status == 'complete' or type(evidence) ~= 'table') then
        return false, false;
    end
    if (state.evidence_type ~= nil and tostring(evidence.type or '') ~= tostring(state.evidence_type)) then
        return false, false;
    end
    if (state.element ~= nil and tostring(evidence.element or ''):lower() ~= state.element) then
        return false, false;
    end
    local key = tostring(evidence.key or '');
    if (key == '' or state.evidence[key] ~= nil) then return false, false; end

    state.evidence[key] = {
        at=tonumber(now) or 0, name=evidence.name, type=evidence.type,
        element=evidence.element, target=evidence.target,
    };
    state.progress = math.min(state.required, state.progress + 1);
    state.last_evidence_at = tonumber(now) or 0;
    if (state.progress >= state.required) then state.status = 'awaiting_confirmation'; end
    return true, state.status == 'awaiting_confirmation';
end

function objectives.confirm(state, now, certainty)
    if (state == nil or not state.active) then return false; end
    state.status = 'complete';
    state.progress = state.required;
    state.completed_at = tonumber(now) or 0;
    state.certainty = tostring(certainty or 'confirmed');
    return true;
end

function objectives.reset_progress(state, now)
    if (state == nil or not state.active or state.status == 'complete') then return false; end
    state.progress = 0;
    state.status = 'active';
    state.evidence = {};
    state.last_evidence_at = tonumber(now) or state.last_evidence_at;
    return true;
end

function objectives.clear(state)
    if (state == nil) then return; end
    local replacement = objectives.new(state.id);
    for key in pairs(state) do state[key] = nil; end
    for key, value in pairs(replacement) do state[key] = value; end
end

return objectives;
