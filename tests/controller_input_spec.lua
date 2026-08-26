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

for _, obsolete in ipairs({
    'controller_toggle_chord',
    'controller_buttons_down',
    'controller_button_pressed_at',
    'controller_toggle_latched',
    'get_controller_toggle_buttons',
    'handle_controller_toggle_input',
    'Open / Close Chord',
}) do
    assert(source:find(obsolete, 1, true) == nil, 'obsolete controller chord code remains: ' .. obsolete);
end

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
assert(xinput_callback:find("if (state ~= 1) then return; end", 1, true) ~= nil,
    'XInput releases must pass through without being consumed');

local action_handler = source:match(
    "function guiOps.handle_controller_action%b()%s*(.-)%s*ashita.events.register%('load'"
);
assert(action_handler ~= nil, 'controller action handler must remain present');
assert(action_handler:find('warn.isGuiOpen[1] ~= true', 1, true) ~= nil,
    'controller actions must pass through while the GUI is closed');
assert(action_handler:find("warn.ui.controller_pending_gui_state = false;", 1, true) ~= nil,
    'B/Circle must queue a controller GUI close');

local dinput_callback = source:match("ashita.events.register%('dinput_button'.-\nend%);");
assert(dinput_callback ~= nil, 'DirectInput callback must remain present');
assert(dinput_callback:find('if (warn.isGuiOpen[1] ~= true) then return; end', 1, true) ~= nil,
    'DirectInput buttons must pass through while the GUI is closed');
for _, mapping in ipairs({
    "[0] = 'up'",
    "[9000] = 'right'",
    "[18000] = 'down'",
    "[27000] = 'left'",
    "button == 52) then action = 'tab_left'",
    "button == 53) then action = 'tab_right'",
    "button == 50) then action = 'close'",
    "button == 48) then action = 'close'",
}) do
    assert(dinput_callback:find(mapping, 1, true) ~= nil, 'missing DirectInput action mapping: ' .. mapping);
end

local controller_event_path = action_handler .. xinput_callback .. dinput_callback;
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

print('controller_input_spec: closed-GUI pass-through, open-GUI navigation, and deferred close are correct');
