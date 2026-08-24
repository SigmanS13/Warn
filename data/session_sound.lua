local M = {};

-- Consume the first-open opportunity for one FFXI process. The marker is
-- persisted by warn.lua so unloading/reloading the addon in the same process
-- cannot replay the cue.
function M.consume(config, sessionMarker)
    if (type(config) ~= 'table') then return false, nil, false; end
    sessionMarker = tostring(sessionMarker or '');
    if (sessionMarker == '' or config.first_open_session == sessionMarker) then
        return false, nil, false;
    end

    config.first_open_session = sessionMarker;
    local filename = tostring(config.first_open_selected or '');
    local shouldPlay = config.first_open_enabled == true and filename ~= '' and filename ~= 'None';
    return shouldPlay, filename, true;
end

return M;
