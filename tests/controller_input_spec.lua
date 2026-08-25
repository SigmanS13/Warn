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

local callback = source:match("ashita.events.register%('xinput_button'.-\nend%);");
assert(callback ~= nil, 'XInput callback must remain present');
for _, mapping in ipairs({
    "[XINPUT_BUTTON.DPAD_UP] = 'up'",
    "[XINPUT_BUTTON.DPAD_DOWN] = 'down'",
    "[XINPUT_BUTTON.DPAD_LEFT] = 'left'",
    "[XINPUT_BUTTON.DPAD_RIGHT] = 'right'",
    "[XINPUT_BUTTON.B] = 'close'",
    "[XINPUT_BUTTON.LB] = 'tab_left'",
    "[XINPUT_BUTTON.RB] = 'tab_right'",
}) do
    assert(callback:find(mapping, 1, true) ~= nil, 'missing XInput action mapping: ' .. mapping);
end

local toggle_handler = source:match(
    'function guiOps.handle_controller_toggle_input%b()%s*(.-)%s*function guiOps.handle_controller_action'
);
assert(toggle_handler ~= nil, 'controller toggle handler must remain present');
assert(toggle_handler:match(
    'set_gui_open%(not warn%.isGuiOpen%[1%]%);%s*end%s*.-return true;%s*$'
) ~= nil,
    'configured chord buttons must be consumed while the chord is in progress');

print('controller_input_spec: Ashita XInput IDs and chord consumption are correct');
