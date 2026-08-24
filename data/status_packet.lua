-- Read-only parser for incoming FFXI battle/status message packet 0x029.
-- Classification stays outside this module because Param1 is message-dependent.

local status_packet = {};

function status_packet.parse(data, unpackValue)
    if (data == nil or type(unpackValue) ~= 'function') then
        return nil, 'packet data unavailable';
    end

    local ok, actorId, targetId, param1, param2, actorIndex, targetIndex, messageId = pcall(function ()
        return unpackValue('I', data, 0x04 + 0x01),
               unpackValue('I', data, 0x08 + 0x01),
               unpackValue('I', data, 0x0C + 0x01),
               unpackValue('I', data, 0x10 + 0x01),
               unpackValue('H', data, 0x14 + 0x01),
               unpackValue('H', data, 0x16 + 0x01),
               unpackValue('H', data, 0x18 + 0x01);
    end);
    if (not ok) then return nil, 'malformed status packet'; end

    return {
        actor_id = tonumber(actorId) or 0,
        target_id = tonumber(targetId) or 0,
        param1 = tonumber(param1) or 0,
        param2 = tonumber(param2) or 0,
        actor_index = tonumber(actorIndex) or 0,
        target_index = tonumber(targetIndex) or 0,
        message_id = tonumber(messageId) or 0,
    };
end

return status_packet;
