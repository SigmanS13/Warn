local file = assert(io.open('warn.lua', 'rb'));
local source = file:read('*a');
file:close();

local integration = source:match(
    'function set_xiui_hotbars_suppressed%b()%s*(.-)%s*function sync_xiui_hotbars_with_dashboard'
);
assert(integration ~= nil, 'XIUI hotbar integration must remain present');
assert(
    integration:find("'/addon exec xiui ' .. string.format('%q', command)", 1, true) ~= nil,
    'XIUI Lua source must be quoted as one /addon exec argument'
);
assert(
    integration:find('command = "/addon exec xiui ', 1, true) == nil,
    'the quoted XIUI payload must not contain a duplicate /addon exec prefix'
);
assert(
    integration:find('QueueCommand(-1, command)', 1, true) == nil,
    'XIUI Lua source must not be queued as an unquoted command'
);

print('xiui_command_spec: /addon exec Lua source is quoted as one argument');
