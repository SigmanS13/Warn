local parser = dofile('data/status_packet.lua');

local values = {
    ['I:5'] = 0x01020304,
    ['I:9'] = 0x05060708,
    ['I:13'] = 15,
    ['I:17'] = 123,
    ['H:21'] = 0x1111,
    ['H:23'] = 0x2222,
    ['H:25'] = 0x3333,
};
local function unpack_value(format, _, offset)
    return values[format .. ':' .. tostring(offset)] or 0;
end

local packet = assert(parser.parse('test', unpack_value));
assert(packet.actor_id == 0x01020304, 'actor id parsed');
assert(packet.target_id == 0x05060708, 'target id parsed');
assert(packet.param1 == 15 and packet.param2 == 123, 'message parameters parsed');
assert(packet.actor_index == 0x1111, 'actor index parsed');
assert(packet.target_index == 0x2222 and packet.message_id == 0x3333, 'indices and message parsed');

local missing, err = parser.parse(nil, unpack_value);
assert(missing == nil and err ~= nil, 'missing packet rejected');
local malformed = parser.parse('test', function () error('bad packet'); end);
assert(malformed == nil, 'malformed packet rejected');

print('status_packet_spec: all checks passed');
