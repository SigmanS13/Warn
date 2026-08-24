-- Read-only parser for incoming FFXI action packet 0x028.
-- Supports both the retail / XiPackets header and the legacy SimpleLog / DSP
-- target-count header. Every target and action is retained; first-target fields
-- remain available as compatibility aliases for older Warn callers.

local action_packet = {};

local function normalize_layout(value)
    value = tostring(value or 'auto'):lower();
    if (value ~= 'retail' and value ~= 'legacy') then return 'auto'; end
    return value;
end

function action_packet.parse(data, size, unpackBits, layoutPreference)
    if (data == nil or type(unpackBits) ~= 'function') then return nil, 'packet data unavailable'; end
    local maximum = (tonumber(size) or 0) * 8;
    if (maximum <= 150) then return nil, 'packet is too small'; end

    local malformed = false;
    local function read_at(offset, length)
        if ((offset + length) > maximum) then malformed = true; return 0; end
        local value = unpackBits(data, offset, length);
        return tonumber(value) or 0;
    end

    local retailCount = read_at(72, 6);
    local legacyCount = read_at(72, 10);
    local preference = normalize_layout(layoutPreference);
    local layout = preference;
    if (layout == 'auto') then
        -- A common SimpleLog / DSP packet with one target reads as zero in the
        -- retail six-bit field but one in the legacy ten-bit field.
        layout = (retailCount == 0 and legacyCount > 0) and 'legacy' or 'retail';
    end

    local result = {
        actor_id = read_at(40, 32),
        target_count = layout == 'legacy' and legacyCount or retailCount,
        retail_target_count = retailCount,
        legacy_target_count = legacyCount,
        layout = layout,
        action_type = read_at(82, 4),
    };
    if (result.target_count > 64) then return nil, 'implausible target count'; end

    if (result.action_type == 8 or result.action_type == 9) then
        result.param = read_at(86, 16);
        result.group = read_at(102, 16);
    else
        result.param = read_at(86, 32);
    end
    result.recast = read_at(118, 32);

    -- The top-level action parameter is a 17-bit value followed by 15 reserved
    -- bits. Keep the historical `param` field above intact while exposing the
    -- precise value needed for completed monster skills (category 11).
    result.param17 = read_at(86, 17);

    result.targets = {};
    local actionOffset = 150;
    for targetIndex = 1, result.target_count do
        local target = {
            id = read_at(actionOffset, 32),
            actions = {},
        };
        actionOffset = actionOffset + 32;
        target.action_count = read_at(actionOffset, 4);
        actionOffset = actionOffset + 4;
        if (target.action_count > 16) then return nil, 'implausible action count'; end

        for actionIndex = 1, target.action_count do
            local action = {};
            action.reaction = read_at(actionOffset, 5); actionOffset = actionOffset + 5;
            action.animation = read_at(actionOffset, 12); actionOffset = actionOffset + 12;
            action.special_effect = read_at(actionOffset, 7); actionOffset = actionOffset + 7;
            action.knockback = read_at(actionOffset, 3); actionOffset = actionOffset + 3;
            action.param = read_at(actionOffset, 17); actionOffset = actionOffset + 17;
            action.message = read_at(actionOffset, 10); actionOffset = actionOffset + 10;
            action.flags = read_at(actionOffset, 31); actionOffset = actionOffset + 31;

            action.has_additional_effect = read_at(actionOffset, 1) == 1;
            actionOffset = actionOffset + 1;
            if (action.has_additional_effect) then
                action.additional_effect = {
                    damage = read_at(actionOffset, 10),
                    param = read_at(actionOffset + 10, 17),
                    message = read_at(actionOffset + 27, 10),
                };
                actionOffset = actionOffset + 37;
            end

            action.has_spikes_effect = read_at(actionOffset, 1) == 1;
            actionOffset = actionOffset + 1;
            if (action.has_spikes_effect) then
                action.spikes_effect = {
                    damage = read_at(actionOffset, 10),
                    param = read_at(actionOffset + 10, 14),
                    message = read_at(actionOffset + 24, 10),
                };
                actionOffset = actionOffset + 34;
            end
            table.insert(target.actions, action);
        end
        table.insert(result.targets, target);
    end

    -- Backward-compatible aliases used by Warn v2.9 and older tests.
    local firstTarget = result.targets[1];
    local firstAction = firstTarget ~= nil and firstTarget.actions[1] or nil;
    if (firstTarget ~= nil) then
        result.target_id = firstTarget.id;
        result.action_count = firstTarget.action_count;
    end
    if (firstAction ~= nil) then
        result.reaction = firstAction.reaction;
        result.animation = firstAction.animation;
        result.special_effect = firstAction.special_effect;
        result.knockback = firstAction.knockback;
        result.action_param = firstAction.param;
        result.message = firstAction.message;
    end
    result.bits_consumed = actionOffset;

    if (malformed) then return nil, 'malformed action packet'; end
    return result;
end

return action_packet;
