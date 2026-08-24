local imgui = require('imgui');

local theme = {};

local defaults = {
    name = 'Vana\'diel Tactical',
    window_bg = { 0.025, 0.045, 0.100, 0.965 },
    panel_bg = { 0.035, 0.070, 0.145, 0.900 },
    panel_alt = { 0.050, 0.095, 0.190, 0.920 },
    field_bg = { 0.018, 0.032, 0.070, 0.960 },
    brass = { 0.820, 0.690, 0.390, 1.000 },
    brass_hover = { 0.970, 0.840, 0.500, 1.000 },
    brass_dim = { 0.400, 0.330, 0.190, 1.000 },
    text = { 0.930, 0.920, 0.850, 1.000 },
    text_muted = { 0.570, 0.640, 0.740, 1.000 },
    selected = { 0.095, 0.230, 0.500, 0.950 },
    selected_hover = { 0.130, 0.310, 0.650, 1.000 },
    important = { 0.300, 0.680, 1.000, 1.000 },
    danger = { 1.000, 0.650, 0.180, 1.000 },
    critical = { 1.000, 0.210, 0.180, 1.000 },
    success = { 0.420, 0.920, 0.500, 1.000 },
    rounding = 5.0,
    border_size = 1.0,
};

local color_keys = {
    window_bg = true, panel_bg = true, panel_alt = true, field_bg = true,
    brass = true, brass_hover = true, brass_dim = true, text = true,
    text_muted = true, selected = true, selected_hover = true,
    important = true, danger = true, critical = true, success = true,
};

local function clone_defaults()
    local result = {};
    for key, value in pairs(defaults) do
        if (type(value) == 'table') then
            result[key] = { value[1], value[2], value[3], value[4] };
        else
            result[key] = value;
        end
    end
    return result;
end

local function file_exists(path)
    if (ashita ~= nil and ashita.fs ~= nil and ashita.fs.exists ~= nil) then
        return ashita.fs.exists(path);
    end
    local handle = io.open(path, 'rb');
    if (handle == nil) then return false; end
    handle:close();
    return true;
end

local function parse_color(value)
    value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('^#', '');
    if (#value ~= 6 and #value ~= 8) then return nil; end
    local number = tonumber(value, 16);
    if (number == nil) then return nil; end
    local r, g, b, a;
    if (#value == 8) then
        r = math.floor(number / 0x1000000) % 0x100;
        g = math.floor(number / 0x10000) % 0x100;
        b = math.floor(number / 0x100) % 0x100;
        a = number % 0x100;
    else
        r = math.floor(number / 0x10000) % 0x100;
        g = math.floor(number / 0x100) % 0x100;
        b = number % 0x100;
        a = 0xFF;
    end
    return { r / 255, g / 255, b / 255, a / 255 };
end

local function apply_file(result, path)
    if (not file_exists(path)) then return; end
    local handle = io.open(path, 'rb');
    if (handle == nil) then return; end
    for line in handle:lines() do
        local key, value = line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$');
        if (key ~= nil and value ~= nil and key:sub(1, 1) ~= '#') then
            if (color_keys[key]) then
                result[key] = parse_color(value) or result[key];
            elseif (key == 'rounding' or key == 'border_size') then
                result[key] = tonumber(value) or result[key];
            elseif (key == 'name') then
                result.name = tostring(value);
            end
        end
    end
    handle:close();
end

local function user_theme_root()
    if (AshitaCore == nil or AshitaCore.GetInstallPath == nil) then return nil; end
    return string.format('%s\\config\\addons\\warn\\themes', AshitaCore:GetInstallPath());
end

function theme.load(addon_path, theme_name)
    theme_name = tostring(theme_name or 'vana_tactical');
    local result = clone_defaults();
    result.id = theme_name;
    result.packaged_dir = string.format('%s/themes/%s', addon_path, theme_name);
    apply_file(result, result.packaged_dir .. '/theme.txt');

    local root = user_theme_root();
    if (root ~= nil) then
        result.user_dir = string.format('%s\\%s', root, theme_name);
        apply_file(result, result.user_dir .. '\\theme.txt');
    end
    return result;
end

function theme.launcher_path(active_theme)
    if (active_theme ~= nil and active_theme.user_dir ~= nil) then
        local custom = active_theme.user_dir .. '\\launcher.png';
        if (file_exists(custom)) then return custom; end
    end
    if (active_theme ~= nil and active_theme.packaged_dir ~= nil) then
        local packaged = active_theme.packaged_dir .. '/launcher.png';
        if (file_exists(packaged)) then return packaged; end
    end
    return nil;
end

function theme.role_icon_path(active_theme, icon_name)
    icon_name = tostring(icon_name or ''):lower();
    if (not icon_name:match('^[%w_%-]+$')) then return nil; end
    if (active_theme ~= nil and active_theme.user_dir ~= nil) then
        local custom = string.format('%s\\roles\\%s.png', active_theme.user_dir, icon_name);
        if (file_exists(custom)) then return custom; end
    end
    if (active_theme ~= nil and active_theme.packaged_dir ~= nil) then
        local packaged = string.format('%s/roles/%s.png', active_theme.packaged_dir, icon_name);
        if (file_exists(packaged)) then return packaged; end
    end
    return nil;
end

function theme.list(addon_path)
    local found = { vana_tactical = true };
    local roots = { string.format('%s/themes', addon_path), user_theme_root() };
    if (ashita ~= nil and ashita.fs ~= nil and ashita.fs.get_directory ~= nil) then
        for _, root in ipairs(roots) do
            if (root ~= nil) then
                local ok, entries = pcall(function () return ashita.fs.get_directory(root); end);
                entries = (ok and entries) or {};
                for _, entry in ipairs(entries) do
                    local name = tostring(entry or ''):gsub('[\\/]+$', '');
                    if (name ~= '' and name ~= '.' and name ~= '..') then found[name] = true; end
                end
            end
        end
    end
    local result = {};
    for name in pairs(found) do table.insert(result, name); end
    table.sort(result, function (a, b) return a:lower() < b:lower(); end);
    return result;
end

function theme.severity_color(active_theme, severity)
    local key = tostring(severity or 'important'):lower();
    if (key ~= 'danger' and key ~= 'critical') then key = 'important'; end
    return active_theme[key];
end

function theme.push(active_theme, scale)
    active_theme = active_theme or clone_defaults();
    scale = tonumber(scale) or 1.0;
    imgui.PushStyleColor(ImGuiCol_WindowBg, active_theme.window_bg);
    imgui.PushStyleColor(ImGuiCol_ChildBg, active_theme.panel_bg);
    imgui.PushStyleColor(ImGuiCol_PopupBg, active_theme.panel_alt);
    imgui.PushStyleColor(ImGuiCol_Border, active_theme.brass_dim);
    imgui.PushStyleColor(ImGuiCol_Text, active_theme.text);
    imgui.PushStyleColor(ImGuiCol_TextDisabled, active_theme.text_muted);
    imgui.PushStyleColor(ImGuiCol_FrameBg, active_theme.field_bg);
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, active_theme.panel_alt);
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, active_theme.selected);
    imgui.PushStyleColor(ImGuiCol_Button, active_theme.panel_alt);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, active_theme.selected);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, active_theme.selected_hover);
    imgui.PushStyleColor(ImGuiCol_Header, active_theme.panel_alt);
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, active_theme.selected);
    imgui.PushStyleColor(ImGuiCol_HeaderActive, active_theme.selected_hover);
    imgui.PushStyleColor(ImGuiCol_CheckMark, active_theme.brass_hover);
    imgui.PushStyleColor(ImGuiCol_SliderGrab, active_theme.brass);
    imgui.PushStyleColor(ImGuiCol_SliderGrabActive, active_theme.brass_hover);
    imgui.PushStyleColor(ImGuiCol_Separator, active_theme.brass_dim);
    imgui.PushStyleColor(ImGuiCol_ScrollbarBg, active_theme.field_bg);
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrab, active_theme.brass_dim);
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrabHovered, active_theme.brass);
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrabActive, active_theme.brass_hover);

    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 12 * scale, 10 * scale });
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 7 * scale, 5 * scale });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 8 * scale, 6 * scale });
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, active_theme.rounding * scale);
    imgui.PushStyleVar(ImGuiStyleVar_ChildRounding, math.max(2, active_theme.rounding - 1) * scale);
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 3 * scale);
end

function theme.pop()
    imgui.PopStyleVar(6);
    imgui.PopStyleColor(23);
end

return theme;
