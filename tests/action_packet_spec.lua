local parser = dofile('data/action_packet.lua');

local function make_reader(values)
    return function (_, offset, length)
        return values[tostring(offset) .. ':' .. tostring(length)] or 0;
    end
end

local common = {
    ['40:32'] = 0x01020304,
    ['82:4'] = 7,
    ['86:32'] = 0,
    ['118:32'] = 0,
    ['150:32'] = 0x05060708,
    ['182:4'] = 1,
    ['186:5'] = 0,
    ['191:12'] = 0,
    ['203:7'] = 0,
    ['210:3'] = 0,
    ['213:17'] = 300,
    ['230:10'] = 43,
};

local retailValues = {};
for key, value in pairs(common) do retailValues[key] = value; end
retailValues['72:6'] = 1;
retailValues['72:10'] = 16;
local retail = assert(parser.parse('test', 64, make_reader(retailValues), 'auto'));
assert(retail.actor_id == 0x01020304, 'actor parsed');
assert(retail.action_type == 7, 'monster-skill start parsed');
assert(retail.target_id == 0x05060708, 'target parsed');
assert(retail.action_param == 300, 'ability parameter parsed');
assert(retail.message == 43, 'message parsed');
assert(retail.layout == 'retail', 'retail header selected');
assert(#retail.targets == 1 and #retail.targets[1].actions == 1, 'nested target/action retained');

local legacyValues = {};
for key, value in pairs(common) do legacyValues[key] = value; end
legacyValues['72:6'] = 0;
legacyValues['72:10'] = 1;
local legacy = assert(parser.parse('test', 64, make_reader(legacyValues), 'auto'));
assert(legacy.target_count == 1, 'legacy target count parsed');
assert(legacy.layout == 'legacy', 'legacy SimpleLog / DSP header auto-detected');
assert(legacy.action_param == 300 and legacy.message == 43, 'legacy first action parsed');

local forced = assert(parser.parse('test', 64, make_reader(legacyValues), 'retail'));
assert(forced.layout == 'retail' and forced.target_count == 0, 'manual retail override respected');

local multiValues = {};
for key, value in pairs(common) do multiValues[key] = value; end
multiValues['72:6'] = 2;
multiValues['72:10'] = 32;
multiValues['273:32'] = 0x090A0B0C;
multiValues['305:4'] = 1;
multiValues['309:5'] = 1;
multiValues['314:12'] = 22;
multiValues['326:7'] = 3;
multiValues['333:3'] = 0;
multiValues['336:17'] = 777;
multiValues['353:10'] = 101;
local multi = assert(parser.parse('test', 64, make_reader(multiValues), 'retail'));
assert(#multi.targets == 2, 'all targets parsed');
assert(multi.targets[2].id == 0x090A0B0C, 'second target id parsed');
assert(multi.targets[2].actions[1].param == 777, 'second target action parsed');
assert(multi.target_id == 0x05060708 and multi.action_param == 300, 'first-target compatibility aliases preserved');

local optionalValues = {};
for key, value in pairs(common) do optionalValues[key] = value; end
optionalValues['72:6'] = 1;
optionalValues['271:1'] = 1;
optionalValues['272:10'] = 55;
optionalValues['282:17'] = 66;
optionalValues['299:10'] = 77;
optionalValues['309:1'] = 1;
optionalValues['310:10'] = 88;
optionalValues['320:14'] = 99;
optionalValues['334:10'] = 111;
local optional = assert(parser.parse('test', 64, make_reader(optionalValues), 'retail'));
local optionalAction = optional.targets[1].actions[1];
assert(optionalAction.additional_effect.param == 66, 'additional effect parsed');
assert(optionalAction.spikes_effect.param == 99, 'spikes effect parsed');

local missing, err = parser.parse(nil, 0, function () return 0; end);
assert(missing == nil and err ~= nil, 'missing data rejected');

print('action_packet_spec: all checks passed');
