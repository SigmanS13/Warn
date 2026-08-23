-- Minimal, read-only parser for incoming FFXI action packet 0x028.
-- Only the actor, action type, first target and first action parameter are retained.

local action_packet = {};

function action_packet.parse(data, size, unpackBits)
    if (data == nil or type(unpackBits) ~= 'function') then return nil, 'packet data unavailable'; end
    local bitOffset = 40;
    local maximum = (tonumber(size) or 0) * 8;
    if (maximum <= bitOffset) then return nil, 'packet is too small'; end

    local malformed = false;
    local function read(length)
        if ((bitOffset + length) > maximum) then malformed = true; return 0; end
        local value = unpackBits(data, bitOffset, length);
        bitOffset = bitOffset + length;
        return tonumber(value) or 0;
    end

    local result = {
        actor_id = read(32),
        target_count = read(6),
    };
    bitOffset = bitOffset + 4;
    result.action_type = read(4);

    if (result.action_type == 8 or result.action_type == 9) then
        result.param = read(16);
        result.group = read(16);
    else
        result.param = read(32);
    end
    result.recast = read(32);

    if (result.target_count > 0) then
        result.target_id = read(32);
        result.action_count = read(4);
        if (result.action_count > 0) then
            result.reaction = read(5);
            result.animation = read(12);
            result.special_effect = read(7);
            result.knockback = read(3);
            result.action_param = read(17);
            result.message = read(10);
        end
    end

    if (malformed) then return nil, 'malformed action packet'; end
    return result;
end

return action_packet;
