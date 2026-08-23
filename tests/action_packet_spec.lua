local parser = dofile('data/action_packet.lua');

local values = { 0x01020304, 1, 7, 0, 0, 0x05060708, 1, 0, 0, 0, 0, 300, 43 };
local index = 0;
local packet = assert(parser.parse('test', 64, function (_, _, _)
    index = index + 1;
    return values[index] or 0;
end));

assert(packet.actor_id == 0x01020304, 'actor parsed');
assert(packet.action_type == 7, 'monster-skill start parsed');
assert(packet.target_id == 0x05060708, 'target parsed');
assert(packet.action_param == 300, 'ability parameter parsed');
assert(packet.message == 43, 'message parsed');

local missing, err = parser.parse(nil, 0, function () return 0; end);
assert(missing == nil and err ~= nil, 'missing data rejected');

print('action_packet_spec: all checks passed');
