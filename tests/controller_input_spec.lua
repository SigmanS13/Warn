local file = assert(io.open('warn.lua', 'rb'));
local source = file:read('*a');
file:close();

local constants = source:match('local XINPUT_BUTTON%s*=%s*(%b{})');
assert(constants ~= nil, 'named XInput button constants must remain present');

local expected = {
    DPAD_UP = 0,
    DPAD_DOWN = 1,
    DPAD_LEFT = 2,
    DPAD_RIGHT = 3,
    START = 4,
    BACK = 5,
    L3 = 6,
    R3 = 7,
    LB = 8,
    RB = 9,
    A = 12,
    B = 13,
    X = 14,
    Y = 15,
};
for name, id in pairs(expected) do
    local pattern = name .. '%s*=%s*' .. tostring(id) .. '%s*[,}]';
    assert(constants:find(pattern) ~= nil, string.format('XInput %s must use Ashita button ID %d', name, id));
end

local chords = source:match('xinput%s*=%s*(%b{})');
assert(chords ~= nil, 'XInput chord mappings must remain present');
assert(chords:find('menu = { XINPUT_BUTTON.BACK, XINPUT_BUTTON.START }', 1, true) ~= nil,
    'menu chord must use Back/View + Start/Menu');
assert(chords:find('sticks = { XINPUT_BUTTON.L3, XINPUT_BUTTON.R3 }', 1, true) ~= nil,
    'sticks chord must use L3 + R3');
assert(chords:find('shoulders = { XINPUT_BUTTON.LB, XINPUT_BUTTON.RB }', 1, true) ~= nil,
    'shoulders chord must use LB + RB');

local xinput_callback = source:match("ashita.events.register%('xinput_button'.-\nend%);");
assert(xinput_callback ~= nil, 'XInput callback must remain present');
for _, mapping in ipairs({
    "[XINPUT_BUTTON.DPAD_UP] = 'up'",
    "[XINPUT_BUTTON.DPAD_DOWN] = 'down'",
    "[XINPUT_BUTTON.DPAD_LEFT] = 'left'",
    "[XINPUT_BUTTON.DPAD_RIGHT] = 'right'",
    "[XINPUT_BUTTON.B] = 'close'",
    "[XINPUT_BUTTON.LB] = 'tab_left'",
    "[XINPUT_BUTTON.RB] = 'tab_right'",
}) do
    assert(xinput_callback:find(mapping, 1, true) ~= nil, 'missing XInput action mapping: ' .. mapping);
end

local toggle_handler = source:match(
    'function guiOps.handle_controller_toggle_input%b()%s*(.-)%s*function guiOps.handle_controller_action'
);
assert(toggle_handler ~= nil, 'controller toggle handler must remain present');
assert(toggle_handler:match(
    'warn%.ui%.controller_pending_gui_state%s*=%s*not warn%.isGuiOpen%[1%];%s*end%s*.-return true;%s*$'
) ~= nil,
    'configured chord buttons must be consumed while the chord is in progress');

local action_handler = source:match(
    "function guiOps.handle_controller_action%b()%s*(.-)%s*ashita.events.register%('load'"
);
assert(action_handler ~= nil, 'controller action handler must remain present');
assert(action_handler:find("warn.ui.controller_pending_gui_state = false;", 1, true) ~= nil,
    'B/Circle must queue a controller GUI close');

local dinput_callback = source:match("ashita.events.register%('dinput_button'.-\nend%);");
assert(dinput_callback ~= nil, 'DirectInput callback must remain present');

local controller_event_path = toggle_handler .. action_handler .. xinput_callback .. dinput_callback;
assert(controller_event_path:find('set_gui_open(', 1, true) == nil,
    'controller event callbacks and their handlers must not call set_gui_open directly');
assert(controller_event_path:find('sync_xiui_hotbars_with_dashboard(', 1, true) == nil,
    'controller event callbacks and their handlers must not synchronize XIUI directly');
assert(xinput_callback:find('e.blocked = true;', 1, true) ~= nil,
    'XInput handling must continue to block consumed controller events');
assert(dinput_callback:find('e.blocked = true;', 1, true) ~= nil,
    'DirectInput handling must continue to block consumed controller events');

local present_callback = source:match("ashita.events.register%('d3d_present'.-\nend%);");
assert(present_callback ~= nil, 'present callback must remain present');
assert(present_callback:match(
    "^ashita%.events%.register%('d3d_present', 'present_cb', function %(%s*%)%s*" ..
    'local pendingControllerGuiState = warn%.ui%.controller_pending_gui_state;%s*' ..
    'if %(pendingControllerGuiState ~= nil%) then%s*' ..
    'warn%.ui%.controller_pending_gui_state = nil;%s*' ..
    'set_gui_open%(pendingControllerGuiState%);%s*end'
) ~= nil, 'pending controller GUI state must be cleared and applied at the start of d3d_present');

local _, present_set_gui_open_count = present_callback:gsub('set_gui_open%(', '');
assert(present_set_gui_open_count == 1,
    'd3d_present must consume a pending controller GUI transition exactly once');
local _, pending_clear_count = present_callback:gsub(
    'warn%.ui%.controller_pending_gui_state%s*=%s*nil;', ''
);
assert(pending_clear_count == 1,
    'd3d_present must clear a pending controller GUI transition exactly once');

print('controller_input_spec: controller IDs, event isolation, and deferred GUI transitions are correct');
