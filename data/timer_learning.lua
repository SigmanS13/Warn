-- Pure timer-learning helpers for Warn.
--
-- This module intentionally does not activate alerts or timers.  It only turns a
-- sequence of actor + ability observations into a confidence-scored readiness suggestion.
-- It never claims that a learned TP move follows a hard countdown.

local learner = {};

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value));
end

local function copy_and_sort(values)
    local result = {};
    for _, value in ipairs(values or {}) do
        local number = tonumber(value);
        if (number ~= nil and number > 0) then
            table.insert(result, number);
        end
    end
    table.sort(result);
    return result;
end

function learner.make_key(actor, ability)
    return tostring(actor or ''):lower() .. '|' .. tostring(ability or ''):lower();
end

function learner.summarize(intervals)
    local sorted = copy_and_sort(intervals);
    local count = #sorted;
    if (count == 0) then
        return nil;
    end

    local total = 0;
    for _, value in ipairs(sorted) do total = total + value; end
    local average = total / count;

    local median;
    if ((count % 2) == 1) then
        median = sorted[(count + 1) / 2];
    else
        median = (sorted[count / 2] + sorted[(count / 2) + 1]) / 2;
    end

    local range = sorted[count] - sorted[1];
    local consistency = clamp(1.0 - (range / math.max(average, 1.0)), 0.0, 1.0);
    local sampleStrength = clamp(count / 3.0, 0.0, 1.0);
    local confidence = consistency * (0.65 + (0.35 * sampleStrength));

    return {
        interval = median,
        average = average,
        minimum = sorted[1],
        maximum = sorted[count],
        samples = count,
        confidence = clamp(confidence, 0.0, 1.0),
    };
end

-- Records one observed action and returns:
--   entry, changed, becameSuggestion, reason
--
-- Readies/starts_casting are preferred timing anchors.  A matching uses/casts line
-- shortly afterward is treated as the resolution of the same action, not another use.
function learner.record(entries, actor, ability, eventType, now, options)
    options = options or {};
    local minimumUses = math.max(3, tonumber(options.minimum_uses) or 3);
    local minimumInterval = math.max(1, tonumber(options.minimum_interval) or 5);
    local maximumInterval = math.max(minimumInterval, tonumber(options.maximum_interval) or 900);
    local confidenceThreshold = clamp(tonumber(options.confidence_threshold) or 0.80, 0.0, 1.0);
    local resolutionWindow = math.max(1, tonumber(options.resolution_window) or 15);
    local maximumSamples = math.max(2, tonumber(options.maximum_samples) or 8);

    local key = learner.make_key(actor, ability);
    local entry = entries[key];
    if (entry == nil) then
        entry = {
            actor = actor,
            ability = ability,
            uses = 0,
            intervals = {},
            status = 'observing',
            prediction = 'readiness',
            created_at = now,
        };
        entries[key] = entry;
    end

    if (type(entry.intervals) ~= 'table') then entry.intervals = {}; end
    if (entry.status == nil) then entry.status = 'observing'; end
    entry.prediction = 'readiness';

    if (entry.status == 'ignored') then
        return entry, false, false, 'ignored';
    end
    if (entry.status == 'suggested') then
        return entry, false, false, 'awaiting_review';
    end

    local event = tostring(eventType or 'uses');
    local isResolution = (event == 'uses' or event == 'casts');
    local previousWasStart = (entry.last_event == 'readies' or entry.last_event == 'starts_casting');
    local elapsed = (entry.last_seen ~= nil) and (now - tonumber(entry.last_seen)) or nil;

    if (isResolution and previousWasStart and elapsed ~= nil and elapsed >= 0 and elapsed <= resolutionWindow) then
        return entry, false, false, 'duplicate_resolution';
    end

    if (elapsed ~= nil and elapsed >= 0 and elapsed < minimumInterval) then
        return entry, false, false, 'too_close';
    end

    if (elapsed ~= nil and elapsed > maximumInterval) then
        -- A long gap usually means a new pull/session.  Keep the reviewed state but start
        -- a fresh consecutive sequence so downtime is never mistaken for a repeat timer.
        entry.uses = 0;
        entry.intervals = {};
        entry.interval = nil;
        entry.confidence = nil;
        if (entry.status == 'suggested') then entry.status = 'observing'; end
        elapsed = nil;
    end

    entry.actor = actor;
    entry.ability = ability;
    entry.uses = (tonumber(entry.uses) or 0) + 1;
    entry.last_seen = now;
    entry.last_event = event;
    entry.updated_at = now;

    if (elapsed ~= nil and elapsed >= minimumInterval and elapsed <= maximumInterval) then
        table.insert(entry.intervals, elapsed);
        while (#entry.intervals > maximumSamples) do table.remove(entry.intervals, 1); end
    end

    local summary = learner.summarize(entry.intervals);
    if (summary ~= nil) then
        entry.interval = summary.interval;
        entry.average = summary.average;
        entry.minimum = summary.minimum;
        entry.maximum = summary.maximum;
        entry.samples = summary.samples;
        entry.confidence = summary.confidence;
    end

    local becameSuggestion = false;
    if (entry.status == 'observing' and summary ~= nil and
        entry.uses >= minimumUses and summary.samples >= (minimumUses - 1) and
        summary.confidence >= confidenceThreshold) then
        entry.status = 'suggested';
        entry.suggested_at = now;
        becameSuggestion = true;
    end

    return entry, true, becameSuggestion, 'recorded';
end

return learner;
