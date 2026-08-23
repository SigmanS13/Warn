-- Minimal, read-only parser for incoming FFXI action packet 0x028.
-- Supports both the retail / XiPackets header and the legacy SimpleLog / DSP
-- target-count header. Only the first target/action is retained by Warn.

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

    if (result.target_count > 0) then
        local actionOffset = 150;
        result.target_id = read_at(actionOffset, 32);
        result.action_count = read_at(actionOffset + 32, 4);
        if (result.action_count > 8) then return nil, 'implausible action count'; end
        if (result.action_count > 0) then
            actionOffset = actionOffset + 36;
            result.reaction = read_at(actionOffset, 5);
            result.animation = read_at(actionOffset + 5, 12);
            result.special_effect = read_at(actionOffset + 17, 7);
            result.knockback = read_at(actionOffset + 24, 3);
            result.action_param = read_at(actionOffset + 27, 17);
            result.message = read_at(actionOffset + 44, 10);
        end
    end

    if (malformed) then return nil, 'malformed action packet'; end
    return result;
end

return action_packet;
