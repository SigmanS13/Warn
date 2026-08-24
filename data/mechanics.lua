-- Shared mechanic classification and responsibility-profile helpers.
-- This module is intentionally independent from Ashita so its policy can be tested offline.

local mechanics = {};

mechanics.responsibilities = {
    { id = 'tank',           label = 'Tank',           group = 'role', icon = 'shield', description = 'Show enmity, positioning and tank-recovery instructions.' },
    { id = 'primary_healer', label = 'Primary Healer', group = 'role', icon = 'potion', description = 'Show healing and recovery instructions.' },
    { id = 'damage',         label = 'Damage Dealer',  group = 'role', icon = 'bow', description = 'Show damage-window and damage-hold instructions.' },
    { id = 'support',        label = 'Support',        group = 'role', icon = 'harp', description = 'Show dispel, resistance and party-support instructions.' },
    { id = 'cleanse',        label = 'Cleanse',        group = 'assignment', description = 'Show status-removal instructions.' },
    { id = 'interrupt',      label = 'Interrupt',      group = 'assignment', description = 'Show Stun and interruption instructions.' },
    { id = 'crowd_control',  label = 'Crowd Control',  group = 'assignment', description = 'Show sleep, bind and enfeeble-maintenance instructions.' },
};

local allowedResponsibilities = {};
for _, entry in ipairs(mechanics.responsibilities) do
    allowedResponsibilities[entry.id] = true;
end

mechanics.prediction_labels = {
    reactive = 'Reactive',
    readiness = 'Readiness Estimate',
    scripted = 'Scripted',
};

mechanics.target_shape_labels = {
    unspecified = 'Shape Unspecified',
    self = 'Self',
    single = 'Single Target',
    cone = 'Conal',
    radial = 'Radial AoE',
    party = 'Party / Alliance',
    gaze = 'Gaze',
    ground = 'Ground / Location',
};

local allowedPredictions = { reactive = true, readiness = true, scripted = true };
local allowedShapes = {};
for key in pairs(mechanics.target_shape_labels) do allowedShapes[key] = true; end

local function enable(profile, ...)
    for index = 1, select('#', ...) do
        profile[select(index, ...)] = true;
    end
end

-- These are starting suggestions, not claims about a party assignment.  Each main-job profile
-- is created once and then remembers the player's choices independently for every subjob.
function mechanics.default_profile(mainJob)
    local profile = {
        primary_healer = false,
        tank = false,
        interrupt = false,
        cleanse = false,
        crowd_control = false,
        support = false,
        damage = false,
    };

    mainJob = tonumber(mainJob) or 0;
    if (mainJob == 3) then enable(profile, 'primary_healer', 'cleanse', 'support');       -- WHM
    elseif (mainJob == 7) then enable(profile, 'tank', 'support');                       -- PLD
    elseif (mainJob == 22) then enable(profile, 'tank', 'interrupt');                    -- RUN
    elseif (mainJob == 10 or mainJob == 17 or mainJob == 21) then enable(profile, 'support'); -- BRD/COR/GEO
    elseif (mainJob == 5) then enable(profile, 'support', 'cleanse', 'crowd_control');    -- RDM
    elseif (mainJob == 20) then enable(profile, 'primary_healer', 'cleanse', 'support'); -- SCH
    elseif (mainJob == 16) then enable(profile, 'damage', 'interrupt', 'crowd_control'); -- BLU
    elseif (mainJob == 4 or mainJob == 8) then enable(profile, 'damage', 'interrupt');   -- BLM/DRK
    elseif (mainJob == 13) then enable(profile, 'damage', 'tank');                       -- NIN
    elseif (mainJob == 15 or mainJob == 19) then enable(profile, 'damage', 'support');   -- SMN/DNC
    elseif (mainJob > 0) then enable(profile, 'damage'); end

    return profile;
end

function mechanics.profile_key(characterName, mainJob, subJob)
    local name = tostring(characterName or 'unknown'):lower():gsub('[^%w_%-]', '_');
    return string.format('%s|%d|%d', name, tonumber(mainJob) or 0, tonumber(subJob) or 0);
end

function mechanics.is_valid_responsibility(value)
    return allowedResponsibilities[tostring(value or '')] == true;
end

local counterMap = {
    ['stun'] = 'interrupt',
    ['head butt'] = 'interrupt',
    ['sudden lunge'] = 'interrupt',
    ['temporal shift'] = 'interrupt',

    ['cursna'] = 'cleanse',
    ['stona'] = 'cleanse',
    ['silena'] = 'cleanse',
    ['paralyna'] = 'cleanse',
    ['erase'] = 'cleanse',

    ['flash'] = 'tank',

    ['dispel'] = 'support',
    ['blank gaze'] = 'support',

    ['sleep'] = 'crowd_control',
    ['sleep ii'] = 'crowd_control',
    ['sleepga'] = 'crowd_control',
    ['sleepga ii'] = 'crowd_control',
    ['foe lullaby'] = 'crowd_control',
    ['foe lullaby ii'] = 'crowd_control',
    ['horde lullaby'] = 'crowd_control',
    ['horde lullaby ii'] = 'crowd_control',
    ['dream flower'] = 'crowd_control',
    ['sheep song'] = 'crowd_control',
    ['soporific'] = 'crowd_control',
    ['yawn'] = 'crowd_control',
    ['break'] = 'crowd_control',
    ['entomb'] = 'crowd_control',
    ['bind'] = 'crowd_control',
    ['gravity'] = 'crowd_control',
    ['gravity ii'] = 'crowd_control',
    ['subduction'] = 'crowd_control',
    ['silence'] = 'crowd_control',
    ['silent storm'] = 'crowd_control',
    ['chaotic eye'] = 'crowd_control',
};

function mechanics.counter_responsibility(counter)
    if (type(counter) ~= 'table') then return nil; end
    local explicit = tostring(counter.responsibility or '');
    if (allowedResponsibilities[explicit]) then return explicit; end

    local name = tostring(counter.name or ''):lower();
    local mapped = counterMap[name];
    if (mapped ~= nil) then return mapped; end
    if (name:match('^bar')) then return 'support'; end
    if (name:find('cure', 1, true) or name:find('curaga', 1, true)) then return 'primary_healer'; end
    return nil;
end

function mechanics.counter_is_assigned(counter, profile)
    local responsibility = mechanics.counter_responsibility(counter);
    if (responsibility == nil) then return true, nil; end
    return type(profile) == 'table' and profile[responsibility] == true, responsibility;
end

function mechanics.normalize_rule(rule)
    if (type(rule) ~= 'table') then return rule; end
    if (not allowedPredictions[rule.prediction]) then rule.prediction = 'reactive'; end
    if (not allowedShapes[rule.target_shape]) then rule.target_shape = 'unspecified'; end
    if (type(rule.audience) ~= 'table' or #rule.audience == 0) then rule.audience = { 'everyone' }; end
    return rule;
end

return mechanics;
