local file = assert(io.open('warn.lua', 'rb'));
local source = file:read('*a');
file:close();

assert(
    source:find('request_focus = false,', 1, true) ~= nil,
    'Warn UI state must initialize its transient focus request'
);

local lifecycle = source:match(
    'local function set_gui_open%b()%s*(.-)%s*%-%-%-+%s*%-%- Warning trigger'
);
assert(lifecycle ~= nil, 'dashboard open lifecycle must remain present');
assert(
    lifecycle:find('if (isOpening) then%s+warn%.ui%.request_focus = true;') ~= nil,
    'opening the dashboard must request focus once'
);

local renderFocus = source:match(
    "warn%.ui%.focus_api_available =.-(if %(warn%.ui%.request_focus%).-warn%.ui%.request_focus = false;)"
);
assert(renderFocus ~= nil, 'dashboard rendering must consume the transient focus request');
assert(
    renderFocus:find("warn.settings.ui.always_on_top and type(imgui.SetNextWindowFocus) == 'function'", 1, true) ~= nil,
    'the one-shot focus request must still honor the user setting and API availability'
);
assert(
    source:find(
        "warn%.ui%.focus_api_available%s*=%s*.-;%s*if %(warn%.settings%.ui%.always_on_top"
    ) == nil,
    'dashboard rendering must not steal focus on every frame'
);

print('focus_lifecycle_spec: dashboard focus is requested once per open transition');
