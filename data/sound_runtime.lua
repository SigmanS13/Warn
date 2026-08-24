local ffi = require('ffi');
local sessionSound = require('data.session_sound');

local M = {};

ffi.cdef[[
    int __stdcall PlaySoundA(const char* pszSound, void* hmod, unsigned int fdwSound);
    void* __stdcall FindFirstFileA(const char* lpFileName, void* lpFindFileData);
    int __stdcall FindNextFileA(void* hFindFile, void* lpFindFileData);
    int __stdcall FindClose(void* hFindFile);
    typedef struct { unsigned long low; unsigned long high; } WARN_FILETIME;
    void* __stdcall GetCurrentProcess(void);
    unsigned long __stdcall GetCurrentProcessId(void);
    int __stdcall GetProcessTimes(void* process, WARN_FILETIME* created,
        WARN_FILETIME* exited, WARN_FILETIME* kernel, WARN_FILETIME* user);
]];

local winmm = nil;
local kernel32 = nil;
pcall(function () winmm = ffi.load('winmm'); end);
pcall(function () kernel32 = ffi.load('kernel32'); end);

local SND_ASYNC = 0x0001;
local SND_NODEFAULT = 0x0002;
local SND_FILENAME = 0x00020000;
local FILE_ATTRIBUTE_DIRECTORY = 0x00000010;
local WIN32_FIND_DATAA_SIZE = 320;
local WIN32_FIND_DATAA_FILENAME_OFFSET = 44;

local fallbackFiles = {
    'msg.wav', 'beep.wav', 'alert.wav', 'warning.wav', 'alarm.wav',
    'firstopen.wav', 'healme.wav', 'celebrate.wav', 'leave.wav', 'rrun.wav',
    'Fly you fools!.wav', 'Kefka.wav', 'Run away.wav',
};

local function add_sound_if_valid(files, seen, name)
    if (name == nil or name == '' or name == '.' or name == '..') then return; end
    local lower = name:lower();
    if (not lower:match('%.wav$') or seen[lower]) then return; end
    seen[lower] = true;
    table.insert(files, name);
end

function M.get_files(addonPath)
    local files = {};
    local seen = {};

    if (kernel32 ~= nil) then
        local data = ffi.new('uint8_t[?]', WIN32_FIND_DATAA_SIZE);
        local pattern = addonPath .. '\\sounds\\*.wav';
        local handle = kernel32.FindFirstFileA(pattern, data);
        local invalidHandle = ffi.cast('void*', -1);
        if (handle ~= invalidHandle) then
            while (true) do
                local attributes = ffi.cast('uint32_t*', data)[0];
                if (bit.band(attributes, FILE_ATTRIBUTE_DIRECTORY) == 0) then
                    local namePtr = ffi.cast('char*', data) + WIN32_FIND_DATAA_FILENAME_OFFSET;
                    add_sound_if_valid(files, seen, ffi.string(namePtr));
                end
                if (kernel32.FindNextFileA(handle, data) == 0) then
                    break
                end
            end
            kernel32.FindClose(handle);
        end
    end

    if (#files == 0) then
        for _, name in ipairs(fallbackFiles) do
            local file = io.open(addonPath .. '\\sounds\\' .. name, 'rb');
            if (file ~= nil) then
                file:close();
                add_sound_if_valid(files, seen, name);
            end
        end
    end

    table.sort(files, function (a, b) return a:lower() < b:lower(); end);
    local result = { 'None' };
    for _, name in ipairs(files) do table.insert(result, name); end
    return result;
end

function M.play(addonPath, selected)
    if (selected == nil or selected == 'None' or selected == '') then return true; end
    if (winmm == nil) then return false, 'Sound playback is unavailable (winmm.dll could not be loaded).'; end

    local path = addonPath .. '\\sounds\\' .. selected;
    local file = io.open(path, 'rb');
    if (file == nil) then return false, 'Sound file not found: ' .. tostring(selected); end
    file:close();

    local ok, result = pcall(function ()
        return winmm.PlaySoundA(path, nil, bit.bor(SND_FILENAME, SND_ASYNC, SND_NODEFAULT));
    end);
    if (not ok or result == 0) then return false, 'Failed to play sound: ' .. tostring(selected); end
    return true;
end

function M.session_marker()
    if (kernel32 == nil) then return 'warn-runtime'; end
    local ok, marker = pcall(function ()
        local processId = tonumber(kernel32.GetCurrentProcessId()) or 0;
        local created = ffi.new('WARN_FILETIME[1]');
        local exited = ffi.new('WARN_FILETIME[1]');
        local kernelTime = ffi.new('WARN_FILETIME[1]');
        local userTime = ffi.new('WARN_FILETIME[1]');
        local result = kernel32.GetProcessTimes(kernel32.GetCurrentProcess(), created, exited, kernelTime, userTime);
        if (result ~= 0) then
            return string.format('%u:%u:%u', processId,
                tonumber(created[0].high) or 0, tonumber(created[0].low) or 0);
        end
        return string.format('%u', processId);
    end);
    if (ok and marker ~= nil and marker ~= '') then return marker; end
    return 'warn-runtime';
end

function M.consume_first_open(config)
    return sessionSound.consume(config, M.session_marker());
end

return M;
