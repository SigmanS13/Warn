-- Optional portrait-resolution seam for a future encounter-art update.
-- No portrait is displayed unless a matching local asset exists; the encounter
-- browser does not reserve empty space or download art at runtime.
local portraits = {};

local function file_exists(path)
    if (path == nil or path == '') then return false; end
    if (ashita ~= nil and ashita.fs ~= nil and ashita.fs.exists ~= nil) then
        return ashita.fs.exists(path);
    end
    local handle = io.open(path, 'rb');
    if (handle == nil) then return false; end
    handle:close();
    return true;
end

local function safe_key(value)
    return tostring(value or ''):lower():gsub('[^%w_%-]+', '_'):gsub('^_+', ''):gsub('_+$', '');
end

function portraits.resolve(addon_path, encounter_key)
    local key = safe_key(encounter_key);
    if (key == '') then return nil; end

    if (AshitaCore ~= nil and AshitaCore.GetInstallPath ~= nil) then
        local user_path = string.format('%s\\config\\addons\\warn\\portraits\\%s.png',
            AshitaCore:GetInstallPath(), key);
        if (file_exists(user_path)) then return user_path; end
    end

    local packaged = string.format('%s/portraits/%s.png', addon_path, key);
    if (file_exists(packaged)) then return packaged; end
    return nil;
end

return portraits;
