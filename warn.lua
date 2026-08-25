addon.name      = 'warn';
addon.author    = 'Sigman';
addon.version   = '3.0.9';
addon.desc      = 'Context-aware FFXI encounter helper with global debuff and crowd-control tracking.';
addon.link      = '';

--[[
    warn - Ashita v4 Addon
    Created by Sigman
    -----------------------
    Independent of, and does not modify, the skillwatch addon. It reuses the
    same general concepts demonstrated by skillwatch.lua (text_in based
    ability detection, fonts based overlay, ImGui configuration window,
    settings persistence) but is implemented as its own self-contained
    addon with its own settings files, its own overlay, and its own ability
    data file.

    Commands:
        /warn                       - Toggle the configuration GUI.
        /warn <Ability Name>        - Add an ability to the warning list.
        /warn off <Ability Name>    - Remove an ability from the warning list.
        /warn list                  - Print the current warning list to chat.
        /warn clear                 - Clear the entire warning list.
        /warn test <Ability Name>   - Show a test warning.
        /warn debug                 - Toggle parser/state debug logging.
        /warn rules                 - Print loaded contextual rule counts.
        /warn coverage              - Print encounter-index coverage counts.
        /warn testrule <rule id>    - Trigger a contextual rule for testing.
        /warn capability <spell>    - Check whether Warn considers a spell / BLU spell usable now.
        /warn sounds                - Rescan the sounds folder for WAV files.
        /warn rule <rule id>         - Select a contextual rule in the GUI.
        /warn rule reset <rule id>   - Reset a rule's custom enable/sound settings.
        /warn teststate <rule id> <gained|lost> - Test a maintained-debuff state transition.
        /warn debuffs [list|clear|preset|test|lose|soon|reload] - Manage global debuff tracking.
        /warn sleep [list|clear|test|wake] - Compatibility alias for the Sleep debuff tracker.
        /warn petrify [list|clear|test|recover] - Compatibility alias for the Petrify debuff tracker.
--]]

require('common');
local imgui    = require('imgui');
local fonts    = require('fonts');
local settings = require('settings');
local chat     = require('chat');
local ffi      = require('ffi');
local uiTheme  = require('ui.theme');
local uiTextures = require('ui.textures');
local uiPortraits = require('ui.portraits');
local encounterBrowser = require('ui.encounter_browser');
local encounterRuntime = require('data.encounter_runtime');
local activeEncounter = require('data.active_encounter');
local alertGuard = require('data.alert_guard');
local soundRuntime = require('data.sound_runtime');

local spellElementNames = {
    [0]='fire', [1]='ice', [2]='wind', [3]='earth', [4]='thunder', [5]='water', [6]='light', [7]='dark',
};
local magicBurstMessages = {
    [252]=true, [265]=true, [268]=true, [269]=true, [271]=true,
    [272]=true, [274]=true, [275]=true, [379]=true, [650]=true,
};

local COMMUNITY_MANIFEST_URL = 'https://raw.githubusercontent.com/SigmanS13/Warn/main/community/manifest.json';

ffi.cdef[[
    int __stdcall URLDownloadToFileA(void* caller, const char* url, const char* filename, unsigned int reserved, void* callback);
]];
local urlmon = nil;
pcall(function () urlmon = ffi.load('urlmon'); end);

--------------------------------------------------------------------------------------------------
-- Default settings
--------------------------------------------------------------------------------------------------

local default_settings = T{
    overlay = T{
        position_x      = 480,
        position_y      = 300,
        size            = 3.0,          -- font size multiplier
        text_color      = 0xFFFFFF00,   -- ARGB, bright yellow
        outline_color   = 0xFF000000,   -- ARGB, black
        bg_color        = 0xFF660000,   -- ARGB (alpha byte recalculated from bg_transparency), dark red
        bg_transparency = 0.15,         -- 0 = fully opaque, 1 = fully invisible
        blink           = true,
        blink_speed     = 4.0,
        duration        = 4.0,          -- seconds the warning stays up once triggered
        template        = '!!! %s !!!',
        card_opacity    = 0.86,         -- custom warning-card opacity; independent from edge cues
        card_scale      = 1.0,
        edge_enabled    = true,
        edge_intensity  = 0.65,
        reduced_motion  = false,
        position_anchor = 'custom',
        burst_protection = true,
        repeat_suppression = 1.25,
        alert_queue_limit = 4,
        alert_queue_max_age = 6.0,
    },
    ui = T{
        theme                = 'vana_tactical',
        scale_preset         = 'auto',  -- auto / 1440p / 1080p / custom
        custom_scale         = 1.0,
        always_on_top        = true,
        launcher_enabled     = true,
        launcher_position_x  = -1,
        launcher_position_y  = -1,
        launcher_size        = 58,
        controller_enabled   = true,
        controller_layout    = 'xinput', -- xinput / playstation / switch
        show_indexed_only    = false,
        encounter_collapsed  = T{},
        encounter_hud_x      = 24,
        encounter_hud_y      = 150,
        encounter_hud_opacity = 0.86,
    },
    sound = T{
        enabled             = true,
        selected            = 'msg.wav',
        first_open_enabled  = true,
        first_open_selected = 'firstopen.wav',
        -- Persisted process marker: prevents an addon reload from replaying the
        -- cue while the same FFXI process is still running.
        first_open_session  = '',
    },
    context = T{
        enabled           = true,
        job_counters      = true,
        contextual_sounds = true,
        state_triggers    = true,
        packet_recognition = true,
        packet_layout      = 'auto', -- auto / retail / legacy (SimpleLog / DSP)
        encounter_hud      = true,
        encounter_detection = true,
        encounter_dismiss_seconds = 12,
        encounter_diagnostics = false,
        bumba_element      = 'unknown',
        bumba_vengeance    = 'v25',
    },
    responsibilities = T{
        profiles = T{},
    },
    learning = T{
        enabled              = true,
        minimum_uses         = 3,
        minimum_interval     = 5,
        maximum_interval     = 900,
        confidence_threshold = 0.80,
    },
    community = T{
        enabled              = true,
        auto_check           = true,
        check_interval_hours = 24,
        last_checked_at      = 0,
    },
    debuffs = T{
        enabled          = true,
        smart_reapply    = true,     -- maintenance alerts wait until this character can act
        sound_enabled    = true,     -- debuff-loss sounds are independent from manual ability sounds
        critical_center  = true,     -- Sleep/Petrify loss uses a dedicated center-screen alert
        batch_window     = 0.20,     -- group near-simultaneous status losses
        alert_duration   = 4.0,
        show_estimates   = true,     -- show estimated remaining time / overdue state in the Debuffs tab
        prewarn_enabled  = true,     -- warn shortly before important crowd-control estimates expire
        prewarn_seconds  = 5.0,
        statuses         = T{},      -- per-status user overrides keyed by stable status id
    },

    -- Legacy v1.5.x fields retained only so settings.load can migrate a user's
    -- dedicated Sleep/Petrify preferences into the unified Debuff Engine.
    sleep = T{
        enabled = true,
        wake_sound = '__global__',
        wake_duration = 4.0,
        batch_window = 0.20,
    },
    petrify = T{
        enabled = true,
        recovery_sound = '__global__',
        recovery_duration = 4.0,
        batch_window = 0.20,
    },
};

local default_ability_settings = T{
    enabled = T{},   -- map: ability name (exact, as it appears in data/abilities.txt) -> true
};

-- Per-rule user overrides. Rules remain data-driven in data/rules.lua; this file only
-- stores the user's preferences (enabled state and sound override) by stable rule id.
local default_rule_settings = T{
    overrides = T{},
};

-- Learned observations are kept separate from curated rules and normal preferences.
-- A database update can therefore never overwrite local evidence or approvals.
local default_learning_data = T{
    version = 1,
    entries = T{},
};

--------------------------------------------------------------------------------------------------
-- Local helpers (colors)
--------------------------------------------------------------------------------------------------

local function argb_to_rgba_floats(argb)
    argb = argb or 0xFFFFFFFF;
    local a = bit.band(bit.rshift(argb, 24), 0xFF) / 255.0;
    local r = bit.band(bit.rshift(argb, 16), 0xFF) / 255.0;
    local g = bit.band(bit.rshift(argb, 8), 0xFF) / 255.0;
    local b = bit.band(argb, 0xFF) / 255.0;
    return { r, g, b, a };
end

local function rgba_floats_to_argb(t, alpha_override)
    local r = math.floor((t[1] or 1.0) * 255 + 0.5);
    local g = math.floor((t[2] or 1.0) * 255 + 0.5);
    local b = math.floor((t[3] or 1.0) * 255 + 0.5);
    local a = alpha_override;
    if (a == nil) then
        a = math.floor((t[4] or 1.0) * 255 + 0.5);
    end
    return bit.bor(
        bit.lshift(bit.band(a, 0xFF), 24),
        bit.lshift(bit.band(r, 0xFF), 16),
        bit.lshift(bit.band(g, 0xFF), 8),
        bit.band(b, 0xFF));
end

local function safe_format(fmt, value)
    local ok, result = pcall(string.format, fmt, value);
    if (ok) then
        return result;
    end
    return '!!! ' .. tostring(value) .. ' !!!';
end

local function trim(s)
    if (s == nil) then return ''; end
    return (s:gsub('^%s+', ''):gsub('%s+$', ''));
end

--------------------------------------------------------------------------------------------------
-- Addon state
--------------------------------------------------------------------------------------------------

warn = T{
    font = nil,
    criticalFont = nil,

    settings = nil,
    abilitySettings = nil,
    ruleSettings = nil,
    learningData = nil,

    abilities = T{},        -- array of T{ name, enabledBool }
    enabledLookup = T{},    -- map: lower(name) -> original-case name
    soundFiles = T{ 'None', 'msg.wav', 'beep.wav', 'alert.wav', 'warning.wav', 'alarm.wav' },

    isGuiOpen = T{ false },
    guiSizeInitialized = false,
    search = T{ '' },
    selectedIndex = T{ -1 },
    templateBuf = T{ '!!! %s !!!' },
    ruleSearch = T{ '' },
    selectedRuleId = nil,
    encounterContent = nil,
    encounterGroup = nil,
    manualEncounterSearch = T{ '' },
    manualEncounterOpen = T{ false },
    customWatchesOpen = T{ false },
    optionsSection = T{ 1 },
    mainTab = T{ 1 },

    ui = T{
        theme = nil,
        launcher_texture = nil,
        role_textures = T{},
        launcher_position_initialized = false,
        last_launcher_x = nil,
        last_launcher_y = nil,
        encounter_category_index = 1,
        encounter_rule_index = 1,
        portrait_provider = uiPortraits,
        next_launcher_save = nil,
        launcher_drag_mouse_x = nil,
        launcher_drag_mouse_y = nil,
        launcher_press_active = false,
        launcher_dragged = false,
        warning_preview_visible = false,
        warning_preview_drag_mouse_x = nil,
        warning_preview_drag_mouse_y = nil,
        warning_preview_drag_active = false,
        encounter_hud_cache = { key=nil, next_refresh=0, rules={}, counters={} },
    },

    debug = false,

    rules = { ability_rules = {}, state_rules = {}, catalog = {} },
    ruleState = {},
    spellCache = {},
    bluReader = T{
        initialized = false,
        available = false,
        offset = nil,
        error = nil,
    },
    entityScan = T{
        next_scan = 0,
        active_interval = 0.20,
        idle_interval = 1.00,
        entities = {},
    },

    -- Global debuff / crowd-control engine.  Definitions live in data/debuffs.lua.
    -- Runtime state is zone-local and is never persisted.
    debuffs = T{
        definitions = {},
        lookup = {},
        tracked = {},              -- status id -> lower mob name -> tracked entry
        mob_names = {},            -- lower mob name -> canonical hostile entity name
        mob_counts = {},           -- lower mob name -> number of loaded hostile entities
        next_scan = 0,
        scan_interval = 0.75,
        pending_losses = {},
        batch_deadline = 0,
        pending_prewarns = {},      -- estimated-expiry warnings for crowd control
        prewarn_deadline = 0,
        deferred_losses = {},      -- smart maintenance losses waiting for a usable counter
        next_deferred_check = 0,
        selected_id = 'sleep',
        packet_losses = 0,     -- recognized 0x029 status-loss packets
        last_packet_loss = '',
        advanced_open = T{ false },
    },
    mechanics = nil,
    actionPacket = nil,
    statusPacket = nil,
    reactive = T{
        recent = T{},
        packet_actions = 0,
        last_packet_action = '',
        last_packet_layout = '',
        last_target_count = 0,
        last_status_observation = '',
    },

    timerLearning = T{
        engine = nil,
        entries = {},
        active_timers = {},
        dirty = false,
        next_save = 0,
        selected_key = nil,
        show_ignored = T{ false },
    },

    encounter = encounterRuntime.new_state(),
    activeEncounter = T{
        engine = activeEncounter,
        index = nil,
        state = activeEncounter.new_state(),
    },

    community = T{
        engine = nil,
        json = nil,
        sha256 = nil,
        installed = nil,
        remote_manifest = nil,
        status = 'idle',
        message = 'Not checked yet.',
        check_requested = false,
        update_requested = false,
        rollback_requested = false,
        busy = false,
        auto_check_queued = false,
        backup_available = false,
        loaded_rule_count = 0,
        loaded_catalog_count = 0,
    },

    active = T{
        firing = false,
        name = '',
        text = nil,
        rule_id = nil,
        sound = nil,
        duration = nil,
        severity = 'important',
        prediction = 'reactive',
        startTime = 0,
    },

    alertGuard = T{
        engine = alertGuard,
        state = alertGuard.new_state(),
    },

    critical = T{
        firing = false,
        text = '',
        sound = nil,
        duration = 4.0,
        startTime = 0,
    },
};

--------------------------------------------------------------------------------------------------
-- Settings persistence
--------------------------------------------------------------------------------------------------

local function save_settings()
    settings.save('warn_settings');
end

local function save_rule_settings()
    if (warn.ruleSettings == nil) then
        warn.ruleSettings = T{ overrides = T{} };
    end
    if (warn.ruleSettings.overrides == nil) then
        warn.ruleSettings.overrides = T{};
    end
    settings.save('warn_rule_settings');
end

local function save_ability_settings()
    local enabledMap = T{};
    warn.abilities:each(function (v)
        if (v[2]) then
            enabledMap[v[1]] = true;
        end
    end);
    warn.abilitySettings.enabled = enabledMap;
    settings.save('warn_abilities');
end

-- Ashita v4 builds differ in which optional Dear ImGui helpers they expose.
-- Font scaling is cosmetic, so use it when available and otherwise retain the
-- user's normal ImGui font without allowing the UI callback to fail.
local function set_ui_font_scale(value)
    if (type(imgui.SetWindowFontScale) == 'function') then
        imgui.SetWindowFontScale(value);
    end
end

local function save_learning_data()
    if (warn.learningData == nil) then
        warn.learningData = T{ version = 1, entries = T{} };
    end
    if (warn.learningData.entries == nil) then warn.learningData.entries = T{}; end
    warn.learningData.entries = warn.timerLearning.entries or T{};
    settings.save('warn_learning');
    warn.timerLearning.dirty = false;
end

settings.register('warn_settings', 'warn_settings_update', function (s)
    if (s ~= nil) then warn.settings = s; end
    settings.save('warn_settings');
end);

settings.register('warn_abilities', 'warn_abilities_update', function (s)
    if (s ~= nil) then warn.abilitySettings = s; end
    settings.save('warn_abilities');
end);

settings.register('warn_rule_settings', 'warn_rule_settings_update', function (s)
    if (s ~= nil) then warn.ruleSettings = s; end
    settings.save('warn_rule_settings');
end);

settings.register('warn_learning', 'warn_learning_update', function (s)
    if (s ~= nil) then
        warn.learningData = s;
        if (warn.learningData.entries == nil) then warn.learningData.entries = T{}; end
        warn.timerLearning.entries = warn.learningData.entries;
    end
    settings.save('warn_learning');
end);

--------------------------------------------------------------------------------------------------
-- Ability list management
--------------------------------------------------------------------------------------------------

function rebuild_enabled_lookup()
    warn.enabledLookup = T{};
    warn.abilities:each(function (v)
        if (v[2]) then
            warn.enabledLookup[v[1]:lower()] = v[1];
        end
    end);
end

function load_abilities()
    warn.abilities = T{};
    local seen = {};
    local saved = {};
    if (warn.abilitySettings ~= nil and warn.abilitySettings.enabled ~= nil) then
        for name, enabled in pairs(warn.abilitySettings.enabled) do
            if (enabled == true) then saved[tostring(name):lower()] = true; end
        end
    end

    local function add(name)
        name = trim(tostring(name or ''));
        if (name ~= '') then
            local key = name:lower();
            if (key ~= 'unknown' and not seen[key]) then
                seen[key] = true;
                table.insert(warn.abilities, T{ name, saved[key] == true });
            end
        end
    end

    -- Ashita's local resource table is the primary catalog. This avoids maintaining a
    -- second copy of information the client already exposes and performs no network access.
    local resources = AshitaCore:GetResourceManager();
    if (resources ~= nil) then
        for id = 0, 4095 do
            local ok, name = pcall(function () return resources:GetString('monsters.abilities', id); end);
            if (ok and name ~= nil) then add(name); end
        end
    end

    -- Retain the packaged list only as a compatibility fallback for Ashita installations
    -- where the monster-ability string table is unavailable.
    if (#warn.abilities == 0) then
        local f = io.open(addon.path .. '/data/abilities.txt', 'rb');
        if (f ~= nil) then
            for line in f:lines() do add(line); end
            f:close();
        end
    end

    table.sort(warn.abilities, function (a, b) return tostring(a[1]):lower() < tostring(b[1]):lower(); end);

    rebuild_enabled_lookup();
end

function count_enabled()
    local c = 0;
    warn.abilities:each(function (v)
        if (v[2]) then c = c + 1; end
    end);
    return c;
end

function find_ability_entry(name)
    local lname = name:lower();
    local found = nil;
    warn.abilities:each(function (v)
        if (found == nil and v[1]:lower() == lname) then
            found = v;
        end
    end);
    return found;
end

function set_ability_enabled(name, enabled)
    local entry = find_ability_entry(name);
    if (entry == nil) then
        print(chat.header(addon.name):append(chat.error('Ability not found in ability list: ')):append(chat.warning(name)));
        return;
    end

    entry[2] = enabled;
    save_ability_settings();
    rebuild_enabled_lookup();

    if (enabled) then
        print(chat.header(addon.name):append(chat.message('Now warning on: ')):append(chat.warning(entry[1])));
    else
        print(chat.header(addon.name):append(chat.message('No longer warning on: ')):append(chat.warning(entry[1])));
    end
end

function print_warning_list()
    local c = count_enabled();
    if (c == 0) then
        print(chat.header(addon.name):append(chat.message('No warning abilities configured.')));
        return;
    end

    print(chat.header(addon.name):append(chat.message(string.format('Warning on %d ability/abilities:', c))));
    warn.abilities:each(function (v)
        if (v[2]) then
            print(chat.header(addon.name):append(chat.warning('  - ' .. v[1])));
        end
    end);
end

function clear_warning_list()
    warn.abilities:each(function (v) v[2] = false; end);
    save_ability_settings();
    rebuild_enabled_lookup();
    warn.selectedIndex[1] = -1;
    warn.search[1] = '';
    print(chat.header(addon.name):append(chat.message('Warning list cleared.')));
end

function enable_all_abilities()
    warn.abilities:each(function (v) v[2] = true; end);
    save_ability_settings();
    rebuild_enabled_lookup();
end

function disable_all_abilities()
    warn.abilities:each(function (v) v[2] = false; end);
    save_ability_settings();
    rebuild_enabled_lookup();
end

--------------------------------------------------------------------------------------------------
-- Contextual encounter rules / player capability
--------------------------------------------------------------------------------------------------

local function ensure_context_settings()
    if (warn.settings.context == nil) then
        warn.settings.context = T{
            enabled = true,
            job_counters = true,
            contextual_sounds = true,
            state_triggers = true,
            packet_recognition = true,
            packet_layout = 'auto',
            encounter_hud = true,
            encounter_detection = true,
            encounter_dismiss_seconds = 12,
            encounter_diagnostics = false,
            bumba_element = 'unknown',
            bumba_vengeance = 'v25',
        };
        save_settings();
        return;
    end

    if (warn.settings.context.enabled == nil) then warn.settings.context.enabled = true; end
    if (warn.settings.context.job_counters == nil) then warn.settings.context.job_counters = true; end
    if (warn.settings.context.contextual_sounds == nil) then warn.settings.context.contextual_sounds = true; end
    if (warn.settings.context.state_triggers == nil) then warn.settings.context.state_triggers = true; end
    if (warn.settings.context.packet_recognition == nil) then warn.settings.context.packet_recognition = true; end
    if (warn.settings.context.encounter_hud == nil) then warn.settings.context.encounter_hud = true; end
    if (warn.settings.context.encounter_detection == nil) then warn.settings.context.encounter_detection = true; end
    if (warn.settings.context.encounter_dismiss_seconds == nil) then warn.settings.context.encounter_dismiss_seconds = 12; end
    if (warn.settings.context.encounter_diagnostics == nil) then warn.settings.context.encounter_diagnostics = false; end
    if (warn.settings.context.bumba_element == nil) then warn.settings.context.bumba_element = 'unknown'; end
    if (warn.settings.context.bumba_vengeance == nil) then warn.settings.context.bumba_vengeance = 'v25'; end
    if (warn.settings.context.packet_layout ~= 'retail' and warn.settings.context.packet_layout ~= 'legacy') then
        warn.settings.context.packet_layout = 'auto';
    end
end

local function ensure_ui_settings()
    if (warn.settings.ui == nil) then warn.settings.ui = T{}; end
    local cfg = warn.settings.ui;
    if (cfg.theme == nil) then cfg.theme = 'vana_tactical'; end
    if (cfg.scale_preset == nil) then cfg.scale_preset = 'auto'; end
    if (cfg.custom_scale == nil) then cfg.custom_scale = 1.0; end
    if (cfg.always_on_top == nil) then cfg.always_on_top = true; end
    if (cfg.launcher_enabled == nil) then cfg.launcher_enabled = true; end
    if (cfg.launcher_position_x == nil) then cfg.launcher_position_x = -1; end
    if (cfg.launcher_position_y == nil) then cfg.launcher_position_y = -1; end
    if (cfg.launcher_size == nil) then cfg.launcher_size = 58; end
    if (cfg.controller_enabled == nil) then cfg.controller_enabled = true; end
    if (cfg.controller_layout == nil) then cfg.controller_layout = 'xinput'; end
    if (cfg.show_indexed_only == nil) then cfg.show_indexed_only = false; end
    if (cfg.encounter_collapsed == nil) then cfg.encounter_collapsed = T{}; end
    if (cfg.encounter_hud_x == nil) then cfg.encounter_hud_x = 24; end
    if (cfg.encounter_hud_y == nil) then cfg.encounter_hud_y = 150; end
    if (cfg.encounter_hud_opacity == nil) then cfg.encounter_hud_opacity = 0.86; end

    if (warn.settings.overlay == nil) then warn.settings.overlay = T{}; end
    local overlay = warn.settings.overlay;
    if (overlay.card_opacity == nil) then
        overlay.card_opacity = math.max(0.0, math.min(1.0, 1.0 - (tonumber(overlay.bg_transparency) or 0.15)));
    end
    if (overlay.card_scale == nil) then overlay.card_scale = 1.0; end
    if (overlay.edge_enabled == nil) then overlay.edge_enabled = true; end
    if (overlay.edge_intensity == nil) then overlay.edge_intensity = 0.65; end
    if (overlay.reduced_motion == nil) then overlay.reduced_motion = false; end
    if (overlay.position_anchor == nil) then overlay.position_anchor = 'custom'; end
    if (overlay.burst_protection == nil) then overlay.burst_protection = true; end
    if (overlay.repeat_suppression == nil) then overlay.repeat_suppression = 1.25; end
    if (overlay.alert_queue_limit == nil) then overlay.alert_queue_limit = 4; end
    if (overlay.alert_queue_max_age == nil) then overlay.alert_queue_max_age = 6.0; end
end

local function ensure_sound_settings()
    if (warn.settings.sound == nil) then warn.settings.sound = T{}; end
    local cfg = warn.settings.sound;
    if (cfg.enabled == nil) then cfg.enabled = true; end
    if (cfg.selected == nil or cfg.selected == '') then cfg.selected = 'msg.wav'; end
    if (cfg.first_open_enabled == nil) then cfg.first_open_enabled = true; end
    if (cfg.first_open_selected == nil or cfg.first_open_selected == '') then
        cfg.first_open_selected = 'firstopen.wav';
    end
    if (cfg.first_open_session == nil) then cfg.first_open_session = ''; end
end

local function get_ui_scale()
    ensure_ui_settings();
    local cfg = warn.settings.ui;
    if (cfg.scale_preset == '1440p') then return 1.0; end
    if (cfg.scale_preset == '1080p') then return 0.75; end
    if (cfg.scale_preset == 'custom') then
        return math.max(0.60, math.min(1.75, tonumber(cfg.custom_scale) or 1.0));
    end
    local display = imgui.GetIO().DisplaySize;
    local height = display ~= nil and tonumber(display.y) or 1440;
    return math.max(0.75, math.min(1.50, height / 1440));
end

local function reload_ui_theme()
    ensure_ui_settings();
    warn.ui.theme = uiTheme.load(addon.path, warn.settings.ui.theme);
    warn.ui.launcher_texture = uiTextures.load(uiTheme.launcher_path(warn.ui.theme));
    warn.ui.role_textures = T{};
    for _, icon in ipairs({ 'shield', 'potion', 'bow', 'harp' }) do
        warn.ui.role_textures[icon] = uiTextures.load(uiTheme.role_icon_path(warn.ui.theme, icon));
    end
end

local function ensure_responsibility_settings()
    if (warn.settings.responsibilities == nil) then warn.settings.responsibilities = T{}; end
    if (warn.settings.responsibilities.profiles == nil) then warn.settings.responsibilities.profiles = T{}; end
end

local function ensure_learning_settings()
    if (warn.settings.learning == nil) then
        warn.settings.learning = T{
            enabled = true,
            minimum_uses = 3,
            minimum_interval = 5,
            maximum_interval = 900,
            confidence_threshold = 0.80,
        };
    end

    local learning = warn.settings.learning;
    if (learning.enabled == nil) then learning.enabled = true; end
    if (learning.minimum_uses == nil) then learning.minimum_uses = 3; end
    if (learning.minimum_interval == nil) then learning.minimum_interval = 5; end
    if (learning.maximum_interval == nil) then learning.maximum_interval = 900; end
    if (learning.confidence_threshold == nil) then learning.confidence_threshold = 0.80; end
end

local function ensure_community_settings()
    if (warn.settings.community == nil) then
        warn.settings.community = T{
            enabled = true,
            auto_check = true,
            check_interval_hours = 24,
            last_checked_at = 0,
        };
    end
    local cfg = warn.settings.community;
    if (cfg.enabled == nil) then cfg.enabled = true; end
    if (cfg.auto_check == nil) then cfg.auto_check = true; end
    if (cfg.check_interval_hours == nil) then cfg.check_interval_hours = 24; end
    if (cfg.last_checked_at == nil) then cfg.last_checked_at = 0; end
end

local function load_data_module(filename, requiredFunction)
    local path = addon.path .. '/data/' .. filename;
    local chunk, loadErr = loadfile(path);
    if (chunk == nil) then return nil, 'Failed to load ' .. filename .. ': ' .. tostring(loadErr); end
    local ok, module = pcall(chunk);
    if (not ok or type(module) ~= 'table') then return nil, 'Invalid ' .. filename .. ': ' .. tostring(module); end
    if (requiredFunction ~= nil and type(module[requiredFunction]) ~= 'function') then
        return nil, filename .. ' is missing ' .. requiredFunction;
    end
    return module;
end

local function load_community_modules()
    local json, err = load_data_module('json.lua', 'decode');
    if (json == nil) then return false, err; end
    local sha256; sha256, err = load_data_module('sha256.lua', 'digest');
    if (sha256 == nil) then return false, err; end
    local engine; engine, err = load_data_module('community.lua', 'validate_database');
    if (engine == nil) then return false, err; end
    warn.community.json = json;
    warn.community.sha256 = sha256;
    warn.community.engine = engine;
    return true;
end

local function load_mechanic_modules()
    local policy, err = load_data_module('mechanics.lua', 'normalize_rule');
    if (policy == nil) then return false, err; end
    local packet; packet, err = load_data_module('action_packet.lua', 'parse');
    if (packet == nil) then return false, err; end
    local statusPacket; statusPacket, err = load_data_module('status_packet.lua', 'parse');
    if (statusPacket == nil) then return false, err; end
    warn.mechanics = policy;
    warn.actionPacket = packet;
    warn.statusPacket = statusPacket;
    return true;
end

local function load_timer_learning()
    local path = addon.path .. '/data/timer_learning.lua';
    local chunk, loadErr = loadfile(path);
    if (chunk == nil) then
        print(chat.header(addon.name):append(chat.error('Failed to load data/timer_learning.lua: ' .. tostring(loadErr))));
        return false;
    end

    local ok, engine = pcall(chunk);
    if (not ok or type(engine) ~= 'table' or type(engine.record) ~= 'function') then
        print(chat.header(addon.name):append(chat.error('Invalid data/timer_learning.lua: ' .. tostring(engine))));
        return false;
    end

    warn.timerLearning.engine = engine;
    if (warn.learningData == nil) then warn.learningData = T{ version = 1, entries = T{} }; end
    if (warn.learningData.entries == nil) then warn.learningData.entries = T{}; end
    warn.timerLearning.entries = warn.learningData.entries;
    return true;
end

local function ensure_debuff_settings()
    if (warn.settings.debuffs == nil) then
        warn.settings.debuffs = T{
            enabled = true,
            smart_reapply = true,
            sound_enabled = true,
            critical_center = true,
            batch_window = 0.20,
            alert_duration = 4.0,
            show_estimates = true,
            prewarn_enabled = true,
            prewarn_seconds = 5.0,
            statuses = T{},
        };
    end

    if (warn.settings.debuffs.enabled == nil) then warn.settings.debuffs.enabled = true; end
    if (warn.settings.debuffs.smart_reapply == nil) then warn.settings.debuffs.smart_reapply = true; end
    if (warn.settings.debuffs.sound_enabled == nil) then warn.settings.debuffs.sound_enabled = true; end
    if (warn.settings.debuffs.critical_center == nil) then warn.settings.debuffs.critical_center = true; end
    if (warn.settings.debuffs.batch_window == nil) then warn.settings.debuffs.batch_window = 0.20; end
    if (warn.settings.debuffs.alert_duration == nil) then warn.settings.debuffs.alert_duration = 4.0; end
    if (warn.settings.debuffs.show_estimates == nil) then warn.settings.debuffs.show_estimates = true; end
    if (warn.settings.debuffs.prewarn_enabled == nil) then warn.settings.debuffs.prewarn_enabled = true; end
    if (warn.settings.debuffs.prewarn_seconds == nil) then warn.settings.debuffs.prewarn_seconds = 5.0; end
    if (warn.settings.debuffs.statuses == nil) then warn.settings.debuffs.statuses = T{}; end
end

local function get_debuff_override(definition, create)
    if (definition == nil or definition.id == nil) then return nil; end
    ensure_debuff_settings();
    local key = tostring(definition.id):lower();
    local override = warn.settings.debuffs.statuses[key];
    if (override == nil and create) then
        override = T{};
        warn.settings.debuffs.statuses[key] = override;
    end
    return override;
end

local function load_debuff_definitions()
    warn.debuffs.definitions = {};
    warn.debuffs.lookup = {};

    local path = addon.path .. '/data/debuffs.lua';
    local chunk, loadErr = loadfile(path);
    if (chunk == nil) then
        print(chat.header(addon.name):append(chat.error('Failed to load data/debuffs.lua: ' .. tostring(loadErr))));
        return false;
    end

    local ok, data = pcall(chunk);
    if (not ok or type(data) ~= 'table') then
        print(chat.header(addon.name):append(chat.error('Invalid data/debuffs.lua: ' .. tostring(data))));
        return false;
    end

    local list = data.statuses or data;
    if (type(list) ~= 'table') then
        print(chat.header(addon.name):append(chat.error('data/debuffs.lua does not contain a status list.')));
        return false;
    end

    local seen = {};
    for _, definition in ipairs(list) do
        if (type(definition) == 'table' and definition.id ~= nil and definition.name ~= nil) then
            local id = tostring(definition.id):lower();
            if (not seen[id]) then
                seen[id] = true;
                definition.id = id;
                table.insert(warn.debuffs.definitions, definition);
                warn.debuffs.lookup[id] = definition;
                warn.debuffs.lookup[tostring(definition.name):lower()] = definition;
            end
        end
    end

    table.sort(warn.debuffs.definitions, function (a, b)
        local ca = tostring(a.category or '');
        local cb = tostring(b.category or '');
        if (ca == cb) then return tostring(a.name):lower() < tostring(b.name):lower(); end
        return ca < cb;
    end);

    -- Migrate the dedicated v1.5.x Sleep / Petrify preferences once, without
    -- deleting the old values from a user's settings file.
    ensure_debuff_settings();
    if (warn.settings.debuffs.migrated_legacy ~= true) then
        if (warn.settings.sleep ~= nil) then
            local def = warn.debuffs.lookup['sleep'];
            if (def ~= nil) then
                local ov = get_debuff_override(def, true);
                if (warn.settings.sleep.enabled ~= nil) then ov.enabled = warn.settings.sleep.enabled; end
                if (warn.settings.sleep.wake_sound ~= nil) then ov.sound = warn.settings.sleep.wake_sound; end
            end
        end
        if (warn.settings.petrify ~= nil) then
            local def = warn.debuffs.lookup['petrify'];
            if (def ~= nil) then
                local ov = get_debuff_override(def, true);
                if (warn.settings.petrify.enabled ~= nil) then ov.enabled = warn.settings.petrify.enabled; end
                if (warn.settings.petrify.recovery_sound ~= nil) then ov.sound = warn.settings.petrify.recovery_sound; end
            end
        end
        warn.settings.debuffs.migrated_legacy = true;
        save_settings();
    end

    if (warn.debuffs.selected_id == nil or warn.debuffs.lookup[warn.debuffs.selected_id] == nil) then
        warn.debuffs.selected_id = (#warn.debuffs.definitions > 0) and warn.debuffs.definitions[1].id or nil;
    end

    return true;
end

local function read_binary_file(path, maximumBytes)
    local file = io.open(path, 'rb');
    if (file == nil) then return nil, 'File not found: ' .. tostring(path); end
    local body = file:read('*a');
    file:close();
    if (body == nil) then return nil, 'Could not read: ' .. tostring(path); end
    if (maximumBytes ~= nil and #body > maximumBytes) then return nil, 'File exceeds the size limit.'; end
    return body;
end

local function decode_json(body, label)
    if (warn.community.json == nil) then return nil, 'JSON decoder is unavailable.'; end
    local ok, value = pcall(warn.community.json.decode, body);
    if (not ok) then return nil, tostring(label or 'JSON') .. ': ' .. tostring(value); end
    return value;
end

local function decode_community_database(body, expectedVersion)
    local raw, err = decode_json(body, 'Community database');
    if (raw == nil) then return nil, err; end
    local validated; validated, err = warn.community.engine.validate_database(raw);
    if (validated == nil) then return nil, 'Community database rejected: ' .. tostring(err); end
    if (expectedVersion ~= nil and tonumber(validated.database_version) ~= tonumber(expectedVersion)) then
        return nil, 'Database version does not match its manifest.';
    end
    return validated;
end

local function community_data_path(suffix)
    return addon.path .. '/data/community.json' .. tostring(suffix or '');
end

local function update_community_backup_state()
    local file = io.open(community_data_path('.bak'), 'rb');
    warn.community.backup_available = file ~= nil;
    if (file ~= nil) then file:close(); end
end

local function load_installed_community_database(announce)
    warn.community.installed = nil;
    warn.community.loaded_rule_count = 0;
    warn.community.loaded_catalog_count = 0;
    update_community_backup_state();

    if (warn.community.engine == nil) then return false; end
    local body, err = read_binary_file(community_data_path(), 2 * 1024 * 1024);
    if (body == nil) then
        warn.community.message = 'No installed community database.';
        if (announce) then print(chat.header(addon.name):append(chat.warning(warn.community.message))); end
        return false;
    end
    local database; database, err = decode_community_database(body, nil);
    if (database == nil) then
        warn.community.status = 'error';
        warn.community.message = err;
        if (announce) then print(chat.header(addon.name):append(chat.error(err))); end
        return false;
    end
    warn.community.installed = database;
    warn.community.loaded_rule_count = #(database.ability_rules or {}) + #(database.state_rules or {});
    warn.community.loaded_catalog_count = #(database.catalog or {});
    return true;
end

function load_context_rules()
    warn.rules = { ability_rules = {}, state_rules = {}, catalog = {} };
    warn.ruleState = {};

    local path = addon.path .. '/data/rules.lua';
    local chunk, loadErr = loadfile(path);
    if (chunk == nil) then
        print(chat.header(addon.name):append(chat.error('Failed to load data/rules.lua: ' .. tostring(loadErr))));
        return;
    end

    local ok, data = pcall(chunk);
    if (not ok or type(data) ~= 'table') then
        print(chat.header(addon.name):append(chat.error('Invalid data/rules.lua: ' .. tostring(data))));
        return;
    end

    warn.rules.ability_rules = data.ability_rules or {};
    warn.rules.state_rules = data.state_rules or {};
    warn.rules.catalog = data.catalog or {};

    ensure_community_settings();
    if (warn.settings.community.enabled and warn.community.engine ~= nil and warn.community.installed ~= nil) then
        warn.rules = warn.community.engine.merge(warn.rules, warn.community.installed);
    end

    if (warn.mechanics ~= nil) then
        for _, rule in ipairs(warn.rules.ability_rules or {}) do warn.mechanics.normalize_rule(rule); end
        for _, rule in ipairs(warn.rules.state_rules or {}) do warn.mechanics.normalize_rule(rule); end
    end

    for _, rule in ipairs(warn.rules.state_rules) do
        if (rule.id ~= nil) then
            warn.ruleState[rule.id] = {
                index = nil,
                present = false,
                triggered = false,
                last_x = nil,
                last_y = nil,
                last_z = nil,
                last_trigger = 0,
                armed = true,
                stationary_since = nil,
                status_active = nil,
                last_status_change = 0,
                last_hpp = nil,
            };
        end
    end

    warn.activeEncounter.index = warn.activeEncounter.engine.build_index(
        warn.rules.catalog, warn.rules.ability_rules, warn.rules.state_rules);
    -- Reloading curated/community data should preserve an active profile only when the
    -- same stable content/group/encounter key still exists in the rebuilt index.
    if (warn.activeEncounter.state.active_key ~= nil and
        warn.activeEncounter.index.profiles[warn.activeEncounter.state.active_key] == nil) then
        warn.activeEncounter.engine.clear(warn.activeEncounter.state, 'database reloaded', os.clock());
    end
end

local function ensure_rule_settings()
    if (warn.ruleSettings == nil) then
        warn.ruleSettings = T{ overrides = T{} };
    end
    if (warn.ruleSettings.overrides == nil) then
        warn.ruleSettings.overrides = T{};
    end
end

local function get_all_context_rules()
    local all = {};
    for _, rule in ipairs(warn.rules.ability_rules or {}) do
        rule.__rule_type = 'ability';
        table.insert(all, rule);
    end
    for _, rule in ipairs(warn.rules.state_rules or {}) do
        rule.__rule_type = 'state';
        table.insert(all, rule);
    end
    table.sort(all, function (a, b)
        local ac = tostring(a.content or 'Other'):lower();
        local bc = tostring(b.content or 'Other'):lower();
        if (ac ~= bc) then return ac < bc; end
        local ae = tostring(a.encounter or a.actor or ''):lower();
        local be = tostring(b.encounter or b.actor or ''):lower();
        if (ae ~= be) then return ae < be; end
        return tostring(a.ability or a.id or ''):lower() < tostring(b.ability or b.id or ''):lower();
    end);
    return all;
end

local function find_context_rule_by_id(id)
    if (id == nil) then return nil; end
    local wanted = tostring(id):lower();
    for _, rule in ipairs(warn.rules.ability_rules or {}) do
        if (tostring(rule.id or ''):lower() == wanted) then return rule; end
    end
    for _, rule in ipairs(warn.rules.state_rules or {}) do
        if (tostring(rule.id or ''):lower() == wanted) then return rule; end
    end
    return nil;
end

local function get_rule_override(rule, create)
    if (rule == nil or rule.id == nil) then return nil; end
    ensure_rule_settings();
    local key = tostring(rule.id);
    local override = warn.ruleSettings.overrides[key];
    if (override == nil and create) then
        override = T{};
        warn.ruleSettings.overrides[key] = override;
    end
    return override;
end

local function is_rule_enabled(rule)
    local override = get_rule_override(rule, false);
    if (override ~= nil and override.enabled ~= nil) then
        return override.enabled == true;
    end
    return rule.enabled ~= false;
end

local function set_rule_enabled(rule, enabled)
    local override = get_rule_override(rule, true);
    override.enabled = enabled == true;
    save_rule_settings();
end

-- Returns the effective contextual sound and whether the user explicitly overrode it.
-- '__default__' means use the rule database's sound; 'None' intentionally suppresses sound.
local function resolve_rule_sound(rule)
    local override = get_rule_override(rule, false);
    if (override ~= nil and override.sound ~= nil and override.sound ~= '__default__') then
        if (override.sound == 'None') then
            return 'None', true;
        end

        -- Preserve custom sound overrides only while that WAV still exists. If the
        -- user later removes the file, gracefully fall back to the database default.
        local wanted = tostring(override.sound):lower();
        for i = 1, #warn.soundFiles do
            if (tostring(warn.soundFiles[i]):lower() == wanted) then
                return warn.soundFiles[i], true;
            end
        end
    end
    return rule.sound, false;
end

local function set_rule_sound_override(rule, value)
    local override = get_rule_override(rule, true);
    override.sound = value or '__default__';
    save_rule_settings();
end

local function reset_rule_override(rule)
    if (rule == nil or rule.id == nil) then return; end
    ensure_rule_settings();
    warn.ruleSettings.overrides[tostring(rule.id)] = nil;
    save_rule_settings();
end

local function get_rule_display_name(rule)
    if (rule == nil) then return 'Unknown Rule'; end
    local actor = rule.actor and tostring(rule.actor) or nil;
    local ability = rule.ability and tostring(rule.ability) or nil;
    if (actor ~= nil and ability ~= nil) then return actor .. ' - ' .. ability; end
    if (ability ~= nil) then return ability; end
    if (actor ~= nil) then return '[STATE] ' .. actor; end
    return tostring(rule.id or 'Unknown Rule');
end

local function get_player_job_text()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then return 'Unknown'; end

    local jobAbbr = {
        [0] = 'NON', [1] = 'WAR', [2] = 'MNK', [3] = 'WHM', [4] = 'BLM',
        [5] = 'RDM', [6] = 'THF', [7] = 'PLD', [8] = 'DRK', [9] = 'BST',
        [10] = 'BRD', [11] = 'RNG', [12] = 'SAM', [13] = 'NIN', [14] = 'DRG',
        [15] = 'SMN', [16] = 'BLU', [17] = 'COR', [18] = 'PUP', [19] = 'DNC',
        [20] = 'SCH', [21] = 'GEO', [22] = 'RUN',
    };

    local mainId = player:GetMainJob();
    local subId = player:GetSubJob();
    local main = jobAbbr[mainId] or tostring(mainId);
    local sub = jobAbbr[subId] or tostring(subId);
    return string.format('%s%d/%s%d', main, player:GetMainJobLevel(), sub, player:GetSubJobLevel());
end

local function get_player_profile_identity()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then return nil; end

    local name = 'Unknown Character';
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party ~= nil) then
        local ok, value = pcall(function () return party:GetMemberName(0); end);
        if (ok and value ~= nil and tostring(value) ~= '') then name = tostring(value); end
        if (name == 'Unknown Character') then
            local index = party:GetMemberTargetIndex(0);
            local entityManager = AshitaCore:GetMemoryManager():GetEntity();
            local entity = entityManager ~= nil and entityManager:GetRawEntity(index) or nil;
            if (entity ~= nil and entity.Name ~= nil and tostring(entity.Name) ~= '') then name = tostring(entity.Name); end
        end
    end
    if (name == 'Unknown Character') then return nil; end
    return name, tonumber(player:GetMainJob()) or 0, tonumber(player:GetSubJob()) or 0;
end

local function get_current_responsibility_profile(create)
    ensure_responsibility_settings();
    if (warn.mechanics == nil) then return nil, nil; end
    local name, mainJob, subJob = get_player_profile_identity();
    if (name == nil) then return nil, nil; end
    local key = warn.mechanics.profile_key(name, mainJob, subJob);
    local profile = warn.settings.responsibilities.profiles[key];
    if (profile == nil and create) then
        local defaults = warn.mechanics.default_profile(mainJob);
        profile = T{};
        for responsibility, enabled in pairs(defaults) do profile[responsibility] = enabled; end
        warn.settings.responsibilities.profiles[key] = profile;
        save_settings();
    end
    return profile, key;
end

local function counter_is_assigned(counter)
    if (warn.mechanics == nil) then return true; end
    local profile = get_current_responsibility_profile(true);
    if (profile == nil) then return true; end
    local assigned = warn.mechanics.counter_is_assigned(counter, profile);
    return assigned == true;
end

local function find_spell_resource(name)
    if (name == nil or name == '') then return nil; end
    local key = name:lower();
    if (warn.spellCache[key] ~= nil) then
        return warn.spellCache[key] ~= false and warn.spellCache[key] or nil;
    end

    local rm = AshitaCore:GetResourceManager();
    for id = 0, 2048 do
        local spell = rm:GetSpellById(id);
        if (spell ~= nil and spell.Name ~= nil and spell.Name[1] ~= nil) then
            if (tostring(spell.Name[1]):lower() == key) then
                warn.spellCache[key] = spell;
                return spell;
            end
        end
    end

    warn.spellCache[key] = false;
    return nil;
end

local function spell_job_usable(spell, player)
    if (spell == nil or player == nil or spell.LevelRequired == nil) then return false; end

    local mainJob = player:GetMainJob();
    local subJob = player:GetSubJob();
    local mainLevel = player:GetMainJobLevel();
    local subLevel = player:GetSubJobLevel();

    -- Official Ashita v4 blucheck indexes LevelRequired with jobId + 1.
    local mainReq = spell.LevelRequired[mainJob + 1] or 0xFF;
    local subReq = spell.LevelRequired[subJob + 1] or 0xFF;

    local mainOk = mainReq > 0 and mainReq < 0xFF and mainLevel >= mainReq;
    local subOk = subReq > 0 and subReq < 0xFF and subLevel >= subReq;
    return mainOk or subOk;
end

local function can_use_spell_now(name)
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then return false, nil, 'player data unavailable'; end
    if (not player:HasSpellData()) then return false, nil, 'spell data not loaded'; end

    local spell = find_spell_resource(name);
    if (spell == nil) then return false, nil, 'spell not found in resources'; end
    if (not player:HasSpell(spell.Id)) then return false, spell, 'spell not learned'; end
    if (not spell_job_usable(spell, player)) then return false, spell, 'current main/sub job cannot cast it'; end

    -- Only offer the counter if the player has enough MP right now.
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party ~= nil and spell.ManaCost ~= nil) then
        local currentMp = party:GetMemberMP(0);
        if (currentMp ~= nil and currentMp < spell.ManaCost) then
            return false, spell, string.format('not enough MP (%d/%d)', currentMp, spell.ManaCost);
        end
    end

    local recast = AshitaCore:GetMemoryManager():GetRecast();
    if (recast ~= nil and recast:GetSpellTimer(spell.Id) > 0) then
        return false, spell, 'spell is on recast';
    end

    return true, spell, 'available';
end

-- Blue Magic must be SET before it can be cast. Ashita's own v4 blusets addon reads
-- the active BLU spell slots from the inventory buffer; use the same verified layout
-- here, read-only, so job-aware encounter advice never recommends an unset BLU spell.
local function init_blu_spell_reader()
    if (warn.bluReader.initialized) then
        return warn.bluReader.available;
    end

    warn.bluReader.initialized = true;

    local ok, address = pcall(function ()
        return ashita.memory.find(0, 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0);
    end);
    if (not ok or address == nil or address == 0) then
        warn.bluReader.error = 'failed to locate BLU spell-set offset';
        return false;
    end

    local castOk, offset = pcall(function ()
        return ffi.cast('uint32_t*', address);
    end);
    if (not castOk or offset == nil) then
        warn.bluReader.error = 'failed to initialize BLU spell-set reader';
        return false;
    end

    warn.bluReader.offset = offset;
    warn.bluReader.available = true;
    return true;
end

local function get_set_blu_spell_ids()
    local result = {};
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then return result, 'player data unavailable'; end

    local mainIsBlu = (player:GetMainJob() == 16);
    local subIsBlu = (player:GetSubJob() == 16);
    if (not mainIsBlu and not subIsBlu) then
        return result, 'BLU is not current main/sub job';
    end

    if (not init_blu_spell_reader()) then
        return result, warn.bluReader.error or 'BLU spell-set reader unavailable';
    end

    local ptr = AshitaCore:GetPointerManager():Get('inventory');
    if (ptr == nil or ptr == 0) then return result, 'inventory pointer unavailable'; end

    ptr = ashita.memory.read_uint32(ptr);
    if (ptr == nil or ptr == 0) then return result, 'inventory buffer unavailable'; end

    local offsetValue = tonumber(warn.bluReader.offset[0]);
    if (offsetValue == nil or offsetValue == 0) then return result, 'BLU spell-set offset unavailable'; end

    local slotOffset = mainIsBlu and 0x04 or 0xA0;
    local ok, slots = pcall(function ()
        return ashita.memory.read_array(ptr + offsetValue + slotOffset, 0x14);
    end);
    if (not ok or slots == nil) then return result, 'failed to read BLU spell slots'; end

    for _, rawId in ipairs(slots) do
        rawId = tonumber(rawId) or 0;
        if (rawId > 0) then
            result[rawId + 512] = true;
        end
    end
    return result, 'available';
end

local function can_use_blu_spell_now(name)
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then return false, nil, 'player data unavailable'; end
    if (not player:HasSpellData()) then return false, nil, 'spell data not loaded'; end

    local spell = find_spell_resource(name);
    if (spell == nil) then return false, nil, 'spell not found in resources'; end
    if (tonumber(spell.Skill) ~= 43) then return false, spell, 'not a Blue Magic spell'; end
    if (not player:HasSpell(spell.Id)) then return false, spell, 'spell not learned'; end
    if (not spell_job_usable(spell, player)) then return false, spell, 'current main/sub job cannot cast it'; end

    local setSpells, setReason = get_set_blu_spell_ids();
    if (not setSpells[spell.Id]) then
        return false, spell, (setReason == 'available') and 'Blue Magic spell is not currently set' or setReason;
    end

    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party ~= nil and spell.ManaCost ~= nil) then
        local currentMp = party:GetMemberMP(0);
        if (currentMp ~= nil and currentMp < spell.ManaCost) then
            return false, spell, string.format('not enough MP (%d/%d)', currentMp, spell.ManaCost);
        end
    end

    local recast = AshitaCore:GetMemoryManager():GetRecast();
    if (recast ~= nil and recast:GetSpellTimer(spell.Id) > 0) then
        return false, spell, 'spell is on recast';
    end

    return true, spell, 'available';
end

local function get_available_counter(rule)
    if (rule == nil or not warn.settings.context.job_counters) then
        return nil;
    end

    -- Support both the initial single-counter schema and a future list of alternatives.
    local candidates = rule.counters;
    if (candidates == nil and rule.counter ~= nil) then
        candidates = { rule.counter };
    end
    if (candidates == nil) then return nil; end

    for _, counter in ipairs(candidates) do
        if (counter_is_assigned(counter) and counter.type == 'spell') then
            local ok = can_use_spell_now(counter.name);
            if (ok) then return counter; end
        elseif (counter_is_assigned(counter) and counter.type == 'blu_spell') then
            local ok = can_use_blu_spell_now(counter.name);
            if (ok) then return counter; end
        end
        -- Additional counter types (job abilities, items, etc.) can be added here only
        -- after their Ashita v4 availability checks are verified.
    end

    return nil;
end

local function build_context_text(rule, messageOverride, context)
    if (rule == nil) then return nil, nil; end

    local counter = get_available_counter(rule);
    -- Critical mechanic facts always remain visible.  Responsibility and capability
    -- filtering only remove the action instruction, never the critical warning itself.
    if (rule.only_if_counter_available and counter == nil and rule.severity ~= 'critical') then
        return nil, nil;
    end

    local text = messageOverride or rule.message or rule.ability or rule.actor or 'WARNING';
    if (text:find('{target}', 1, true) ~= nil) then
        local targetName = context ~= nil and trim(tostring(context.target_name or '')) or '';
        text = text:gsub('{target}', targetName ~= '' and targetName or 'TARGETED PLAYER');
    end
    if (counter ~= nil) then
        text = text .. '\n' .. (counter.label or counter.name:upper());
    end
    return text, counter;
end

local function raw_message_has_actor(message, actor)
    if (actor == nil or actor == '') then return true; end
    if (message == nil) then return false; end
    return message:lower():find(actor:lower(), 1, true) ~= nil;
end

local function raw_message_matches_rule_actor(message, rule)
    if (rule.actor == nil) then return true; end
    if (raw_message_has_actor(message, rule.actor)) then return true; end
    for _, alias in ipairs(rule.actor_aliases or {}) do
        if (raw_message_has_actor(message, tostring(alias))) then return true; end
    end
    return false;
end

local function find_context_ability_rule(eventType, abilityName, rawMessage)
    if (not warn.settings.context.enabled or abilityName == nil or abilityName == '') then
        return nil;
    end

    local lname = abilityName:lower();
    local actorMatches = {};
    local genericMatches = {};
    for _, rule in ipairs(warn.rules.ability_rules or {}) do
        if (is_rule_enabled(rule)) then
        local eventMatches = (rule.event == nil or rule.event == eventType);
        local abilityMatches = (rule.ability ~= nil and rule.ability:lower() == lname);
        if (not abilityMatches and rule.aliases ~= nil) then
            for _, alias in ipairs(rule.aliases) do
                if (tostring(alias):lower() == lname) then
                    abilityMatches = true;
                    break
                end
            end
        end
        if (eventMatches and abilityMatches) then
            if (rule.actor ~= nil) then
                if (raw_message_matches_rule_actor(rawMessage, rule)) then
                    table.insert(actorMatches, rule);
                end
            else
                table.insert(genericMatches, rule);
            end
        end
        end
    end
    local selected = warn.activeEncounter.engine.select_matching_rule(
        warn.activeEncounter.index, warn.activeEncounter.state, actorMatches);
    if (selected ~= nil) then return selected; end
    if (#actorMatches > 0) then return nil; end
    return warn.activeEncounter.engine.select_matching_rule(
        warn.activeEncounter.index, warn.activeEncounter.state, genericMatches);
end

local function find_entity_by_name(name, cachedIndex)
    local entityManager = AshitaCore:GetMemoryManager():GetEntity();
    if (entityManager == nil) then return nil, nil; end

    if (cachedIndex ~= nil) then
        local entity = entityManager:GetRawEntity(cachedIndex);
        if (entity ~= nil and entity.Name == name) then
            return cachedIndex, entity;
        end
    end

    local mapSize = entityManager:GetEntityMapSize();
    for i = 0, mapSize - 1 do
        local entity = entityManager:GetRawEntity(i);
        if (entity ~= nil and entity.Name == name) then
            return i, entity;
        end
    end

    return nil, nil;
end

local function entity_position(entity)
    if (entity == nil or entity.Movement == nil or entity.Movement.LocalPosition == nil) then
        return nil, nil, nil;
    end
    local p = entity.Movement.LocalPosition;
    return tonumber(p.X), tonumber(p.Y), tonumber(p.Z);
end

local function activate_warning_payload(payload)
    if (payload == nil) then return false; end
    warn.active.name = payload.name or 'WARNING';
    warn.active.text = payload.text;
    warn.active.rule_id = payload.rule_id;
    warn.active.sound = payload.sound;
    warn.active.sound_overridden = payload.sound_overridden;
    warn.active.sound_policy = payload.sound_policy;
    warn.active.duration = payload.duration;
    warn.active.severity = tostring(payload.severity or 'important'):lower();
    warn.active.prediction = tostring(payload.prediction or 'reactive'):lower();
    warn.active.dedupe_key = payload.dedupe_key;
    warn.active.startTime = os.clock();
    warn.active.firing = true;

    if (payload.sound_policy == 'debuff') then
        if (warn.settings.debuffs.sound_enabled) then play_sound_file(payload.sound); end
    elseif (payload.sound_policy == 'global') then
        if (warn.settings.sound.enabled) then play_selected_sound(); end
    elseif (warn.settings.sound.enabled) then
        if (warn.settings.context.contextual_sounds) then
            if (payload.sound_overridden) then
                play_sound_file(payload.sound);
            elseif (payload.sound ~= nil and payload.sound ~= '') then
                play_sound_file(payload.sound);
            else
                play_selected_sound();
            end
        else
            play_selected_sound();
        end
    end
    return true;
end

local function submit_warning_payload(payload)
    if (payload == nil) then return false; end
    ensure_ui_settings();
    local overlay = warn.settings.overlay;
    if (overlay.burst_protection ~= true) then return activate_warning_payload(payload); end

    local currentlyVisible = nil;
    if (warn.critical.firing) then
        currentlyVisible = { firing=true, severity='critical', dedupe_key='__critical_debuff__' };
    elseif (warn.active.firing) then
        currentlyVisible = warn.active;
    end
    local decision, ready = warn.alertGuard.engine.submit(
        warn.alertGuard.state, payload, currentlyVisible, os.clock(), {
            dedupe_window=overlay.repeat_suppression,
            queue_limit=overlay.alert_queue_limit,
            max_age=overlay.alert_queue_max_age,
        });
    if (ready ~= nil) then activate_warning_payload(ready); end
    if (warn.debug and (decision == 'suppressed' or decision == 'dropped')) then
        print(chat.header(addon.name):append(chat.message('Alert burst protection: ' .. tostring(decision) ..
            ' ' .. tostring(payload.rule_id or payload.name or 'warning'))));
    end
    -- Suppressed and capacity-dropped events are still handled. Returning true prevents
    -- state rules from retrying the same burst every entity-scan frame.
    return true;
end

local function trigger_context_rule(rule, fallbackName, messageOverride, context)
    if (rule == nil or rule.verified ~= true or not is_rule_enabled(rule)) then return false; end

    local text = build_context_text(rule, messageOverride, context);
    if (text == nil) then return false; end

    local effectiveSound, overridden = resolve_rule_sound(rule);
    submit_warning_payload({
        name=fallbackName or rule.ability or rule.actor or 'WARNING',
        text=text, rule_id=rule.id, dedupe_key=rule.id,
        sound=effectiveSound, sound_overridden=overridden, sound_policy='context',
        duration=rule.duration, severity=tostring(rule.severity or 'important'):lower(),
        prediction=tostring(rule.prediction or 'reactive'):lower(),
    });

    if (warn.debug) then
        print(chat.header(addon.name):append(chat.message('Context rule: ' .. tostring(rule.id))));
    end
    return true;
end

--------------------------------------------------------------------------------------------------
-- Global debuff / crowd-control engine
--------------------------------------------------------------------------------------------------

local function get_debuff_definition(idOrName)
    if (idOrName == nil) then return nil; end
    return warn.debuffs.lookup[tostring(idOrName):lower()];
end

local function is_debuff_enabled(definition)
    if (definition == nil) then return false; end
    ensure_debuff_settings();
    if (not warn.settings.debuffs.enabled) then return false; end
    local override = get_debuff_override(definition, false);
    if (override ~= nil and override.enabled ~= nil) then
        return override.enabled == true;
    end
    return definition.default_enabled ~= false;
end

local function set_debuff_enabled(definition, enabled)
    if (definition == nil) then return; end
    local override = get_debuff_override(definition, true);
    override.enabled = enabled == true;
    if (not enabled) then
        warn.debuffs.tracked[definition.id] = nil;
        for key, pending in pairs(warn.debuffs.deferred_losses or {}) do
            if pending.status_id == definition.id then warn.debuffs.deferred_losses[key] = nil; end
        end
        for key, pending in pairs(warn.debuffs.pending_prewarns or {}) do
            if pending.status_id == definition.id then warn.debuffs.pending_prewarns[key] = nil; end
        end
    end
    save_settings();
end

local function debuff_only_if_capable(definition)
    if (definition == nil) then return false; end
    local override = get_debuff_override(definition, false);
    if (override ~= nil and override.only_if_capable ~= nil) then
        return override.only_if_capable == true;
    end
    if (definition.alert_policy == 'smart') then
        return warn.settings.debuffs.smart_reapply == true;
    end
    return false;
end

local function resolve_debuff_sound(definition)
    if (definition == nil) then return warn.settings.sound.selected; end
    local override = get_debuff_override(definition, false);
    local selected = (override ~= nil and override.sound ~= nil) and tostring(override.sound) or '__global__';
    if (selected == '__global__' or selected == '__default__' or selected == '') then
        return definition.sound or warn.settings.sound.selected;
    end
    return selected;
end

local function get_available_debuff_counter(definition)
    if (definition == nil or definition.counters == nil) then return nil; end
    for _, counter in ipairs(definition.counters) do
        if (counter_is_assigned(counter) and counter.type == 'spell') then
            local ok = can_use_spell_now(counter.name);
            if (ok) then return counter; end
        elseif (counter_is_assigned(counter) and counter.type == 'blu_spell') then
            local ok = can_use_blu_spell_now(counter.name);
            if (ok) then return counter; end
        end
    end
    return nil;
end

local function clear_debuff_status(definition, announce)
    if (definition == nil) then return; end
    warn.debuffs.tracked[definition.id] = nil;
    for key, pending in pairs(warn.debuffs.deferred_losses or {}) do
        if pending.status_id == definition.id then warn.debuffs.deferred_losses[key] = nil; end
    end
    for key, pending in pairs(warn.debuffs.pending_prewarns or {}) do
        if pending.status_id == definition.id then warn.debuffs.pending_prewarns[key] = nil; end
    end
    if (announce) then
        print(chat.header(addon.name):append(chat.message(definition.name .. ' tracker cleared.')));
    end
end

local function clear_debuff_tracker(announce)
    warn.debuffs.tracked = {};
    warn.debuffs.pending_losses = {};
    warn.debuffs.pending_prewarns = {};
    warn.debuffs.deferred_losses = {};
    warn.debuffs.batch_deadline = 0;
    warn.debuffs.prewarn_deadline = 0;
    if (announce) then
        print(chat.header(addon.name):append(chat.message('Global debuff tracker cleared.')));
    end
end

local function update_debuff_mob_cache(force)
    ensure_debuff_settings();
    ensure_learning_settings();
    if (not warn.settings.debuffs.enabled and not warn.settings.learning.enabled) then return; end

    local now = os.clock();
    if (not force and now < (warn.debuffs.next_scan or 0)) then return; end
    warn.debuffs.next_scan = now + (warn.debuffs.scan_interval or 0.75);

    local names = {};
    local counts = {};
    local entityManager = AshitaCore:GetMemoryManager():GetEntity();
    if (entityManager ~= nil) then
        local mapSize = entityManager:GetEntityMapSize();
        for i = 0, mapSize - 1 do
            local entity = entityManager:GetRawEntity(i);
            if (entity ~= nil and entity.Name ~= nil and entity.Name ~= '' and
                entity.SpawnFlags ~= nil and bit.band(entity.SpawnFlags, 0x10) ~= 0) then
                local name = tostring(entity.Name);
                local key = name:lower();
                names[key] = name;
                counts[key] = (counts[key] or 0) + 1;
            end
        end
    end

    warn.debuffs.mob_names = names;
    warn.debuffs.mob_counts = counts;

    -- Death/despawn is not a debuff-loss event.  Remove entries silently once every
    -- hostile entity with that name has been absent for several scans.
    if (warn.settings.debuffs.enabled) then
        for statusId, statusTable in pairs(warn.debuffs.tracked or {}) do
            for key, entry in pairs(statusTable) do
                if (counts[key] ~= nil and counts[key] > 0) then
                    entry.last_present = now;
                elseif ((now - (entry.last_present or now)) >= 3.0) then
                    statusTable[key] = nil;
                    warn.debuffs.deferred_losses[statusId .. '|' .. key] = nil;
                    warn.debuffs.pending_prewarns[statusId .. '|' .. key] = nil;
                end
            end
        end
    end

end

local function entity_health_percent(entity, index)
    if (index ~= nil) then
        local manager = AshitaCore:GetMemoryManager():GetEntity();
        if (manager ~= nil and type(manager.GetHPPercent) == 'function') then
            local ok, value = pcall(function () return manager:GetHPPercent(index); end);
            value = ok and tonumber(value) or nil;
            if (value ~= nil and value >= 0 and value <= 100) then return value; end
        end
    end
    if (entity == nil) then return nil; end
    local fields = { 'HealthPercent', 'HPP', 'HPPercent' };
    for _, field in ipairs(fields) do
        local ok, value = pcall(function () return entity[field]; end);
        value = ok and tonumber(value) or nil;
        if (value ~= nil and value >= 0 and value <= 100) then return value; end
    end
    return nil;
end

local function get_current_zone_id()
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then return nil; end
    local ok, value = pcall(function () return party:GetMemberZone(0); end);
    return ok and tonumber(value) or nil;
end

local function rule_matches_current_zone(rule)
    if (type(rule) ~= 'table' or type(rule.zone_ids) ~= 'table' or #rule.zone_ids == 0) then return true; end
    local zone = get_current_zone_id();
    if (zone == nil) then return false; end
    for _, id in ipairs(rule.zone_ids) do if (tonumber(id) == zone) then return true; end end
    return false;
end

local function get_friendly_name_lookup()
    local names = {};

    local playerEntity = GetPlayerEntity();
    if (playerEntity ~= nil and playerEntity.Name ~= nil and playerEntity.Name ~= '') then
        names[tostring(playerEntity.Name):lower()] = true;
    end

    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party ~= nil) then
        for i = 0, 17 do
            local name = party:GetMemberName(i);
            if (name ~= nil and name ~= '') then
                names[tostring(name):lower()] = true;
            end
        end
    end

    return names;
end

local function clean_log_subject(text)
    if (text == nil) then return ''; end
    local subject = tostring(text);

    -- text_in strings can contain FFXI formatting/control bytes around names.  Removing
    -- control characters keeps the visible actor text without depending on an unverified
    -- Ashita string-cleaning helper.
    subject = subject:gsub('%c', '');
    subject = subject:gsub('^%s+', ''):gsub('%s+$', '');
    subject = subject:gsub('^[%p%s]+', function (prefix)
        -- Keep apostrophes/hyphens that may be part of a real name; only discard obvious
        -- formatting punctuation before the visible actor.
        if prefix:find("'", 1, true) or prefix:find('-', 1, true) then return prefix; end
        return '';
    end);
    return subject;
end

local function find_debuff_subject(rawMessage, rawLower, fragmentStart)
    -- Prefer a canonical hostile entity name when one is available.  This remains useful
    -- for same-name mob counting, but it is no longer a hard requirement for recognizing
    -- a legitimate status transition from the combat log.
    local best = nil;
    local bestLen = 0;
    for key, canonical in pairs(warn.debuffs.mob_names or {}) do
        local pos = rawLower:find(key, 1, true);
        if (pos ~= nil and pos < fragmentStart and #key > bestLen) then
            best = canonical;
            bestLen = #key;
        end
    end
    if (best ~= nil) then return best; end

    -- Fallback: status messages are actor-first ("Mob wakes up", "Mob is petrified",
    -- "Mob's Sleep effect wears off").  Use the visible prefix directly.  This fixes
    -- legitimate loss events being discarded when the entity scan has not yet populated
    -- or when the text line contains formatting bytes that prevented a cache match.
    local prefix = tostring(rawMessage):sub(1, math.max(0, fragmentStart - 1));
    local subject = clean_log_subject(prefix);
    if (subject == '') then return nil; end

    -- Do not track the player or party/trust members as hostile debuff targets.
    local friendly = get_friendly_name_lookup();
    if (friendly[subject:lower()]) then return nil; end

    -- Reject obviously malformed prefixes instead of letting a whole chat sentence become
    -- a fake mob name.  Real FFXI entity names are comfortably below this limit.
    if (#subject > 64 or subject:find('\n', 1, true) ~= nil) then return nil; end
    return subject;
end

local function find_status_fragment(rawLower, definition, isLoss)
    local fragments = isLoss and definition.loss_fragments or definition.gain_fragments;
    if (fragments ~= nil) then
        for _, fragment in ipairs(fragments) do
            local wanted = tostring(fragment or ''):lower();
            if (wanted ~= '') then
                local pos = rawLower:find(wanted, 1, true);
                if (pos ~= nil) then return pos; end
            end
        end
    end

    -- Common FFXI status forms.  Definitions only need to provide effect_names to
    -- benefit from these variants.
    for _, effect in ipairs(definition.effect_names or {}) do
        local lowerEffect = tostring(effect):lower();
        local variants;
        if (isLoss) then
            variants = {
                "'s " .. lowerEffect .. ' effect wears off',
                ' is no longer affected by ' .. lowerEffect,
                ' loses the effect of ' .. lowerEffect,
            };
        else
            variants = {
                ' receives the effect of ' .. lowerEffect,
                ' is afflicted with ' .. lowerEffect,
                ' gains the effect of ' .. lowerEffect,
            };
        end
        for _, wanted in ipairs(variants) do
            local pos = rawLower:find(wanted, 1, true);
            if (pos ~= nil) then return pos; end
        end
    end

    return nil;
end


local function get_debuff_estimated_duration(definition)
    if (definition == nil) then return nil; end
    local override = get_debuff_override(definition, false);
    if (override ~= nil and override.duration ~= nil) then
        local value = tonumber(override.duration);
        if (value ~= nil and value > 0) then return value; end
    end
    local value = tonumber(definition.duration or definition.default_duration or definition.estimate_duration);
    if (value ~= nil and value > 0) then return value; end
    return nil;
end

local function set_debuff_estimated_duration(definition, duration)
    if (definition == nil) then return; end
    local override = get_debuff_override(definition, true);
    local value = tonumber(duration);
    if (value == nil or value <= 0) then
        override.duration = nil;
    else
        override.duration = math.floor(value + 0.5);
    end
    save_settings();
end

local function debuff_prewarn_enabled(definition)
    if (definition == nil) then return false; end
    local override = get_debuff_override(definition, false);
    if (override ~= nil and override.prewarn ~= nil) then return override.prewarn == true; end
    if (definition.prewarn ~= nil) then return definition.prewarn == true; end
    return definition.category == 'Crowd Control' or definition.center_alert == true;
end

local function format_seconds(seconds)
    seconds = tonumber(seconds) or 0;
    if (seconds < 0) then seconds = 0; end
    seconds = math.floor(seconds + 0.5);
    if (seconds >= 60) then
        local mins = math.floor(seconds / 60);
        local secs = seconds % 60;
        return string.format('%d:%02d', mins, secs);
    end
    return tostring(seconds) .. 's';
end

local function get_debuff_time_text(entry, now)
    if (entry == nil or entry.expires_at == nil) then return 'observed'; end
    now = now or os.clock();
    local remaining = tonumber(entry.expires_at) - now;
    if (remaining > 0) then
        return '~' .. format_seconds(remaining);
    end
    return '? +' .. format_seconds(-remaining);
end

local function debuff_instruction_is_assigned(definition)
    if (definition == nil or definition.counters == nil or #definition.counters == 0) then return true; end
    for _, counter in ipairs(definition.counters) do
        if (counter_is_assigned(counter)) then return true; end
    end
    return false;
end

local MAX_PENDING_DEBUFF_EVENTS = 64;

local function queue_debuff_prewarn(definition, entry)
    if (definition == nil or entry == nil) then return; end
    local name = tostring(entry.name or 'Unknown');
    for _, pending in ipairs(warn.debuffs.pending_prewarns) do
        if (pending.status_id == definition.id and tostring(pending.name):lower() == name:lower()) then return; end
    end
    if (#warn.debuffs.pending_prewarns >= MAX_PENDING_DEBUFF_EVENTS) then return; end
    table.insert(warn.debuffs.pending_prewarns, {
        status_id = definition.id,
        definition = definition,
        name = name,
        remaining = math.max(0, math.floor(((entry.expires_at or os.clock()) - os.clock()) + 0.5)),
        assigned = debuff_instruction_is_assigned(definition),
    });
    warn.debuffs.prewarn_deadline = os.clock() + math.max(0.0, tonumber(warn.settings.debuffs.batch_window) or 0.20);
end

local function get_debuff_status_table(definition, create)
    if (definition == nil) then return nil; end
    local t = warn.debuffs.tracked[definition.id];
    if (t == nil and create) then
        t = {};
        warn.debuffs.tracked[definition.id] = t;
    end
    return t;
end

local function debuff_mark_gained(definition, name)
    if (definition == nil or name == nil or name == '') then return; end
    local now = os.clock();
    local key = tostring(name):lower();
    local statusTable = get_debuff_status_table(definition, true);
    local entry = statusTable[key];

    if (entry == nil) then
        entry = {
            name = tostring(name),
            count = 0,
            first_applied = now,
            last_applied = now,
            last_present = now,
            estimated_duration = nil,
            expires_at = nil,
            uncertain = false,
            prewarned = false,
        };
        statusTable[key] = entry;
    end

    -- Same-name mobs cannot be uniquely identified from the status text line.  The
    -- loaded entity count is a safe upper bound while still allowing AoE CC groups.
    local ceiling = tonumber(warn.debuffs.mob_counts[key]) or 1;
    if (entry.count < ceiling) then entry.count = entry.count + 1; end
    entry.last_applied = now;
    entry.last_present = now;
    entry.uncertain = false;
    entry.prewarned = false;
    local estimated = get_debuff_estimated_duration(definition);
    entry.estimated_duration = estimated;
    entry.expires_at = (estimated ~= nil) and (now + estimated) or nil;

    -- Someone reapplied the effect before our character became able to respond.
    warn.debuffs.deferred_losses[definition.id .. '|' .. key] = nil;

    -- Maintenance effects can be reapplied by another player during the short batching
    -- window.  Cancel a stale pending maintenance alert in that case.  Crowd-control
    -- wake/recovery events remain informative and are not canceled.
    if (definition.alert_policy == 'smart' and #warn.debuffs.pending_losses > 0) then
        local kept = {};
        for _, pending in ipairs(warn.debuffs.pending_losses) do
            if (pending.status_id ~= definition.id or tostring(pending.name):lower() ~= key) then
                table.insert(kept, pending);
            end
        end
        warn.debuffs.pending_losses = kept;
    end

    if (warn.debug) then
        print(chat.header(addon.name):append(chat.message(string.format(
            'Debuff gained: %s - %s (count %d)', tostring(name), definition.name, entry.count))));
    end
end

local function queue_debuff_loss(definition, name, counter)
    name = tostring(name);
    for _, pending in ipairs(warn.debuffs.pending_losses) do
        if (pending.status_id == definition.id and tostring(pending.name):lower() == name:lower()) then return; end
    end
    if (#warn.debuffs.pending_losses >= MAX_PENDING_DEBUFF_EVENTS) then return; end
    table.insert(warn.debuffs.pending_losses, {
        status_id = definition.id,
        definition = definition,
        name = name,
        counter = counter,
        assigned = debuff_instruction_is_assigned(definition),
    });
    local window = tonumber(warn.settings.debuffs.batch_window) or 0.20;
    warn.debuffs.batch_deadline = os.clock() + math.max(0.0, window);
end

local function defer_debuff_loss(definition, name)
    local key = definition.id .. '|' .. tostring(name):lower();
    warn.debuffs.deferred_losses[key] = {
        status_id = definition.id,
        name = tostring(name),
        lost_at = os.clock(),
    };
end

local function debuff_mark_lost(definition, name, forceAlert, allowUntracked)
    if (definition == nil or name == nil or name == '') then return false; end
    local key = tostring(name):lower();
    local statusTable = get_debuff_status_table(definition, false);
    local entry = statusTable ~= nil and statusTable[key] or nil;
    warn.debuffs.pending_prewarns[definition.id .. '|' .. key] = nil;

    -- Text-derived loss messages normally require a previously observed gain.  A parsed
    -- 0x029 battle-message packet is stronger evidence: FFXI sends the origin player the
    -- status-loss packet directly, so packet processing may allow an otherwise-untracked loss.
    if (not forceAlert and not allowUntracked and (entry == nil or (entry.count or 0) <= 0)) then return false; end

    if (entry ~= nil) then
        entry.count = math.max(0, (entry.count or 1) - 1);
        if (entry.count <= 0) then statusTable[key] = nil; end
    end

    local counter = get_available_debuff_counter(definition);
    if (not forceAlert and debuff_only_if_capable(definition) and counter == nil) then
        defer_debuff_loss(definition, name);
        if (warn.debug) then
            print(chat.header(addon.name):append(chat.message(
                'Debuff lost but alert deferred (no usable counter): ' .. tostring(name) .. ' - ' .. definition.name)));
        end
        return true;
    end

    queue_debuff_loss(definition, name, counter);

    if (warn.debug) then
        print(chat.header(addon.name):append(chat.message(
            'Debuff lost: ' .. tostring(name) .. ' - ' .. definition.name)));
    end
    return true;
end

-- Resolve an FFXI status icon / buff resource name to one of Warn's debuff definitions.
-- Packet 0x029 places the worn-off status icon id in Param1.  Most enfeebles use their
-- status id as the icon id; the resource lookup keeps the core data-driven where possible.
local PACKET_DEBUFF_ID_FALLBACK = {
    [2]  = 'sleep',      -- Sleep I / common sleep icon (Sleep II/Lullaby may display this icon)
    [3]  = 'poison',
    [4]  = 'paralyze',
    [5]  = 'blind',
    [6]  = 'silence',
    [7]  = 'petrify',
    [11] = 'bind',
    [12] = 'gravity',    -- FFXI status name is Weight; player spell is Gravity
    [13] = 'slow',
    [18] = 'petrify',    -- Gradual Petrification
    [19] = 'sleep',      -- Sleep II if the raw icon is preserved
    [21] = 'addle',
};

local function find_packet_debuff_definition(effectIcon)
    effectIcon = tonumber(effectIcon);
    if (effectIcon == nil) then return nil, nil; end

    local resMgr = AshitaCore:GetResourceManager();
    local resourceName = nil;
    if (resMgr ~= nil) then
        local ok, value = pcall(function ()
            return resMgr:GetString('buffs.names', effectIcon);
        end);
        if (ok and value ~= nil and tostring(value) ~= '') then
            resourceName = tostring(value);
        end
    end

    if (resourceName ~= nil) then
        local lower = resourceName:lower();
        for _, definition in ipairs(warn.debuffs.definitions or {}) do
            if (tostring(definition.name or ''):lower() == lower) then
                return definition, resourceName;
            end
            for _, effectName in ipairs(definition.effect_names or {}) do
                if (tostring(effectName):lower() == lower) then
                    return definition, resourceName;
                end
            end
        end
    end

    local fallbackId = PACKET_DEBUFF_ID_FALLBACK[effectIcon];
    if (fallbackId ~= nil) then
        return get_debuff_definition(fallbackId), resourceName;
    end

    return nil, resourceName;
end

local function get_any_packet_target_name(targetIndex, targetServerId)
    local entityManager = AshitaCore:GetMemoryManager():GetEntity();
    if (entityManager == nil) then return nil; end

    local index = tonumber(targetIndex) or 0;
    local entity = entityManager:GetRawEntity(index);
    if (entity ~= nil and entity.Name ~= nil and tostring(entity.Name) ~= '') then
        return tostring(entity.Name);
    end

    local wantedId = tonumber(targetServerId) or 0;
    if (wantedId ~= 0) then
        local mapSize = entityManager:GetEntityMapSize();
        for i = 0, mapSize - 1 do
            if (tonumber(entityManager:GetServerId(i)) == wantedId) then
                local candidate = entityManager:GetRawEntity(i);
                if (candidate ~= nil and candidate.Name ~= nil and tostring(candidate.Name) ~= '') then
                    return tostring(candidate.Name);
                end
            end
        end
    end
    return nil;
end

local function get_packet_target_name(targetIndex, targetServerId)
    local entityManager = AshitaCore:GetMemoryManager():GetEntity();
    if (entityManager == nil) then return nil; end

    -- The packet provides the exact target index, so prefer it over all name heuristics.
    local entity = entityManager:GetRawEntity(tonumber(targetIndex) or 0);
    if (entity ~= nil and entity.Name ~= nil and entity.Name ~= '' and
        entity.SpawnFlags ~= nil and bit.band(entity.SpawnFlags, 0x10) ~= 0) then
        return tostring(entity.Name);
    end

    -- Rare fallback if the index could not be resolved: locate the hostile entity by server id.
    local wantedId = tonumber(targetServerId) or 0;
    if (wantedId ~= 0) then
        local mapSize = entityManager:GetEntityMapSize();
        for i = 0, mapSize - 1 do
            local candidate = entityManager:GetRawEntity(i);
            if (candidate ~= nil and candidate.Name ~= nil and candidate.Name ~= '' and
                candidate.SpawnFlags ~= nil and bit.band(candidate.SpawnFlags, 0x10) ~= 0 and
                candidate.ServerId ~= nil and tonumber(candidate.ServerId) == wantedId) then
                return tostring(candidate.Name);
            end
        end
    end

    return nil;
end

-- Packet: 0x029 - battle/action message.
-- Layout is the retail FFXI battle-message packet:
--   0x08 target server id, 0x0C Param1/status icon, 0x16 target index,
--   0x18 message id. Message 204 = "<target> is no longer <effect>" and
--   206 = "<target>'s <effect> wears off."
local function process_debuff_loss_packet(e)
    ensure_debuff_settings();
    if (not warn.settings.debuffs.enabled or e == nil or e.id ~= 0x0029) then return; end
    if (#warn.debuffs.definitions == 0) then return; end

    local data = e.data_modified or e.data_raw;
    if (data == nil) then return; end

    local ok, targetServerId, effectIcon, targetIndex, messageId = pcall(function ()
        return struct.unpack('I', data, 0x08 + 0x01),
               struct.unpack('I', data, 0x0C + 0x01),
               struct.unpack('H', data, 0x16 + 0x01),
               struct.unpack('H', data, 0x18 + 0x01);
    end);
    if (not ok) then
        if (warn.debug) then
            print(chat.header(addon.name):append(chat.error('Failed to parse 0x029 debuff-loss packet.')));
        end
        return;
    end

    -- Standard status-loss messages. Sleep, Petrification, Bind, Silence, etc. generally
    -- use 204; status definitions without a custom wear-off line use 206.
    if (messageId ~= 204 and messageId ~= 206) then return; end

    local definition, resourceName = find_packet_debuff_definition(effectIcon);
    if (definition == nil or not is_debuff_enabled(definition)) then
        if (warn.debug and definition == nil) then
            print(chat.header(addon.name):append(chat.message(string.format(
                '0x029 unhandled status loss: icon=%d effect=%s msg=%d targetIndex=%d',
                tonumber(effectIcon) or -1, tostring(resourceName or '?'), tonumber(messageId) or -1,
                tonumber(targetIndex) or -1))));
        end
        return;
    end

    local name = get_packet_target_name(targetIndex, targetServerId);
    if (name == nil or name == '') then
        if (warn.debug) then
            print(chat.header(addon.name):append(chat.message(string.format(
                '0x029 %s loss recognized but hostile target name was unavailable (targetIndex=%d).',
                tostring(definition.name), tonumber(targetIndex) or -1))));
        end
        return;
    end

    warn.debuffs.packet_losses = (tonumber(warn.debuffs.packet_losses) or 0) + 1;
    warn.debuffs.last_packet_loss = string.format('%s - %s', name, tostring(definition.name));

    if (warn.debug) then
        print(chat.header(addon.name):append(chat.warning(string.format(
            '0x029 DEBUFF LOSS: %s - %s (icon=%d, msg=%d)', name, tostring(definition.name),
            tonumber(effectIcon) or -1, tonumber(messageId) or -1))));
    end

    -- Packet evidence is authoritative enough to alert even if the gain text was filtered
    -- or used an unknown wording. Smart-maintenance statuses still honor capability checks.
    debuff_mark_lost(definition, name, false, true);
end

local function process_encounter_status_packet(e)
    if (e == nil or e.id ~= 0x0029 or warn.statusPacket == nil or
        warn.encounter == nil or warn.encounter.shinryu == nil or
        not warn.encounter.shinryu.doom.active) then return; end

    local data = e.data_modified or e.data_raw;
    local parsed = warn.statusPacket.parse(data, function (format, packet, offset)
        return struct.unpack(format, packet, offset);
    end);
    if (parsed == nil) then return; end

    -- Buff id 15 is Doom. Restrict interpretation to the short Supernova triage
    -- window so unrelated 0x029 message parameters cannot become false positives.
    local effectName = nil;
    local resources = AshitaCore:GetResourceManager();
    if (resources ~= nil) then
        local ok, value = pcall(function () return resources:GetString('buffs.names', parsed.param1); end);
        if (ok and value ~= nil and tostring(value) ~= '') then effectName = tostring(value); end
    end
    local isDoom = tonumber(parsed.param1) == 15 or tostring(effectName or ''):lower() == 'doom';
    if (not isDoom) then return; end

    local name = get_any_packet_target_name(parsed.target_index, parsed.target_id);
    if (name == nil or name == '') then name = 'Unknown party member'; end
    local active = parsed.message_id ~= 204 and parsed.message_id ~= 206;
    if (encounterRuntime.observe_shinryu_doom(warn.encounter, parsed.target_id, name, active, os.clock())) then
        warn.reactive.last_status_observation = string.format('%s - Doom %s', name, active and 'gained' or 'cleared');
        if (warn.debug) then
            print(chat.header(addon.name):append(chat.warning(string.format(
                'SHINRYU DOOM %s: %s (icon=%d, msg=%d)', active and 'GAIN' or 'CLEAR', name,
                tonumber(parsed.param1) or -1, tonumber(parsed.message_id) or -1))));
        end
    end
end

local function process_global_debuff_message(rawMessage)
    ensure_debuff_settings();
    if (not warn.settings.debuffs.enabled or rawMessage == nil or rawMessage == '') then return; end
    if (#warn.debuffs.definitions == 0) then return; end

    update_debuff_mob_cache(false);

    local rawLower = tostring(rawMessage):lower();

    -- Loss first: "is no longer paralyzed" contains "paralyzed".
    for _, definition in ipairs(warn.debuffs.definitions) do
        if (is_debuff_enabled(definition)) then
            local pos = find_status_fragment(rawLower, definition, true);
            if (pos ~= nil) then
                local name = find_debuff_subject(rawMessage, rawLower, pos);
                if (name ~= nil) then debuff_mark_lost(definition, name, false); end
                return;
            end
        end
    end

    for _, definition in ipairs(warn.debuffs.definitions) do
        if (is_debuff_enabled(definition)) then
            local pos = find_status_fragment(rawLower, definition, false);
            if (pos ~= nil) then
                if (definition.id == 'sleep' and rawLower:find('already asleep', 1, true) ~= nil) then
                    return;
                end
                local name = find_debuff_subject(rawMessage, rawLower, pos);
                if (name ~= nil) then debuff_mark_gained(definition, name); end
                return;
            end
        end
    end

    -- Debugging status wording is intentionally easy: if retail uses a variant that is
    -- not yet in data/debuffs.lua, surface the raw candidate line so the database can be
    -- corrected instead of guessing at additional phrases.
    if (warn.debug and (
        rawLower:find(' effect wears off', 1, true) ~= nil or
        rawLower:find(' is no longer ', 1, true) ~= nil or
        rawLower:find(' receives the effect of ', 1, true) ~= nil or
        rawLower:find(' is afflicted with ', 1, true) ~= nil or
        rawLower:find(' wakes up', 1, true) ~= nil or
        rawLower:find(' falls asleep', 1, true) ~= nil
    )) then
        print(chat.header(addon.name):append(chat.message('Debuff Unmatched: ' .. tostring(rawMessage))));
    end
end


local function flush_debuff_prewarn_batch()
    ensure_debuff_settings();
    if (#warn.debuffs.pending_prewarns == 0) then return; end
    if (os.clock() < (warn.debuffs.prewarn_deadline or 0)) then return; end

    local events = warn.debuffs.pending_prewarns;
    warn.debuffs.pending_prewarns = {};
    warn.debuffs.prewarn_deadline = 0;

    local lines = {};
    if (#events == 1) then
        local event = events[1];
        table.insert(lines, tostring(event.name):upper() .. ': ' .. tostring(event.definition.name):upper() .. ' EXPIRING SOON');
        table.insert(lines, '~' .. format_seconds(event.remaining or 0) .. ' ESTIMATED');
        if (event.assigned and event.definition.action ~= nil) then table.insert(lines, tostring(event.definition.action)); end
    else
        table.insert(lines, string.format('%d CROWD-CONTROL EFFECTS EXPIRING SOON', #events));
        for i = 1, math.min(#events, 4) do
            local event = events[i];
            table.insert(lines, string.format('%s: %s ~%s', tostring(event.name), tostring(event.definition.name), format_seconds(event.remaining or 0)));
        end
        if (#events > 4) then table.insert(lines, '...'); end
    end

    submit_warning_payload({
        name='Debuff Timer', text=table.concat(lines, '\n'),
        rule_id='__global_debuff_prewarn__', dedupe_key='__global_debuff_prewarn__',
        sound=resolve_debuff_sound(events[1].definition), sound_policy='debuff',
        duration=tonumber(warn.settings.debuffs.alert_duration) or warn.settings.overlay.duration,
        severity='danger', prediction='readiness',
    });
end

local function process_debuff_estimates()
    ensure_debuff_settings();
    if (not warn.settings.debuffs.enabled) then return; end

    local now = os.clock();
    local prewarnSeconds = math.max(0, tonumber(warn.settings.debuffs.prewarn_seconds) or 5.0);

    for _, definition in ipairs(warn.debuffs.definitions or {}) do
        local statusTable = warn.debuffs.tracked[definition.id] or {};
        for _, entry in pairs(statusTable) do
            if ((entry.count or 0) > 0 and entry.expires_at ~= nil) then
                local remaining = tonumber(entry.expires_at) - now;
                if (remaining <= 0) then
                    entry.uncertain = true;
                elseif (warn.settings.debuffs.prewarn_enabled == true and
                        debuff_prewarn_enabled(definition) and
                        entry.prewarned ~= true and
                        remaining <= prewarnSeconds) then
                    entry.prewarned = true;
                    queue_debuff_prewarn(definition, entry);
                end
            end
        end
    end

    flush_debuff_prewarn_batch();
end

local function process_deferred_debuff_losses()
    if (not warn.settings.debuffs.enabled) then return; end
    local now = os.clock();
    if (now < (warn.debuffs.next_deferred_check or 0)) then return; end
    warn.debuffs.next_deferred_check = now + 0.25;

    for key, pending in pairs(warn.debuffs.deferred_losses or {}) do
        local definition = get_debuff_definition(pending.status_id);
        if (definition == nil or not is_debuff_enabled(definition)) then
            warn.debuffs.deferred_losses[key] = nil;
        else
            local mobKey = tostring(pending.name):lower();
            local statusTable = get_debuff_status_table(definition, false);

            -- Effect was reapplied, mob disappeared, or this stale loss is no longer useful.
            if (statusTable ~= nil and statusTable[mobKey] ~= nil and (statusTable[mobKey].count or 0) > 0) then
                warn.debuffs.deferred_losses[key] = nil;
            elseif (warn.debuffs.mob_counts[mobKey] == nil or (now - (pending.lost_at or now)) > 60.0) then
                warn.debuffs.deferred_losses[key] = nil;
            else
                local counter = get_available_debuff_counter(definition);
                if (counter ~= nil) then
                    queue_debuff_loss(definition, pending.name, counter);
                    warn.debuffs.deferred_losses[key] = nil;
                end
            end
        end
    end
end

local function build_single_debuff_loss_text(event)
    local definition = event.definition;
    local name = tostring(event.name):upper();

    if definition.id == 'sleep' then
        local action = (event.counter ~= nil)
            and tostring(event.counter.label or event.counter.name:upper())
            or (event.assigned and tostring(definition.action or 'RE-SLEEP / CONTROL IT!') or nil);
        return action ~= nil and (name .. ' WOKE UP!\n' .. action) or (name .. ' WOKE UP!');
    end

    local text = name .. ': ' .. tostring(definition.loss_label or (definition.name:upper() .. ' WORE OFF!'));
    if (event.counter ~= nil) then
        text = text .. '\n' .. tostring(event.counter.label or event.counter.name:upper());
    elseif (event.assigned and definition.action ~= nil) then
        text = text .. '\n' .. tostring(definition.action);
    end
    return text;
end

local function find_available_sound(preferred)
    local wanted = tostring(preferred or ''):lower();
    for i = 1, #warn.soundFiles do
        if (tostring(warn.soundFiles[i]):lower() == wanted) then return warn.soundFiles[i]; end
    end
    return nil;
end

local function resolve_critical_debuff_sound(definition)
    local sound = resolve_debuff_sound(definition);
    if (sound ~= nil and sound ~= '' and sound ~= 'None') then return sound; end

    -- Critical crowd-control losses should make noise out of the box even when the manual
    -- ability-warning sound is still set to None.  An explicit per-status "None" override
    -- is still respected.
    local override = get_debuff_override(definition, false);
    if (override ~= nil and tostring(override.sound or '') == 'None') then return 'None'; end

    return find_available_sound('alarm.wav') or
           find_available_sound('warning.wav') or
           find_available_sound('alert.wav') or
           find_available_sound('beep.wav') or 'None';
end

local function start_critical_debuff_alert(text, definition)
    submit_warning_payload({
        name=tostring((definition and definition.name) or 'CROWD CONTROL'),
        text=tostring(text or 'CROWD CONTROL LOST!'),
        rule_id='__critical_debuff__',
        dedupe_key='__critical_debuff__|' .. tostring((definition and definition.id) or 'unknown'),
        sound=resolve_critical_debuff_sound(definition), sound_policy='debuff',
        duration=tonumber(warn.settings.debuffs.alert_duration) or 4.0,
        severity='critical', prediction='reactive',
    });
end

local function render_critical_debuff_alert()
    if (warn.critical.firing and
        (os.clock() - warn.critical.startTime) >= (tonumber(warn.critical.duration) or 4.0)) then
        warn.critical.firing = false;
    end
    -- The Vana'diel Tactical ImGui layer renders this state with the same severity
    -- language as encounter alerts. Keep the legacy font hidden for safe migration.
    if (warn.criticalFont ~= nil) then warn.criticalFont:SetVisible(false); end
end

local function flush_debuff_loss_batch()
    ensure_debuff_settings();
    if (#warn.debuffs.pending_losses == 0) then return; end
    if (os.clock() < (warn.debuffs.batch_deadline or 0)) then return; end

    local events = warn.debuffs.pending_losses;
    warn.debuffs.pending_losses = {};
    warn.debuffs.batch_deadline = 0;

    local firstDef = events[1].definition;
    local sameStatus = true;
    for i = 2, #events do
        if events[i].status_id ~= events[1].status_id then
            sameStatus = false;
            break
        end
    end

    local text;
    local sound;
    if (#events == 1) then
        text = build_single_debuff_loss_text(events[1]);
        sound = resolve_debuff_sound(firstDef);
    elseif (sameStatus) then
        local grouped, order = {}, {};
        for _, event in ipairs(events) do
            local key = tostring(event.name):lower();
            if (grouped[key] == nil) then
                grouped[key] = { name = tostring(event.name), count = 0 };
                table.insert(order, key);
            end
            grouped[key].count = grouped[key].count + 1;
        end

        local parts = {};
        for i = 1, math.min(#order, 3) do
            local entry = grouped[order[i]];
            table.insert(parts, entry.count > 1 and (entry.count .. 'x ' .. entry.name) or entry.name);
        end
        if (#order > 3) then table.insert(parts, '...'); end

        local headline = firstDef.multi_loss_label or
            string.format('%d MONSTERS LOST %s!', #events, tostring(firstDef.name):upper());
        text = headline .. '\n' .. table.concat(parts, ', ');
        if (events[1].assigned) then
            text = text .. '\n' .. tostring(firstDef.multi_action or firstDef.action or 'RE-CONTROL / REAPPLY!');
        end
        sound = resolve_debuff_sound(firstDef);
    else
        local lines = { string.format('%d DEBUFFS LOST!', #events) };
        for i = 1, math.min(#events, 4) do
            local event = events[i];
            table.insert(lines, tostring(event.name) .. ': ' .. tostring(event.definition.name));
        end
        if (#events > 4) then table.insert(lines, '...'); end
        local anyAssigned = false;
        for _, event in ipairs(events) do
            if (event.assigned) then
                anyAssigned = true;
                break
            end
        end
        if (anyAssigned) then table.insert(lines, 'CHECK CONTROL / REAPPLY!'); end
        text = table.concat(lines, '\n');
        sound = warn.settings.sound.selected;
    end

    local useCriticalCenter = sameStatus and firstDef.center_alert == true and
        warn.settings.debuffs.critical_center == true;

    if (useCriticalCenter) then
        start_critical_debuff_alert(text, firstDef);
    else
        submit_warning_payload({
            name=sameStatus and tostring(firstDef.name) or 'Debuffs', text=text,
            rule_id='__global_debuff_loss__', dedupe_key='__global_debuff_loss__|' .. tostring(firstDef.id or 'mixed'),
            sound=sound, sound_policy='debuff',
            duration=tonumber(warn.settings.debuffs.alert_duration) or warn.settings.overlay.duration,
            severity='danger', prediction='reactive',
        });
    end
end

local function get_debuff_tracked_count(statusId)
    local total = 0;
    if (statusId ~= nil) then
        local statusTable = warn.debuffs.tracked[tostring(statusId):lower()] or {};
        for _, entry in pairs(statusTable) do total = total + math.max(0, tonumber(entry.count) or 0); end
        return total;
    end

    for _, statusTable in pairs(warn.debuffs.tracked or {}) do
        for _, entry in pairs(statusTable) do total = total + math.max(0, tonumber(entry.count) or 0); end
    end
    return total;
end

local function print_debuff_tracker(statusId)
    local filter = statusId ~= nil and get_debuff_definition(statusId) or nil;
    local total = filter ~= nil and get_debuff_tracked_count(filter.id) or get_debuff_tracked_count(nil);
    if (total == 0) then
        local label = filter ~= nil and ('No hostile monsters are currently tracked with ' .. filter.name .. '.')
            or 'No hostile monster debuffs are currently tracked.';
        print(chat.header(addon.name):append(chat.message(label)));
        return;
    end

    local heading = filter ~= nil and
        string.format('Tracked %s targets: %d', filter.name, total) or
        string.format('Tracked hostile debuffs: %d', total);
    print(chat.header(addon.name):append(chat.message(heading)));

    for _, definition in ipairs(warn.debuffs.definitions) do
        if (filter == nil or definition.id == filter.id) then
            local statusTable = warn.debuffs.tracked[definition.id] or {};
            for _, entry in pairs(statusTable) do
                if ((entry.count or 0) > 0) then
                    print(chat.header(addon.name):append(chat.warning(
                        string.format('  - %s: %s x%d [%s]', entry.name, definition.name, entry.count,
                            get_debuff_time_text(entry, os.clock())))));
                end
            end
        end
    end
end

local function apply_debuff_preset(name)
    local preset = tostring(name or 'recommended'):lower();
    for _, definition in ipairs(warn.debuffs.definitions) do
        local enable;
        if (preset == 'recommended' or preset == 'default') then
            enable = definition.recommended == true;
        elseif (preset == 'cc' or preset == 'crowd' or preset == 'crowd-control') then
            enable = tostring(definition.category or '') == 'Crowd Control';
        elseif (preset == 'all') then
            enable = true;
        elseif (preset == 'off' or preset == 'none') then
            enable = false;
        else
            return false;
        end
        local override = get_debuff_override(definition, true);
        override.enabled = enable;
        if (not enable) then warn.debuffs.tracked[definition.id] = nil; end
    end
    save_settings();
    return true;
end

--------------------------------------------------------------------------------------------------
-- Automatic encounter timer learning
--------------------------------------------------------------------------------------------------

local function mark_learning_dirty(immediate)
    warn.timerLearning.dirty = true;
    local delay = immediate and 0 or 5;
    local deadline = os.clock() + delay;
    if (warn.timerLearning.next_save == nil or warn.timerLearning.next_save == 0 or
        deadline < warn.timerLearning.next_save) then
        warn.timerLearning.next_save = deadline;
    end
end

local function clean_action_name(value)
    local text = clean_log_subject(value);
    text = text:gsub('[%.%!%?]+$', '');
    return trim(text);
end

local function is_hostile_learning_actor(actor)
    if (actor == nil or actor == '') then return false; end
    local lower = actor:lower();
    if (get_friendly_name_lookup()[lower]) then return false; end

    -- Learning is deliberately limited to entities currently known to be hostile.  This
    -- prevents party members, trusts, pets, and unrelated chat lines from polluting data.
    return warn.debuffs.mob_names[lower] ~= nil;
end

local function get_learning_counts()
    local counts = { observing = 0, suggested = 0, approved = 0, ignored = 0 };
    for _, entry in pairs(warn.timerLearning.entries or {}) do
        local status = tostring(entry.status or 'observing');
        if (counts[status] ~= nil) then counts[status] = counts[status] + 1; end
    end
    return counts;
end

local function get_sorted_learning_entries(statusFilter)
    local result = {};
    for key, entry in pairs(warn.timerLearning.entries or {}) do
        local status = tostring(entry.status or 'observing');
        if (statusFilter == nil or statusFilter[status]) then
            table.insert(result, { key = key, entry = entry });
        end
    end
    table.sort(result, function (a, b)
        if ((a.entry.updated_at or 0) ~= (b.entry.updated_at or 0)) then
            return (a.entry.updated_at or 0) > (b.entry.updated_at or 0);
        end
        local left = tostring(a.entry.actor or '') .. '|' .. tostring(a.entry.ability or '');
        local right = tostring(b.entry.actor or '') .. '|' .. tostring(b.entry.ability or '');
        return left:lower() < right:lower();
    end);
    return result;
end

local function set_learning_status(key, entry, status)
    if (entry == nil) then return; end
    entry.status = status;
    entry.updated_at = os.time();
    if (status == 'approved') then
        entry.approved_interval = tonumber(entry.interval);
        entry.approved_at = os.time();
    elseif (status ~= 'approved') then
        if (entry.interval == nil and entry.approved_interval ~= nil) then
            entry.interval = tonumber(entry.approved_interval);
        end
        entry.approved_interval = nil;
        warn.timerLearning.active_timers[key or ''] = nil;
    end
    mark_learning_dirty(true);
end

local function forget_learning_entry(key)
    if (key == nil) then return; end
    warn.timerLearning.entries[key] = nil;
    warn.timerLearning.active_timers[key] = nil;
    if (warn.timerLearning.selected_key == key) then warn.timerLearning.selected_key = nil; end
    mark_learning_dirty(true);
end

local function record_timer_learning_event(actorText, abilityText, eventType)
    ensure_learning_settings();
    if (not warn.settings.learning.enabled or warn.timerLearning.engine == nil) then return; end

    local actor = clean_action_name(actorText);
    local ability = clean_action_name(abilityText);
    if (actor == '' or ability == '' or not is_hostile_learning_actor(actor)) then return; end

    local nowEpoch = os.time();
    local entry, changed, becameSuggestion, reason = warn.timerLearning.engine.record(
        warn.timerLearning.entries, actor, ability, eventType, nowEpoch, warn.settings.learning);

    if (changed) then
        local key = warn.timerLearning.engine.make_key(actor, ability);
        if (entry.status == 'approved' and tonumber(entry.approved_interval) ~= nil) then
            local interval = tonumber(entry.approved_interval);
            warn.timerLearning.active_timers[key] = {
                actor = entry.actor,
                ability = entry.ability,
                interval = interval,
                minimum = tonumber(entry.minimum) or interval,
                maximum = tonumber(entry.maximum) or interval,
                started_at = os.clock(),
                next_at = os.clock() + interval,
            };
        end
        mark_learning_dirty(becameSuggestion);
    end

    if (becameSuggestion) then
        print(chat.header(addon.name):append(chat.message(string.format(
            'Readiness observation: %s - %s repeated near %s (%d uses, %.0f%% confidence). Review it in Options > Learning.',
            tostring(entry.actor), tostring(entry.ability), format_seconds(entry.interval or 0),
            tonumber(entry.uses) or 0, (tonumber(entry.confidence) or 0) * 100))));
    elseif (warn.debug and reason ~= 'duplicate_resolution' and reason ~= 'too_close') then
        print(chat.header(addon.name):append(chat.message(string.format(
            'Timer learning: %s - %s (%s, use %d)', actor, ability, tostring(reason), tonumber(entry.uses) or 0))));
    end
end

local function action_event_key(actor, ability, eventType)
    return (tostring(actor or '') .. '|' .. tostring(ability or '') .. '|' .. tostring(eventType or '')):lower();
end

local function schedule_verified_rule_timer(rule, now)
    if (rule == nil or rule.timer == nil) then return; end
    local definition = {};
    for key, value in pairs(rule.timer) do definition[key] = value; end
    definition.id = definition.id or rule.id;
    definition.label = definition.label or rule.ability or rule.actor;
    definition.source_rule_id = rule.id;
    encounterRuntime.schedule_timer(warn.encounter, definition, now);
end

local function apply_verified_rule_mode(rule, now)
    if (rule == nil) then return nil; end
    if (rule.objective ~= nil and rule.objective.kind == 'ongo_fetter_proc') then
        encounterRuntime.start_ongo_proc(warn.encounter, now);
        return true;
    end
    if (rule.mode == nil) then return nil; end
    if (tostring(rule.encounter or '') == 'Aminon') then
        encounterRuntime.set_aminon_mode(warn.encounter, rule.mode.element, rule.mode.response, now);
        return true;
    end
    if (rule.mode.kind == 'shinryu_wings') then
        return encounterRuntime.set_shinryu_wings(warn.encounter, rule.mode.state, now, rule.ability);
    end
    if (rule.mode.kind == 'shinryu_supernova') then
        encounterRuntime.prepare_shinryu_supernova(warn.encounter, now);
        return true;
    end
    return nil;
end

local function note_encounter_action(actorName, now)
    if (tostring(actorName or ''):lower() == 'bumba' and warn.encounter.bumba.engaged_at == nil) then
        ensure_context_settings();
        encounterRuntime.start_bumba(warn.encounter, warn.settings.context.bumba_vengeance, now);
    end
end

local function process_detected_action(actorName, abilityName, eventType, rawMessage, source, context)
    if (abilityName == nil or abilityName == '') then return false; end
    actorName = clean_action_name(actorName);
    abilityName = clean_action_name(abilityName);
    if (abilityName == '') then return false; end

    local key = action_event_key(actorName, abilityName, eventType);
    local now = os.clock();
    if (source == 'text' and warn.reactive.recent[key] ~= nil and (now - warn.reactive.recent[key]) < 1.5) then
        if (warn.debug) then
            print(chat.header(addon.name):append(chat.message('Text action deduplicated after packet recognition: ' .. abilityName)));
        end
        return true;
    end
    if (source == 'packet') then warn.reactive.recent[key] = now; end
    if (source == 'packet' and ((warn.reactive.packet_actions or 0) % 100) == 0) then
        for recentKey, timestamp in pairs(warn.reactive.recent) do
            if ((now - timestamp) > 5.0) then warn.reactive.recent[recentKey] = nil; end
        end
    end

    if (warn.settings.context.encounter_detection and warn.activeEncounter.index ~= nil) then
        local previousEncounterKey = warn.activeEncounter.state.active_key;
        local transition = warn.activeEncounter.engine.observe_action(
            warn.activeEncounter.index, warn.activeEncounter.state,
            actorName, abilityName, eventType, get_current_zone_id(), now);
        if (transition.kind == 'started' and previousEncounterKey ~= nil and
            previousEncounterKey ~= warn.activeEncounter.state.active_key) then
            warn.encounter = encounterRuntime.new_state();
        end
        if (warn.debug and (transition.kind == 'started' or transition.kind == 'ambiguous')) then
            print(chat.header(addon.name):append(chat.message('Encounter detection: ' .. tostring(transition.kind) ..
                ' from ' .. tostring(actorName) .. ' / ' .. tostring(abilityName))));
        end
    end

    record_timer_learning_event(actorName, abilityName, eventType);
    note_encounter_action(actorName, now);

    -- Only verified rules and explicit Custom Watches can create a player-facing alert.
    -- Unknown observations remain local Learning evidence.
    local synthetic = rawMessage or (actorName .. ' ' .. eventType .. ' ' .. abilityName);
    local rule = find_context_ability_rule(eventType, abilityName, synthetic);
    if (rule == nil and warn.activeEncounter.state.active_key ~= nil) then
        local observation = warn.activeEncounter.engine.record_unknown(
            warn.activeEncounter.state, actorName, abilityName, eventType, os.time());
        local learningKey = warn.timerLearning.engine ~= nil and
            warn.timerLearning.engine.make_key(actorName, abilityName) or nil;
        local learningEntry = learningKey ~= nil and warn.timerLearning.entries[learningKey] or nil;
        local profile = warn.activeEncounter.engine.get_profile(warn.activeEncounter.index, warn.activeEncounter.state);
        if (observation ~= nil and learningEntry ~= nil and profile ~= nil) then
            learningEntry.encounter_key = profile.key;
            learningEntry.encounter = profile.encounter;
            learningEntry.content = profile.content;
            mark_learning_dirty(false);
        end
    end
    local modeChanged = nil;
    if (rule ~= nil and rule.verified == true) then
        schedule_verified_rule_timer(rule, now);
        modeChanged = apply_verified_rule_mode(rule, now);
    end
    local shouldTrigger = rule == nil or rule.suppress_when_mode_unchanged ~= true or modeChanged == true;
    if (rule ~= nil and rule.verified == true and shouldTrigger and trigger_context_rule(rule, abilityName, nil, context)) then
        if (warn.debug) then
            print(chat.header(addon.name):append(chat.message('Context Match: YES (' .. tostring(rule.id) .. ')')));
        end
        return true;
    end

    if (eventType == 'readies' and warn.enabledLookup[abilityName:lower()] ~= nil) then
        trigger_warning(abilityName);
        return true;
    end
    return false;
end

local function find_entity_name_by_server_id(serverId)
    local entityManager = AshitaCore:GetMemoryManager():GetEntity();
    if (entityManager == nil or serverId == nil) then return nil; end
    local mapSize = entityManager:GetEntityMapSize();
    for index = 0, mapSize - 1 do
        local id = entityManager:GetServerId(index);
        if (tonumber(id) == tonumber(serverId)) then
            local entity = entityManager:GetRawEntity(index);
            if (entity ~= nil and entity.Name ~= nil and tostring(entity.Name) ~= '') then
                return tostring(entity.Name);
            end
        end
    end
    return nil;
end

local function find_entity_position_by_server_id(serverId)
    local entityManager = AshitaCore:GetMemoryManager():GetEntity();
    if (entityManager == nil or serverId == nil) then return nil; end
    local mapSize = entityManager:GetEntityMapSize();
    for index = 0, mapSize - 1 do
        if (tonumber(entityManager:GetServerId(index)) == tonumber(serverId)) then
            local x, y, z = entity_position(entityManager:GetRawEntity(index));
            if (x ~= nil) then return { x=x, y=y, z=z }; end
            return nil;
        end
    end
    return nil;
end

local function get_player_position()
    local party = AshitaCore:GetMemoryManager():GetParty();
    local entityManager = AshitaCore:GetMemoryManager():GetEntity();
    if (party == nil or entityManager == nil) then return nil; end
    local ok, index = pcall(function () return party:GetMemberTargetIndex(0); end);
    if (not ok or index == nil) then return nil; end
    local x, y, z = entity_position(entityManager:GetRawEntity(index));
    return x ~= nil and { x=x, y=y, z=z } or nil;
end

local function build_entity_name_lookup()
    local result = {};
    local entityManager = AshitaCore:GetMemoryManager():GetEntity();
    if (entityManager == nil) then return result; end
    local mapSize = entityManager:GetEntityMapSize();
    for index = 0, mapSize - 1 do
        local id = tonumber(entityManager:GetServerId(index)) or 0;
        if (id ~= 0) then
            local entity = entityManager:GetRawEntity(index);
            if (entity ~= nil and entity.Name ~= nil and tostring(entity.Name) ~= '') then
                result[id] = tostring(entity.Name);
            end
        end
    end
    return result;
end

local function resolve_packet_action_name(actionType, actionId)
    local resources = AshitaCore:GetResourceManager();
    if (resources == nil or actionId == nil) then return nil; end

    if (actionType == 4 or actionType == 8) then
        local spell = resources:GetSpellById(actionId);
        if (spell ~= nil and spell.Name ~= nil) then return spell.Name[1]; end
        return nil;
    end

    if (actionId < 256) then
        local ability = resources:GetAbilityById(actionId);
        if (ability ~= nil and ability.Name ~= nil) then return ability.Name[1]; end
        return nil;
    end
    return resources:GetString('monsters.abilities', actionId - 256);
end


local function resolve_spell_element(spellId)
    local resources = AshitaCore:GetResourceManager();
    if (resources == nil or spellId == nil) then return nil; end
    local spell = resources:GetSpellById(spellId);
    return spell ~= nil and spellElementNames[tonumber(spell.Element)] or nil;
end

local function observe_elemental_objective_results(parsed, resolvedTargets, now)
    if (parsed.action_type ~= 4) then return; end
    local spellId = tonumber(parsed.param17);
    local spellName = resolve_packet_action_name(4, spellId);
    local element = resolve_spell_element(spellId);
    if (spellName == nil or element == nil) then return; end
    warn.reactive.objective_evidence_serial = (warn.reactive.objective_evidence_serial or 0) + 1;
    local serial = warn.reactive.objective_evidence_serial;

    for targetIndex, target in ipairs(resolvedTargets or {}) do
        local targetLower = tostring(target.name or ''):lower();
        for actionIndex, action in ipairs(target.actions or {}) do
            local damage = tonumber(action.param) or 0;
            if (damage > 0 and targetLower == 'aminon' and warn.encounter.aminon.active) then
                encounterRuntime.observe_aminon_element(warn.encounter, {
                    key=string.format('%d:%d:%d', serial, targetIndex, actionIndex),
                    type='elemental_hit', element=element, name=spellName, target=target.name,
                }, now);
            end
            if (damage > 0 and targetLower == 'ongo' and warn.encounter.ongo.active and
                magicBurstMessages[tonumber(action.message) or -1]) then
                encounterRuntime.observe_ongo_burst(warn.encounter, {
                    key=string.format('%d:%d:%d', serial, targetIndex, actionIndex),
                    type='magic_burst', element=element, name=spellName, target=target.name,
                }, now);
            end
        end
    end
end

local function process_action_packet(event)
    ensure_context_settings();
    if (not warn.settings.context.packet_recognition or warn.actionPacket == nil) then return; end
    local raw = event.data_raw or event.data;
    local parsed, err = warn.actionPacket.parse(raw, event.size, function (data, offset, length)
        return ashita.bits.unpack_be(data, 0, offset, length);
    end, warn.settings.context.packet_layout);
    if (parsed == nil) then
        if (warn.debug) then print(chat.header(addon.name):append(chat.warning('0x028 parse skipped: ' .. tostring(err)))); end
        return;
    end

    local actor = find_entity_name_by_server_id(parsed.actor_id);
    if (actor ~= nil and actor:lower() == 'bumba' and warn.settings.context.encounter_diagnostics) then
        local signature = string.format('%d:%d:%d:%d:%d', tonumber(parsed.action_type) or -1,
            tonumber(parsed.param) or -1, tonumber(parsed.action_param) or -1,
            tonumber(parsed.animation) or -1, tonumber(parsed.special_effect) or -1);
        local details = {
            signature=signature, at=os.clock(), action_type=parsed.action_type, param=parsed.param,
            action_param=parsed.action_param, animation=parsed.animation,
            special_effect=parsed.special_effect, message=parsed.message,
        };
        if (encounterRuntime.record_bumba_packet(warn.encounter, signature, details) and warn.debug) then
            print(chat.header(addon.name):append(chat.message('Bumba packet signature: ' .. signature)));
        end
    end

    local resolvedTargets = {};
    local entityNames = build_entity_name_lookup();
    for _, target in ipairs(parsed.targets or {}) do
        local firstAction = target.actions ~= nil and target.actions[1] or nil;
        table.insert(resolvedTargets, {
            id=target.id,
            name=entityNames[tonumber(target.id) or 0] or ('Target ' .. tostring(target.id or '?')),
            action_count=target.action_count,
            message=firstAction ~= nil and firstAction.message or nil,
            reaction=firstAction ~= nil and firstAction.reaction or nil,
            actions=target.actions,
        });
    end
    warn.reactive.last_target_count = #resolvedTargets;

    if (parsed.action_type == 4) then
        observe_elemental_objective_results(parsed, resolvedTargets, os.clock());
        return;
    end

    -- Completed monster TP moves carry every affected target. They do not create a
    -- duplicate ready alert, but they provide encounter triage and future status evidence.
    if (parsed.action_type == 11) then
        local completedAbility = resolve_packet_action_name(parsed.action_type, parsed.param17);
        local doom = warn.encounter.shinryu ~= nil and warn.encounter.shinryu.doom or nil;
        local awaitingSupernova = doom ~= nil and doom.pending == true and doom.readied_at ~= nil and
            (os.clock() - doom.readied_at) <= 8.0;
        if (actor ~= nil and tostring(actor):lower() == 'shinryu' and
            (tostring(completedAbility or ''):lower() == 'supernova' or awaitingSupernova)) then
            encounterRuntime.observe_shinryu_supernova_targets(warn.encounter, resolvedTargets, os.clock());
            warn.reactive.last_packet_action = tostring(actor) .. ' - ' .. tostring(completedAbility or 'Supernova') ..
                string.format(' (%d targets)', #resolvedTargets);
        end
        if (actor ~= nil and tostring(actor):lower() == 'elemental circle') then
            local now = os.clock();
            encounterRuntime.observe_circle_pulse(warn.encounter, parsed.actor_id, now,
                find_entity_position_by_server_id(parsed.actor_id));
            local pulse = encounterRuntime.nearest_recent_circle_pulse(warn.encounter, get_player_position(), now, 6.0);
            if (pulse ~= nil and pulse.distance <= 45 and
                (now - (warn.encounter.circles.last_player_warning_at or 0)) >= 3.0) then
                warn.encounter.circles.last_player_warning_at = now;
                trigger_context_rule({ id='__divergence_circle_pulse', verified=true, severity='critical',
                    prediction='reactive', sound='warning.wav', duration=3.0 }, 'ELEMENTAL CIRCLE',
                    string.format('PULSE OBSERVED %.1f YALMS AWAY!\nMOVE OUT OR MITIGATE', pulse.distance));
            end
        end
        if (actor ~= nil and completedAbility ~= nil and tostring(completedAbility) ~= '') then
            local targetName = resolvedTargets[1] ~= nil and resolvedTargets[1].name or nil;
            local targetNames = {};
            for _, target in ipairs(resolvedTargets) do table.insert(targetNames, target.name); end
            process_detected_action(actor, completedAbility, 'uses', nil, 'packet', {
                target_name=targetName, target_id=parsed.target_id,
                target_names=targetNames, targets=resolvedTargets,
            });
        end
        return;
    end

    if (parsed.action_type ~= 7 and parsed.action_type ~= 8) then return; end
    -- Some private-server 0x028 packets leave the message field at zero even though the
    -- category and action payload are valid. Category 7/8 already identifies a begin event.
    if (parsed.action_count == nil or parsed.action_count < 1) then return; end

    local ability = resolve_packet_action_name(parsed.action_type, parsed.action_param);
    if (actor == nil or ability == nil or tostring(ability) == '') then return; end

    local eventType = parsed.action_type == 7 and 'readies' or 'starts_casting';
    warn.reactive.packet_actions = (warn.reactive.packet_actions or 0) + 1;
    warn.reactive.last_packet_action = tostring(actor) .. ' - ' .. tostring(ability);
    warn.reactive.last_packet_layout = tostring(parsed.layout or 'unknown');
    local targetName = resolvedTargets[1] ~= nil and resolvedTargets[1].name or nil;
    local targetNames = {};
    for _, target in ipairs(resolvedTargets) do table.insert(targetNames, target.name); end
    process_detected_action(actor, ability, eventType, nil, 'packet', {
        target_name=targetName, target_id=parsed.target_id,
        target_names=targetNames, targets=resolvedTargets,
    });
end

local function save_pending_learning_data()
    if (warn.timerLearning.dirty and os.clock() >= (warn.timerLearning.next_save or 0)) then
        save_learning_data();
        warn.timerLearning.next_save = 0;
    end
end

--------------------------------------------------------------------------------------------------
-- Data-only community database updates
--------------------------------------------------------------------------------------------------

local function set_community_status(status, message)
    warn.community.status = status;
    warn.community.message = tostring(message or '');
end

local function https_get(url, maximumBytes)
    if (urlmon == nil) then return nil, 'Windows HTTPS support is unavailable.'; end
    if (type(url) ~= 'string' or not url:match('^https://')) then return nil, 'Only HTTPS downloads are allowed.'; end

    local tempPath = (addon.path .. '/data/.warn_download.tmp'):gsub('/', '\\');
    os.remove(tempPath);
    local requestUrl = url;
    if (url == COMMUNITY_MANIFEST_URL) then
        requestUrl = url .. '?warn_check=' .. tostring(os.time());
    end
    local ok, result = pcall(function ()
        return tonumber(urlmon.URLDownloadToFileA(nil, requestUrl, tempPath, 0, nil));
    end);
    if (not ok or result ~= 0) then
        os.remove(tempPath);
        return nil, 'Windows HTTPS download failed (code ' .. tostring(result) .. ').';
    end
    local body, err = read_binary_file(tempPath, maximumBytes);
    os.remove(tempPath);
    if (body == nil) then return nil, err; end
    return body;
end

local function check_community_database_now()
    if (warn.community.busy or warn.community.engine == nil) then return false; end
    warn.community.busy = true;
    set_community_status('checking', 'Checking the official community database...');

    local body, err = https_get(COMMUNITY_MANIFEST_URL, 64 * 1024);
    if (body == nil) then
        warn.community.busy = false;
        set_community_status('error', err);
        return false;
    end

    local raw; raw, err = decode_json(body, 'Community manifest');
    if (raw == nil) then
        warn.community.busy = false;
        set_community_status('error', err);
        return false;
    end
    local manifest; manifest, err = warn.community.engine.validate_manifest(raw);
    if (manifest == nil) then
        warn.community.busy = false;
        set_community_status('error', 'Manifest rejected: ' .. tostring(err));
        return false;
    end

    local compatible = warn.community.engine.compare_versions(addon.version, manifest.minimum_warn_version);
    if (compatible == nil or compatible < 0) then
        warn.community.busy = false;
        set_community_status('error', 'This database requires Warn ' .. tostring(manifest.minimum_warn_version) .. ' or newer.');
        return false;
    end

    warn.community.remote_manifest = manifest;
    warn.settings.community.last_checked_at = os.time();
    save_settings();

    local installedVersion = warn.community.installed and tonumber(warn.community.installed.database_version) or 0;
    if (tonumber(manifest.database_version) > installedVersion) then
        set_community_status('update_available', string.format(
            'Database v%d is available (%d rules, %d encounters).',
            manifest.database_version, manifest.rule_count, manifest.encounter_count));
    else
        set_community_status('up_to_date', 'Community database is up to date.');
    end
    warn.community.busy = false;
    return true;
end

local function write_binary_file(path, body)
    local file, err = io.open(path, 'wb');
    if (file == nil) then return false, tostring(err or 'Could not open file for writing.'); end
    local ok, writeErr = file:write(body);
    file:close();
    if (not ok) then return false, tostring(writeErr or 'Could not write file.'); end
    return true;
end

local function install_community_database_now()
    if (warn.community.busy) then return false; end
    local manifest = warn.community.remote_manifest;
    if (manifest == nil) then
        set_community_status('error', 'Check for updates before installing.');
        return false;
    end

    warn.community.busy = true;
    set_community_status('downloading', 'Downloading and validating database v' .. tostring(manifest.database_version) .. '...');
    local body, err = https_get(manifest.database_url, 2 * 1024 * 1024);
    if (body == nil) then
        warn.community.busy = false;
        set_community_status('error', err);
        return false;
    end

    local actualHash = warn.community.sha256.digest(body):lower();
    if (actualHash ~= tostring(manifest.sha256):lower()) then
        warn.community.busy = false;
        set_community_status('error', 'SHA-256 verification failed. The downloaded database was not installed.');
        return false;
    end

    local database; database, err = decode_community_database(body, manifest.database_version);
    if (database == nil) then
        warn.community.busy = false;
        set_community_status('error', err);
        return false;
    end
    local actualRuleCount = #(database.ability_rules or {}) + #(database.state_rules or {});
    if (actualRuleCount ~= tonumber(manifest.rule_count) or #(database.catalog or {}) ~= tonumber(manifest.encounter_count)) then
        warn.community.busy = false;
        set_community_status('error', 'Manifest counts do not match the downloaded database.');
        return false;
    end

    local livePath = community_data_path();
    local tempPath = community_data_path('.tmp');
    local backupPath = community_data_path('.bak');
    os.remove(tempPath);
    local wrote; wrote, err = write_binary_file(tempPath, body);
    if (not wrote) then
        warn.community.busy = false;
        set_community_status('error', 'Could not stage database update: ' .. tostring(err));
        return false;
    end

    os.remove(backupPath);
    local existing = io.open(livePath, 'rb');
    if (existing ~= nil) then
        existing:close();
        local backedUp, backupErr = os.rename(livePath, backupPath);
        if (not backedUp) then
            os.remove(tempPath);
            warn.community.busy = false;
            set_community_status('error', 'Could not back up the installed database: ' .. tostring(backupErr));
            return false;
        end
    end

    local installed, installErr = os.rename(tempPath, livePath);
    if (not installed) then
        os.rename(backupPath, livePath);
        os.remove(tempPath);
        warn.community.busy = false;
        set_community_status('error', 'Could not activate the database update: ' .. tostring(installErr));
        return false;
    end

    load_installed_community_database(false);
    load_context_rules();
    update_community_backup_state();
    warn.community.busy = false;
    set_community_status('installed', string.format(
        'Installed database v%d: %d rules and %d encounters loaded.',
        database.database_version, actualRuleCount, #(database.catalog or {})));
    return true;
end

local function rollback_community_database_now()
    if (warn.community.busy or not warn.community.backup_available) then return false; end
    warn.community.busy = true;
    local livePath = community_data_path();
    local backupPath = community_data_path('.bak');
    local swapPath = community_data_path('.swap');

    local backupBody, err = read_binary_file(backupPath, 2 * 1024 * 1024);
    if (backupBody == nil) then
        warn.community.busy = false;
        set_community_status('error', 'Could not read rollback database: ' .. tostring(err));
        return false;
    end
    local rollbackDatabase; rollbackDatabase, err = decode_community_database(backupBody, nil);
    if (rollbackDatabase == nil) then
        warn.community.busy = false;
        set_community_status('error', 'Rollback database rejected: ' .. tostring(err));
        return false;
    end

    os.remove(swapPath);
    local movedCurrent, moveErr = os.rename(livePath, swapPath);
    if (not movedCurrent) then
        warn.community.busy = false;
        set_community_status('error', 'Could not prepare rollback: ' .. tostring(moveErr));
        return false;
    end
    local restored, restoreErr = os.rename(backupPath, livePath);
    if (not restored) then
        os.rename(swapPath, livePath);
        warn.community.busy = false;
        set_community_status('error', 'Could not restore rollback database: ' .. tostring(restoreErr));
        return false;
    end
    os.rename(swapPath, backupPath);

    load_installed_community_database(false);
    load_context_rules();
    update_community_backup_state();
    warn.community.busy = false;
    set_community_status('rolled_back', 'Restored community database v' .. tostring(rollbackDatabase.database_version) .. '.');
    return true;
end

local function process_community_requests()
    if (warn.community.busy) then return; end
    if (warn.community.rollback_requested) then
        warn.community.rollback_requested = false;
        rollback_community_database_now();
    elseif (warn.community.update_requested) then
        warn.community.update_requested = false;
        install_community_database_now();
    elseif (warn.community.check_requested) then
        warn.community.check_requested = false;
        check_community_database_now();
    end
end

local function queue_automatic_community_check()
    ensure_community_settings();
    local cfg = warn.settings.community;
    if (not cfg.enabled or not cfg.auto_check or warn.community.auto_check_queued) then return; end
    warn.community.auto_check_queued = true;
    local interval = math.max(1, tonumber(cfg.check_interval_hours) or 24) * 3600;
    if ((os.time() - (tonumber(cfg.last_checked_at) or 0)) >= interval) then
        warn.community.check_requested = true;
    end
end

-- Compatibility wrappers preserve the v1.5.x commands while the implementation is now unified.
local function clear_sleep_tracker(announce)
    clear_debuff_status(get_debuff_definition('sleep'), announce);
end

local function print_sleep_tracker()
    print_debuff_tracker('sleep');
end

local function sleep_tracker_mark_asleep(name)
    local definition = get_debuff_definition('sleep');
    if (definition ~= nil) then debuff_mark_gained(definition, name); end
end

local function sleep_tracker_mark_awake(name)
    local definition = get_debuff_definition('sleep');
    if (definition ~= nil) then return debuff_mark_lost(definition, name, false); end
    return false;
end

local function clear_petrify_tracker(announce)
    clear_debuff_status(get_debuff_definition('petrify'), announce);
end

local function print_petrify_tracker()
    print_debuff_tracker('petrify');
end

local function petrify_tracker_mark_petrified(name)
    local definition = get_debuff_definition('petrify');
    if (definition ~= nil) then debuff_mark_gained(definition, name); end
end

local function petrify_tracker_mark_recovered(name)
    local definition = get_debuff_definition('petrify');
    if (definition ~= nil) then return debuff_mark_lost(definition, name, false); end
    return false;
end

-- Maintained-debuff state rules consume encounter-specific log messages that explicitly
-- indicate a debuff is active or has worn off. This is intentionally data-driven so the
-- same engine can later track other encounter mechanics without hard-coding boss names.
local function message_matches_any(rawLower, fragments)
    if (rawLower == nil or fragments == nil) then return false; end
    for _, fragment in ipairs(fragments) do
        local wanted = tostring(fragment or ''):lower();
        if (wanted ~= '' and rawLower:find(wanted, 1, true) ~= nil) then
            return true;
        end
    end
    return false;
end

local function process_maintained_debuff_messages(rawMessage)
    if (not warn.settings.context.enabled or not warn.settings.context.state_triggers) then return; end
    if (rawMessage == nil or rawMessage == '') then return; end

    local rawLower = tostring(rawMessage):lower();
    local now = os.clock();

    for _, rule in ipairs(warn.rules.state_rules or {}) do
        local detectorEnabled = warn.settings.context.encounter_detection == true and warn.activeEncounter.index ~= nil;
        local encounterMatches = not detectorEnabled or
            (warn.activeEncounter.state.active_key ~= nil and rule.__encounter_key == warn.activeEncounter.state.active_key);
        if (encounterMatches and rule.type == 'debuff_maintenance' and is_rule_enabled(rule)) then
            local state = warn.ruleState[rule.id];
            -- Encounter messages such as Breadwinner's scratchy-throat messages do not
            -- include the actor name, so only consume them while the configured actor is present.
            if (state ~= nil and state.present) then
                if (message_matches_any(rawLower, rule.gain_messages)) then
                    state.status_active = true;
                    state.triggered = true;
                    state.last_status_change = now;
                    if (warn.debug) then
                        print(chat.header(addon.name):append(chat.message(tostring(rule.actor) .. ' tracked debuff: ACTIVE')));
                    end
                elseif (message_matches_any(rawLower, rule.loss_messages)) then
                    state.status_active = false;
                    state.triggered = false;
                    state.last_status_change = now;

                    -- Alert immediately if the current character has an available way to
                    -- reapply the debuff. If not, update_state_rules will retry quietly and
                    -- fire as soon as a valid counter becomes usable.
                    if (trigger_context_rule(rule, rule.actor, rule.loss_message or rule.message)) then
                        state.triggered = true;
                        state.last_trigger = now;
                    end

                    if (warn.debug) then
                        print(chat.header(addon.name):append(chat.message(tostring(rule.actor) .. ' tracked debuff: LOST')));
                    end
                end
            end
        end
    end
end

local function update_state_rules()
    if (not warn.settings.context.enabled) then return; end
    local stateRulesEnabled = warn.settings.context.state_triggers == true;
    local detectorEnabled = warn.settings.context.encounter_detection == true and warn.activeEncounter.index ~= nil;
    if (not stateRulesEnabled and not detectorEnabled) then return; end

    local now = os.clock();
    if (now < warn.entityScan.next_scan) then return; end

    -- Build one exact-name lookup and scan the entity map only once. When none of the
    -- configured state-rule actors exist, fall back to a slow 1-second idle scan so
    -- Warn does not continuously walk the full entity table while the player is elsewhere.
    local wanted = {};
    if (stateRulesEnabled) then
        for _, rule in ipairs(warn.rules.state_rules or {}) do
            if (is_rule_enabled(rule) and rule_matches_current_zone(rule) and rule.actor ~= nil) then wanted[rule.actor] = true; end
        end
    end
    local detectorWanted = {};
    if (detectorEnabled) then
        for actor in pairs(warn.activeEncounter.index.actor_index or {}) do detectorWanted[actor] = true; end
    end

    local found = {};
    local encounterActors = {};
    local entityManager = AshitaCore:GetMemoryManager():GetEntity();
    if (entityManager ~= nil) then
        local mapSize = entityManager:GetEntityMapSize();
        for i = 0, mapSize - 1 do
            local entity = entityManager:GetRawEntity(i);
            if (entity ~= nil and entity.Name ~= nil) then
                local entityName = tostring(entity.Name);
                if (wanted[entityName]) then found[entityName] = { index = i, entity = entity }; end
                if (detectorWanted[entityName:lower()]) then
                    local hostile = entity.SpawnFlags ~= nil and bit.band(entity.SpawnFlags, 0x10) ~= 0;
                    local hpp = entity_health_percent(entity, i);
                    if (hostile and (hpp == nil or hpp > 0)) then encounterActors[entityName] = true; end
                end
            end
        end
    end
    warn.entityScan.entities = found;

    local anyFound = next(found) ~= nil or next(encounterActors) ~= nil;
    warn.entityScan.next_scan = now + (anyFound and warn.entityScan.active_interval or warn.entityScan.idle_interval);

    if (detectorEnabled) then
        local transition = warn.activeEncounter.engine.observe_entities(
            warn.activeEncounter.index, warn.activeEncounter.state, encounterActors,
            get_current_zone_id(), now, warn.settings.context.encounter_dismiss_seconds);
        if (transition.kind == 'ended') then
            warn.encounter = encounterRuntime.new_state();
        elseif (warn.debug and (transition.kind == 'started' or transition.kind == 'ambiguous')) then
            print(chat.header(addon.name):append(chat.message('Encounter detection: ' .. tostring(transition.kind) .. ' from nearby entities.')));
        end
    end

    if (not stateRulesEnabled) then return; end
    for _, rule in ipairs(warn.rules.state_rules or {}) do
        local state = warn.ruleState[rule.id];
        local encounterMatches = not detectorEnabled or
            (warn.activeEncounter.state.active_key ~= nil and rule.__encounter_key == warn.activeEncounter.state.active_key);
        if (encounterMatches and is_rule_enabled(rule) and rule_matches_current_zone(rule) and state ~= nil and rule.actor ~= nil) then
            local foundEntry = found[rule.actor];
            local entity = foundEntry ~= nil and foundEntry.entity or nil;

            if (entity == nil) then
                state.index = nil;
                state.present = false;
                state.triggered = false;
                state.last_x = nil;
                state.last_y = nil;
                state.last_z = nil;
                state.armed = true;
                state.stationary_since = nil;
                state.status_active = nil;
                state.last_status_change = 0;
                state.last_hpp = nil;
            else
                state.index = foundEntry.index;

                if (rule.type == 'entity_present') then
                    state.present = true;
                    -- Retry until the rule can actually fire. This matters for rules that
                    -- require a currently-usable counter (for example Silence being off recast).
                    if (not state.triggered) then
                        if (trigger_context_rule(rule, rule.actor)) then
                            state.triggered = true;
                            state.last_trigger = now;
                        end
                    end
                elseif (rule.type == 'debuff_maintenance') then
                    state.present = true;
                    -- On first sight of the encounter, assume the tracked debuff still needs
                    -- to be applied. Thereafter, encounter log messages re-arm this rule only
                    -- when the debuff is explicitly reported as lost.
                    if (not state.triggered and state.status_active ~= true) then
                        if (trigger_context_rule(rule, rule.actor)) then
                            state.triggered = true;
                            state.last_trigger = now;
                        end
                    end
                elseif (rule.type == 'entity_hp_threshold') then
                    state.present = true;
                    local hpp = entity_health_percent(entity, foundEntry.index);
                    local threshold = tonumber(rule.threshold) or 50;
                    if (hpp ~= nil and not state.triggered and hpp <= threshold) then
                        if (trigger_context_rule(rule, rule.actor, nil, { target_name=rule.actor })) then
                            state.triggered = true;
                            state.last_trigger = now;
                        end
                    end
                    if (hpp ~= nil) then state.last_hpp = hpp; end
                elseif (rule.type == 'entity_movement') then
                    local x, y, z = entity_position(entity);
                    if (x ~= nil) then
                        if (state.last_x ~= nil) then
                            local dx = x - state.last_x;
                            local dy = y - state.last_y;
                            local dz = z - state.last_z;
                            local moved = math.sqrt((dx * dx) + (dy * dy) + (dz * dz));
                            local threshold = tonumber(rule.movement_threshold) or 0.60;
                            local rearmSeconds = tonumber(rule.rearm_stationary_seconds) or 8.0;

                            if (warn.debug and moved >= 0.10) then
                                print(chat.header(addon.name):append(chat.message(string.format('%s moved %.2f yalms', rule.actor, moved))));
                            end

                            if (moved >= threshold) then
                                state.stationary_since = nil;
                                if (state.armed) then
                                    if (trigger_context_rule(rule, rule.actor)) then
                                        state.armed = false;
                                        state.triggered = true;
                                        state.last_trigger = now;
                                    end
                                end
                            else
                                if (state.stationary_since == nil) then
                                    state.stationary_since = now;
                                elseif (not state.armed and (now - state.stationary_since) >= rearmSeconds) then
                                    -- Housemaker can charge repeatedly. Rearm only after a long stationary
                                    -- period so the immediate retreat after Earthshaker does not double-warn.
                                    state.armed = true;
                                    state.triggered = false;
                                    if (warn.debug) then
                                        print(chat.header(addon.name):append(chat.message(rule.actor .. ' movement trigger re-armed.')));
                                    end
                                end
                            end
                        end

                        state.last_x = x;
                        state.last_y = y;
                        state.last_z = z;
                        state.present = true;
                    end
                end
            end
        end
    end
end

local function trigger_runtime_timer_alert(event)
    if (event == nil or event.timer == nil) then return; end
    local timer = event.timer;
    local message = nil;
    if (event.kind == 'prewarn') then
        message = timer.prewarn_message or string.format('%s IN %d SECONDS!', timer.label, math.max(1, math.ceil(event.remaining)));
    else
        message = timer.due_message or (timer.label .. ' DUE NOW!');
    end
    local rule = find_context_rule_by_id(timer.source_rule_id);
    if (rule == nil) then
        rule = {
            id='__runtime_timer_' .. tostring(timer.id), verified=true, message=message,
            severity=timer.severity or 'critical', prediction='scripted', sound='alarm.wav', duration=5.0,
        };
    end
    trigger_context_rule(rule, timer.label, message);
end

local function update_verified_encounter_timers()
    for _, event in ipairs(encounterRuntime.update_timers(warn.encounter, os.clock())) do
        trigger_runtime_timer_alert(event);
    end
end

local function update_divergence_circle_state()
    local now = os.clock();
    if (now < (warn.encounter.next_object_scan or 0)) then return; end
    warn.encounter.next_object_scan = now + 0.50;

    local alive = 0;
    local bossPresent = false;
    local entityManager = AshitaCore:GetMemoryManager():GetEntity();
    if (entityManager ~= nil) then
        local mapSize = entityManager:GetEntityMapSize();
        for i = 0, mapSize - 1 do
            local entity = entityManager:GetRawEntity(i);
            if (entity ~= nil and entity.Name ~= nil and entity.SpawnFlags ~= nil and bit.band(entity.SpawnFlags, 0x10) ~= 0) then
                local name = tostring(entity.Name);
                if (name == 'Elemental Circle') then alive = alive + 1; end
                if (name == 'Disjoined Elvaan' or name == 'Disjoined Galka' or
                    name == 'Disjoined Tarutaru' or name == 'Disjoined Mithra') then
                    bossPresent = true;
                end
            end
        end
    end

    if (alive > 0 or bossPresent or warn.encounter.circles.active) then
        encounterRuntime.observe_circles(warn.encounter, alive, now);
        if (bossPresent) then warn.encounter.circles.active = true; end
    end
end

local function get_catalog_counts()
    local counts = { total = 0, ambu1 = 0, ambu2 = 0, htmb = 0, missions = 0, abyssea = 0, omen = 0, geas = 0, sortie = 0, odyssey = 0, dynamis = 0, divergence = 0, sinister = 0, skirmish = 0, unity = 0, vagary = 0 };
    for _, entry in ipairs(warn.rules.catalog or {}) do
        counts.total = counts.total + 1;
        if (entry.content == 'Ambuscade' and entry.group == 'Volume 1') then counts.ambu1 = counts.ambu1 + 1; end
        if (entry.content == 'Ambuscade' and entry.group == 'Volume 2') then counts.ambu2 = counts.ambu2 + 1; end
        if (entry.content == 'High-Tier Mission Battlefields') then counts.htmb = counts.htmb + 1; end
        if (entry.content == 'Missions & BCNMs') then counts.missions = counts.missions + 1; end
        if (entry.content == 'Abyssea') then counts.abyssea = counts.abyssea + 1; end
        if (entry.content == 'Omen') then counts.omen = counts.omen + 1; end
        if (entry.content == 'Geas Fete') then counts.geas = counts.geas + 1; end
        if (entry.content == 'Sortie') then counts.sortie = counts.sortie + 1; end
        if (entry.content == 'Odyssey') then counts.odyssey = counts.odyssey + 1; end
        if (entry.content == 'Dynamis') then counts.dynamis = counts.dynamis + 1; end
        if (entry.content == 'Dynamis - Divergence') then counts.divergence = counts.divergence + 1; end
        if (entry.content == 'Sinister Reign') then counts.sinister = counts.sinister + 1; end
        if (entry.content == 'Skirmish') then counts.skirmish = counts.skirmish + 1; end
        if (entry.content == 'Unity Wanted') then counts.unity = counts.unity + 1; end
        if (entry.content == 'Vagary') then counts.vagary = counts.vagary + 1; end
    end
    return counts;
end

local function print_rule_summary()
    local a = #(warn.rules.ability_rules or {});
    local st = #(warn.rules.state_rules or {});
    local c = get_catalog_counts();
    print(chat.header(addon.name):append(chat.message(string.format('Loaded %d action rules + %d state rules across %d indexed encounters. Player: %s', a, st, c.total, get_player_job_text()))));
end

local function print_coverage_summary()
    local c = get_catalog_counts();
    print(chat.header(addon.name):append(chat.message(string.format('Coverage: Ambuscade V1 %d / V2 %d, HTMB %d, Omen %d, Geas %d, Sortie %d, Odyssey %d.', c.ambu1, c.ambu2, c.htmb, c.omen, c.geas, c.sortie, c.odyssey))));
    print(chat.header(addon.name):append(chat.message(string.format('Coverage: Dynamis %d, Divergence %d, Sinister Reign %d.', c.dynamis, c.divergence, c.sinister))));
    print(chat.header(addon.name):append(chat.message(string.format('Coverage: Abyssea %d, Missions/BCNMs %d, Skirmish %d, Unity Wanted %d, Vagary %d.', c.abyssea, c.missions, c.skirmish, c.unity, c.vagary))));
    print(chat.header(addon.name):append(chat.message(string.format('Total indexed encounters: %d.', c.total))));
    print(chat.header(addon.name):append(chat.message(string.format('Currently actionable: %d ability/spell rules + %d encounter-state rules.', #(warn.rules.ability_rules or {}), #(warn.rules.state_rules or {})))));
end

--------------------------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------------------------

-- Native playback, WAV discovery, and process-session detection live in a
-- separate module so Warn's main Ashita chunk stays well below LuaJIT's local limit.

function get_sound_files()
    return T(soundRuntime.get_files(addon.path));
end

function refresh_sound_files(announce)
    warn.soundFiles = get_sound_files();

    local selectedFound = (warn.settings.sound.selected == nil or warn.settings.sound.selected == 'None');
    if (not selectedFound) then
        local wanted = warn.settings.sound.selected:lower();
        warn.soundFiles:each(function (v)
            if (v:lower() == wanted) then
                selectedFound = true;
                -- Preserve the filename exactly as it exists on disk.
                warn.settings.sound.selected = v;
            end
        end);
    end

    if (not selectedFound) then
        warn.settings.sound.selected = 'None';
        save_settings();
    end

    -- Validate every per-debuff sound override against the current sounds folder.
    ensure_debuff_settings();
    for _, definition in ipairs(warn.debuffs.definitions or {}) do
        local override = get_debuff_override(definition, false);
        if (override ~= nil and override.sound ~= nil) then
            local selected = tostring(override.sound);
            if (selected ~= '__global__' and selected ~= '__default__' and selected ~= 'None' and selected ~= '') then
                local found = false;
                warn.soundFiles:each(function (v)
                    if (v:lower() == selected:lower()) then
                        found = true;
                        override.sound = v;
                    end
                end);
                if (not found) then override.sound = '__global__'; end
            end
        end
    end

    if (announce) then
        print(chat.header(addon.name):append(chat.message(string.format('Found %d WAV sound file(s).', math.max(0, #warn.soundFiles - 1)))));
    end
end

function play_sound_file(sel)
    local ok, err = soundRuntime.play(addon.path, sel);
    if (not ok) then
        print(chat.header(addon.name):append(chat.error(tostring(err))));
    end
end

function play_selected_sound()
    play_sound_file(warn.settings.sound.selected);
end

local function play_first_gui_open_sound_once()
    ensure_sound_settings();
    local cfg = warn.settings.sound;
    local shouldPlay, filename, consumed = soundRuntime.consume_first_open(cfg);
    -- Save before attempting playback so a missing or invalid file cannot cause
    -- repeated sound attempts every time the window is reopened.
    if (consumed) then save_settings(); end
    if (shouldPlay) then play_sound_file(filename); end
end

local function set_gui_open(open)
    local shouldOpen = (open == true);
    local isOpening = shouldOpen and warn.isGuiOpen[1] ~= true;
    warn.isGuiOpen[1] = shouldOpen;
    if (isOpening) then
        refresh_sound_files(false);
        play_first_gui_open_sound_once();
    end
end

--------------------------------------------------------------------------------------------------
-- Warning trigger
--------------------------------------------------------------------------------------------------

function trigger_warning(abilityName)
    local matched = warn.enabledLookup[abilityName:lower()];
    if (matched == nil) then
        return;
    end

    submit_warning_payload({
        name=matched, text=nil, rule_id=nil, dedupe_key='manual|' .. matched:lower(),
        sound=nil, sound_policy='global', duration=nil,
        severity='important', prediction='reactive',
    });
end

--------------------------------------------------------------------------------------------------
-- Overlay rendering
--------------------------------------------------------------------------------------------------

function apply_font_appearance()
    local s = warn.settings.overlay;

    warn.font.font_height = math.floor(14 * s.size) + 1;
    warn.font.padding = warn.font.font_height / 4;
    warn.font.color = s.text_color;
    warn.font.color_outline = s.outline_color;

    local bgRgb = bit.band(s.bg_color, 0x00FFFFFF);
    local alphaByte = math.floor((1.0 - s.bg_transparency) * 255);
    warn.font.background.color = bit.bor(bit.lshift(bit.band(alphaByte, 0xFF), 24), bgRgb);
    warn.font.background.visible = true;
end

local function color_with_alpha(color, alpha)
    color = color or { 1, 1, 1, 1 };
    return { color[1], color[2], color[3], math.max(0, math.min(1, alpha or color[4] or 1)) };
end

local function draw_critical_edges(display, severity_color, alpha)
    local overlay = warn.settings.overlay;
    if (overlay.edge_enabled ~= true or (tonumber(overlay.edge_intensity) or 0) <= 0) then return; end

    local scale = get_ui_scale();
    local intensity = math.max(0, math.min(1, tonumber(overlay.edge_intensity) or 0.65));
    local pulse = 1.0;
    if (overlay.reduced_motion ~= true) then
        pulse = 0.84 + 0.16 * math.abs(math.sin(os.clock() * math.pi * 1.35));
    end
    local outer = color_with_alpha(severity_color, 0.50 * intensity * pulse * alpha);
    local clear = color_with_alpha(severity_color, 0);
    local outer_u32 = imgui.GetColorU32(outer);
    local clear_u32 = imgui.GetColorU32(clear);
    local thickness = math.max(28, math.min(display.x, display.y) * 0.075 * scale);

    local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoInputs,
        ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoBringToFrontOnFocus);
    imgui.SetNextWindowPos({ 0, 0 }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ display.x, display.y }, ImGuiCond_Always);
    if (imgui.Begin('##warn_edge_effect', true, flags)) then
        local draw = imgui.GetWindowDrawList();
        draw:AddRectFilledMultiColor({ 0, 0 }, { display.x, thickness }, outer_u32, outer_u32, clear_u32, clear_u32);
        draw:AddRectFilledMultiColor({ 0, display.y - thickness }, { display.x, display.y }, clear_u32, clear_u32, outer_u32, outer_u32);
        draw:AddRectFilledMultiColor({ 0, 0 }, { thickness, display.y }, outer_u32, clear_u32, clear_u32, outer_u32);
        draw:AddRectFilledMultiColor({ display.x - thickness, 0 }, { display.x, display.y }, clear_u32, outer_u32, outer_u32, clear_u32);
    end
    imgui.End();
end

local function split_first_line(value)
    value = tostring(value or '');
    local first, rest = value:match('^([^\n]*)\n?(.*)$');
    return first or value, rest or '';
end

local function draw_line_path(draw, points, color, thickness, closed)
    for index = 1, #points - 1 do
        draw:AddLine(points[index], points[index + 1], color, thickness);
    end
    if (closed == true and #points > 2) then
        draw:AddLine(points[#points], points[1], color, thickness);
    end
end

local function draw_warning_diamond(draw, center_x, center_y, radius, color, thickness)
    draw_line_path(draw, {
        { center_x, center_y - radius },
        { center_x + radius, center_y },
        { center_x, center_y + radius },
        { center_x - radius, center_y },
    }, color, thickness, true);
end

local function draw_warning_crest(draw, x, y, size, brass, brass_dim, text_color)
    local center_x = x + size / 2;
    local center_y = y + size / 2;
    draw:AddCircle({ center_x, center_y }, size * 0.47, brass_dim, 24, math.max(1, size * 0.055));
    draw:AddCircle({ center_x, center_y }, size * 0.38, brass, 24, math.max(1, size * 0.035));
    draw:AddText({ x + size * 0.24, y + size * 0.15 }, text_color, 'W');
end

local function draw_ornate_warning_frame(draw, x, y, width, height, scale, active_theme,
    severity_color, card_opacity, entry_alpha, urgency_pulse, progress)
    local center_x = x + width / 2;
    local center_y = y + height / 2;
    local line = math.max(1, 1.15 * scale);
    local heavy = math.max(1, 1.65 * scale);
    local bg_top = imgui.GetColorU32(color_with_alpha(active_theme.panel_alt,
        math.min(1, card_opacity * 1.10) * entry_alpha));
    local bg_bottom = imgui.GetColorU32(color_with_alpha(active_theme.window_bg,
        card_opacity * entry_alpha));
    local brass = imgui.GetColorU32(color_with_alpha(active_theme.brass, 0.94 * entry_alpha));
    local brass_hover = imgui.GetColorU32(color_with_alpha(active_theme.brass_hover, 0.96 * entry_alpha));
    local brass_dim = imgui.GetColorU32(color_with_alpha(active_theme.brass_dim, 0.82 * entry_alpha));
    local accent = imgui.GetColorU32(color_with_alpha(severity_color,
        0.95 * entry_alpha * urgency_pulse));
    local dark = imgui.GetColorU32(color_with_alpha(active_theme.field_bg,
        math.min(1, card_opacity * 1.12) * entry_alpha));

    -- Three fills create the subtle side points without requiring a texture or polygon fill.
    draw:AddRectFilledMultiColor({ x + 10 * scale, y + 4 * scale },
        { x + width - 10 * scale, y + height - 4 * scale }, bg_top, bg_top, bg_bottom, bg_bottom);
    draw:AddRectFilled({ x + 3 * scale, center_y - 8 * scale },
        { x + width - 3 * scale, center_y + 8 * scale }, bg_bottom, 1 * scale);
    draw:AddRectFilled({ x + 13 * scale, y + 8 * scale },
        { x + width - 13 * scale, y + 39 * scale }, dark, 1 * scale);

    local outer = {
        { x + 22 * scale, y + 4 * scale },
        { center_x - 10 * scale, y + 4 * scale },
        { center_x, y + 13 * scale },
        { center_x + 10 * scale, y + 4 * scale },
        { x + width - 22 * scale, y + 4 * scale },
        { x + width - 10 * scale, y + 16 * scale },
        { x + width - 10 * scale, center_y - 10 * scale },
        { x + width - 2 * scale, center_y },
        { x + width - 10 * scale, center_y + 10 * scale },
        { x + width - 10 * scale, y + height - 16 * scale },
        { x + width - 22 * scale, y + height - 4 * scale },
        { center_x + 10 * scale, y + height - 4 * scale },
        { center_x, y + height - 13 * scale },
        { center_x - 10 * scale, y + height - 4 * scale },
        { x + 22 * scale, y + height - 4 * scale },
        { x + 10 * scale, y + height - 16 * scale },
        { x + 10 * scale, center_y + 10 * scale },
        { x + 2 * scale, center_y },
        { x + 10 * scale, center_y - 10 * scale },
        { x + 10 * scale, y + 16 * scale },
    };
    draw_line_path(draw, outer, brass_hover, heavy, true);

    -- The inner rail and stepped corner strokes mimic engraved FFXI menu furniture.
    draw:AddRect({ x + 15 * scale, y + 9 * scale },
        { x + width - 15 * scale, y + height - 9 * scale }, brass_dim, 1 * scale, 0, line);
    draw:AddLine({ x + 15 * scale, y + 40 * scale },
        { x + width - 15 * scale, y + 40 * scale }, brass_dim, line);
    draw:AddLine({ x + 24 * scale, y + 43 * scale },
        { x + width - 24 * scale, y + 43 * scale }, accent, line);
    draw_warning_diamond(draw, center_x, y + 8.5 * scale, 4.5 * scale, brass_hover, line);
    draw_warning_diamond(draw, center_x, y + height - 8.5 * scale, 4.5 * scale, brass, line);
    draw_warning_diamond(draw, x + 7 * scale, center_y, 4 * scale, accent, line);
    draw_warning_diamond(draw, x + width - 7 * scale, center_y, 4 * scale, accent, line);

    -- A restrained duration rail adds useful timing while echoing the reference gold bars.
    local rail_left = x + 34 * scale;
    local rail_right = x + width - 34 * scale;
    local rail_y = y + height - 17 * scale;
    draw:AddRectFilled({ rail_left, rail_y }, { rail_right, rail_y + 3 * scale }, brass_dim, 1 * scale);
    draw:AddRectFilled({ rail_left, rail_y },
        { rail_left + (rail_right - rail_left) * math.max(0, math.min(1, progress)), rail_y + 3 * scale }, accent, 1 * scale);
    draw_warning_diamond(draw, rail_left - 4 * scale, rail_y + 1.5 * scale, 3 * scale, brass, line);
    draw_warning_diamond(draw, rail_right + 4 * scale, rail_y + 1.5 * scale, 3 * scale, brass, line);

    return brass, brass_dim, accent;
end

local function resolve_warning_card_position(display, width, height, overlay)
    local margin = math.max(18, math.min(display.x, display.y) * 0.025);
    local x = tonumber(overlay.position_x) or math.floor((display.x - width) / 2);
    local y = tonumber(overlay.position_y) or math.floor(display.y * 0.24);
    local anchor = tostring(overlay.position_anchor or 'custom');

    if (anchor == 'top_left' or anchor == 'middle_left' or anchor == 'bottom_left') then x = margin; end
    if (anchor == 'top_center' or anchor == 'center' or anchor == 'bottom_center' or anchor == 'center_x') then
        x = (display.x - width) / 2;
    end
    if (anchor == 'top_right' or anchor == 'middle_right' or anchor == 'bottom_right') then
        x = display.x - width - margin;
    end
    if (anchor == 'top_left' or anchor == 'top_center' or anchor == 'top_right') then y = margin; end
    if (anchor == 'middle_left' or anchor == 'center' or anchor == 'middle_right' or anchor == 'center_y') then
        y = (display.y - height) / 2;
    end
    if (anchor == 'bottom_left' or anchor == 'bottom_center' or anchor == 'bottom_right') then
        y = display.y - height - margin;
    end

    return math.floor(math.max(0, math.min(display.x - width, x))),
        math.floor(math.max(0, math.min(display.y - height, y)));
end

local function render_warning_card(state, is_critical, previewing)
    ensure_ui_settings();
    if (warn.ui.theme == nil) then reload_ui_theme(); end
    local active_theme = warn.ui.theme;
    local display = imgui.GetIO().DisplaySize;
    local severity = is_critical and 'critical' or tostring(state.severity or 'important'):lower();
    if (severity ~= 'critical' and severity ~= 'danger') then severity = 'important'; end
    local severity_scale = severity == 'critical' and 1.08 or (severity == 'danger' and 1.0 or 0.86);
    local scale = get_ui_scale() * math.max(0.70, math.min(1.40,
        tonumber(warn.settings.overlay.card_scale) or 1.0)) * severity_scale;
    local severity_color = uiTheme.severity_color(active_theme, severity);

    local elapsed = previewing and 1.0 or math.max(0, os.clock() - (tonumber(state.startTime) or os.clock()));
    local entry_alpha = 1.0;
    local slide = 0;
    if (warn.settings.overlay.reduced_motion ~= true and not previewing) then
        entry_alpha = math.max(0, math.min(1, elapsed / 0.18));
        slide = (1.0 - entry_alpha) * (-10 * scale);
    end

    if (severity == 'critical') then draw_critical_edges(display, severity_color, entry_alpha); end

    local title;
    local detail;
    if (is_critical) then
        title, detail = split_first_line(state.text or 'CROWD CONTROL LOST!');
    elseif (previewing) then
        title = 'BILGESTORM';
        detail = 'Preview - mechanic detail or assigned action appears here.';
    else
        title = tostring(state.name or 'WARNING');
        detail = tostring(state.text or '');
        if (detail == title) then detail = ''; end
    end
    title = tostring(title or 'WARNING'):upper();

    local width = math.min(display.x * 0.58, math.max(380 * scale, 560 * scale));
    local detail_lines = 0;
    for _ in (detail .. '\n'):gmatch('(.-)\n') do detail_lines = detail_lines + 1; end
    if (detail == '') then detail_lines = 0; end
    local height = (detail_lines > 0 and (136 + math.max(0, detail_lines - 1) * 18) or 106) * scale;
    local x, y = resolve_warning_card_position(display, width, height, warn.settings.overlay);
    y = y + slide;

    local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoMove);
    if (not previewing) then flags = bit.bor(flags, ImGuiWindowFlags_NoInputs); end
    imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ width, height }, ImGuiCond_Always);

    if (imgui.Begin('##warn_live_card', true, flags)) then
        local win_x, win_y = imgui.GetWindowPos();
        local draw = imgui.GetWindowDrawList();
        local card_opacity = math.max(0.0, math.min(1.0, tonumber(warn.settings.overlay.card_opacity) or 0.86));
        local urgency_pulse = 1.0;
        if (severity == 'danger' and warn.settings.overlay.reduced_motion ~= true) then
            urgency_pulse = 0.72 + 0.28 * math.abs(math.sin(os.clock() * math.pi * 1.10));
        end
        local duration = math.max(0.1, tonumber(state.duration) or tonumber(warn.settings.overlay.duration) or 4.0);
        local progress = previewing and 0.72 or (1.0 - math.min(1, elapsed / duration));
        local brass, brass_dim = draw_ornate_warning_frame(draw, win_x, win_y, width, height, scale,
            active_theme, severity_color, card_opacity, entry_alpha, urgency_pulse, progress);
        local text_color = imgui.GetColorU32(color_with_alpha(active_theme.text, entry_alpha));
        draw_warning_crest(draw, win_x + 20 * scale, win_y + 10 * scale, 25 * scale,
            brass, brass_dim, text_color);

        if (previewing) then
            imgui.SetCursorScreenPos({ win_x, win_y });
            imgui.InvisibleButton('##warn_preview_drag_surface', { width, height });
            if (imgui.IsItemClicked(0)) then
                warn.ui.warning_preview_drag_active = true;
                warn.ui.warning_preview_drag_mouse_x, warn.ui.warning_preview_drag_mouse_y = imgui.GetMousePos();
            end
            if (warn.ui.warning_preview_drag_active and imgui.IsMouseDown(0)) then
                local mouse_x, mouse_y = imgui.GetMousePos();
                if (imgui.IsMouseDragging(0, 3) and warn.ui.warning_preview_drag_mouse_x ~= nil and
                    warn.ui.warning_preview_drag_mouse_y ~= nil) then
                    warn.settings.overlay.position_anchor = 'custom';
                    warn.settings.overlay.position_x = math.floor(math.max(0, math.min(display.x - width,
                        x + mouse_x - warn.ui.warning_preview_drag_mouse_x)));
                    warn.settings.overlay.position_y = math.floor(math.max(0, math.min(display.y - height,
                        y + mouse_y - warn.ui.warning_preview_drag_mouse_y)));
                    warn.ui.next_position_save = os.clock() + 0.35;
                end
                warn.ui.warning_preview_drag_mouse_x = mouse_x;
                warn.ui.warning_preview_drag_mouse_y = mouse_y;
            elseif (warn.ui.warning_preview_drag_active and imgui.IsMouseReleased(0)) then
                warn.ui.warning_preview_drag_active = false;
                warn.ui.warning_preview_drag_mouse_x = nil;
                warn.ui.warning_preview_drag_mouse_y = nil;
            elseif (not imgui.IsMouseDown(0)) then
                warn.ui.warning_preview_drag_active = false;
                warn.ui.warning_preview_drag_mouse_x = nil;
                warn.ui.warning_preview_drag_mouse_y = nil;
            end
        end

        imgui.SetCursorScreenPos({ win_x + 53 * scale, win_y + 14 * scale });
        set_ui_font_scale(0.78 * scale);
        imgui.TextColored(color_with_alpha(severity_color, entry_alpha), severity:upper());
        local prediction = tostring(state.prediction or 'reactive');
        imgui.SetCursorScreenPos({ win_x + width - 168 * scale, win_y + 14 * scale });
        imgui.TextColored(color_with_alpha(active_theme.text_muted, entry_alpha),
            prediction == 'readiness' and 'READINESS ESTIMATE'
                or (prediction == 'scripted' and 'VERIFIED SCRIPT' or 'REACTIVE RECOGNITION'));

        imgui.SetCursorScreenPos({ win_x + 31 * scale, win_y + 51 * scale });
        set_ui_font_scale(1.34 * scale);
        imgui.TextColored(color_with_alpha(active_theme.text, entry_alpha), title);
        if (detail ~= '') then
            imgui.SetCursorScreenPos({ win_x + 34 * scale, win_y + 82 * scale });
            set_ui_font_scale(0.88 * scale);
            imgui.PushTextWrapPos(win_x + width - 34 * scale);
            imgui.TextWrapped(detail);
            imgui.PopTextWrapPos();
        end
        set_ui_font_scale(1.0);

    end
    imgui.End();
end

function render_overlay()
    ensure_ui_settings();
    if (warn.font ~= nil) then warn.font:SetVisible(false); end
    local appearance_open = warn.isGuiOpen[1] and warn.mainTab[1] == 2 and warn.optionsSection[1] == 6;
    if (not appearance_open) then
        warn.ui.warning_preview_visible = false;
        warn.ui.warning_preview_drag_active = false;
    end
    if (warn.active.firing) then
        local duration = warn.active.duration or warn.settings.overlay.duration;
        if ((os.clock() - warn.active.startTime) >= duration) then
            warn.active.firing = false;
        end
    end

    if (not warn.critical.firing and not warn.active.firing and warn.settings.overlay.burst_protection == true) then
        local nextAlert = warn.alertGuard.engine.next(warn.alertGuard.state, os.clock());
        if (nextAlert ~= nil) then activate_warning_payload(nextAlert); end
    end

    if (warn.critical.firing) then
        render_warning_card(warn.critical, true, false);
    elseif (warn.active.firing) then
        render_warning_card(warn.active, false, false);
    elseif (appearance_open and warn.ui.warning_preview_visible == true) then
        render_warning_card({ severity = 'important', prediction = 'reactive', startTime = os.clock() }, false, true);
    end

    if (warn.ui.next_position_save ~= nil and os.clock() >= warn.ui.next_position_save) then
        warn.ui.next_position_save = nil;
        save_settings();
    end
end

local function render_encounter_hud()
    ensure_context_settings();
    ensure_ui_settings();
    if (not warn.settings.context.encounter_hud) then return; end

    local now = os.clock();
    local timerRows = encounterRuntime.timer_rows(warn.encounter, now);
    local showAminon = warn.encounter.aminon.active;
    local showOngo = warn.encounter.ongo ~= nil and warn.encounter.ongo.active;
    local showBumba = warn.encounter.bumba.active;
    local showCircles = warn.encounter.circles.active;
    local circlePulse = showCircles and encounterRuntime.nearest_recent_circle_pulse(
        warn.encounter, get_player_position(), now, 6.0) or nil;
    local doomRows, doomRemaining, doomPending = encounterRuntime.shinryu_doom_rows(warn.encounter, now);
    local showShinryu = warn.encounter.shinryu ~= nil and warn.encounter.shinryu.active;
    local activeProfile = warn.activeEncounter.engine.get_profile(warn.activeEncounter.index, warn.activeEncounter.state);
    local hudCache = warn.ui.encounter_hud_cache;
    local activeKey = activeProfile ~= nil and activeProfile.key or nil;
    if (hudCache.key ~= activeKey or now >= (hudCache.next_refresh or 0)) then
        local activeRules = {};
        local activeCounters, seenCounters = {}, {};
        if (activeProfile ~= nil) then
        for _, rule in ipairs(activeProfile.rules or {}) do
            if (rule.verified == true and is_rule_enabled(rule)) then table.insert(activeRules, rule); end
        end
        local ranks = { critical=1, danger=2, important=3 };
        table.sort(activeRules, function(a, b)
            local ar = ranks[tostring(a.severity or 'important'):lower()] or 4;
            local br = ranks[tostring(b.severity or 'important'):lower()] or 4;
            if (ar ~= br) then return ar < br; end
            return tostring(a.ability or a.actor or a.id) < tostring(b.ability or b.actor or b.id);
        end);
        while (#activeRules > 3) do table.remove(activeRules); end
        for _, rule in ipairs(activeProfile.rules or {}) do
            local counter = get_available_counter(rule);
            if (counter ~= nil) then
                local label = tostring(counter.label or counter.name or 'Available response'):gsub('[!\r\n]+$', '');
                if (not seenCounters[label:lower()]) then
                    seenCounters[label:lower()] = true;
                    table.insert(activeCounters, label);
                    if (#activeCounters >= 2) then break end
                end
            end
        end
        end
        hudCache.key = activeKey;
        hudCache.rules = activeRules;
        hudCache.counters = activeCounters;
        hudCache.next_refresh = now + 0.50;
    end
    local activeRules = hudCache.rules or {};
    local activeCounters = hudCache.counters or {};
    if (#timerRows == 0 and activeProfile == nil and not showAminon and not showOngo and not showBumba and not showCircles and not showShinryu) then return; end

    local shinryuLines = showShinryu and (2 + math.min(#doomRows, 6) + ((doomPending or doomRemaining ~= nil) and 1 or 0)) or 0;
    local activeLines = activeProfile ~= nil and (2 + #activeRules + #activeCounters) or 0;
    local lineCount = activeLines + #timerRows + (showAminon and 2 or 0) + (showOngo and 2 or 0) + (showBumba and 1 or 0) +
        (showCircles and (circlePulse ~= nil and 2 or 1) or 0) + shinryuLines;
    local width = 390 * get_ui_scale();
    local height = (46 + lineCount * 21) * get_ui_scale();
    local ui = warn.settings.ui;
    local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoBringToFrontOnFocus,
        ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoInputs);
    imgui.SetNextWindowPos({ tonumber(ui.encounter_hud_x) or 24, tonumber(ui.encounter_hud_y) or 150 }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ width, height }, ImGuiCond_Always);
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.018, 0.045, 0.11, tonumber(ui.encounter_hud_opacity) or 0.86 });
    imgui.PushStyleColor(ImGuiCol_Border, { 0.78, 0.60, 0.28, 0.95 });
    if (imgui.Begin('##warn_tactical_hud', true, flags)) then
        imgui.TextColored({ 0.96, 0.78, 0.32, 1.0 }, 'WARN  /  CURRENT ENCOUNTER');
        imgui.Separator();
        if (activeProfile ~= nil) then
            local state = warn.activeEncounter.state;
            local badge = state.manual and 'MANUAL' or (state.confidence == 'confirmed' and 'CONFIRMED' or 'NEARBY');
            imgui.TextColored({ 0.96, 0.78, 0.32, 1.0 }, activeProfile.encounter:upper() .. '  [' .. badge .. ']');
            imgui.TextColored({ 0.66, 0.74, 0.86, 1.0 }, activeProfile.content .. ' / ' .. activeProfile.group);
            for _, rule in ipairs(activeRules) do
                local severity = tostring(rule.severity or 'important'):lower();
                local color = severity == 'critical' and { 1.0, 0.35, 0.30, 1.0 } or
                    (severity == 'danger' and { 1.0, 0.72, 0.25, 1.0 } or { 0.55, 0.82, 1.0, 1.0 });
                imgui.TextColored(color, severity:upper() .. '  ' .. tostring(rule.ability or rule.actor or rule.id));
            end
            for _, counter in ipairs(activeCounters) do
                imgui.TextColored({ 0.55, 1.0, 0.60, 1.0 }, 'READY  ' .. counter);
            end
            if (showBumba or showAminon or showOngo or showCircles or showShinryu or #timerRows > 0) then imgui.Separator(); end
        end
        if (showBumba) then
            local element = tostring(warn.encounter.bumba.element or 'unknown'):upper();
            if (element == 'UNKNOWN') then
                imgui.TextColored({ 0.72, 0.78, 0.86, 1.0 }, 'BUMBA  Element: confirm dust-cloud color');
            else
                imgui.TextColored({ 1.0, 0.72, 0.25, 1.0 }, 'BUMBA  ABSORBING ' .. element .. ' - AVOID ' .. element);
            end
        end
        if (showAminon) then
            local dt, age = encounterRuntime.aminon_dt_estimate(warn.encounter, now);
            local objective = warn.encounter.objectives.aminon;
            imgui.TextColored({ 0.72, 0.88, 1.0, 1.0 }, string.format('AMINON  %s MODE - USE %s',
                tostring(warn.encounter.aminon.mode):upper(), tostring(warn.encounter.aminon.response):upper()));
            local status = warn.encounter.aminon.proc_confirmed and 'PROC CONFIRMED  5/5' or
                string.format('Elemental hits %d/5  |  Age %s / possible +%d%% DT', objective.progress or 0, format_seconds(age), dt);
            imgui.TextColored(warn.encounter.aminon.proc_confirmed and { 0.55, 1.0, 0.60, 1.0 } or { 1.0, 0.72, 0.25, 1.0 }, status);
        end
        if (showOngo) then
            local objective = warn.encounter.objectives.ongo;
            imgui.TextColored({ 1.0, 0.50, 0.28, 1.0 }, 'ONGO  FETTERS + SHOCK ~150 HP/TICK');
            local status = warn.encounter.ongo.proc_confirmed and 'BLUE PROC CONFIRMED' or
                string.format('EARTH MAGIC BURSTS  %d/%d%s', objective.progress or 0, objective.required or 2,
                    objective.status == 'awaiting_confirmation' and '  - VERIFY BLUE PROC' or '');
            imgui.TextColored(warn.encounter.ongo.proc_confirmed and { 0.55, 1.0, 0.60, 1.0 } or { 1.0, 0.72, 0.25, 1.0 }, status);
        end
        if (showCircles) then
            local circles = warn.encounter.circles;
            if (circles.reliable) then
                imgui.Text(string.format('DIVERGENCE  Circles %d/8 cleared - boss DT ~-%d%%',
                    circles.cleared or 0, encounterRuntime.circle_damage_reduction(warn.encounter) or 0));
            else
                imgui.TextColored({ 0.72, 0.78, 0.86, 1.0 }, string.format('DIVERGENCE  %d Circles observed - full count uncertain', circles.alive or 0));
            end
            if (circlePulse ~= nil) then
                local color = circlePulse.distance <= 45 and { 1.0, 0.35, 0.30, 1.0 } or { 1.0, 0.72, 0.25, 1.0 };
                imgui.TextColored(color, string.format('RECENT PULSE  %.1f yalms - %s', circlePulse.distance,
                    circlePulse.distance <= 45 and 'MOVE / MITIGATE' or 'OUTSIDE DOCUMENTED 45Y RADIUS'));
            end
        end
        if (showShinryu) then
            local shinryu = warn.encounter.shinryu;
            if (shinryu.wings == 'spread') then
                imgui.TextColored({ 1.0, 0.30, 0.25, 1.0 }, 'SHINRYU  WINGS SPREAD - ABSORPTION STANCE');
            elseif (shinryu.wings == 'down') then
                imgui.TextColored({ 0.55, 1.0, 0.60, 1.0 }, 'SHINRYU  WINGS DOWN - DAMAGE WINDOW');
            else
                imgui.TextColored({ 0.72, 0.78, 0.86, 1.0 }, 'SHINRYU  Wing stance awaiting spell evidence');
            end
            if (shinryu.next_shift_at ~= nil) then
                local shiftRemaining = shinryu.next_shift_at - now;
                imgui.TextColored({ 0.94, 0.88, 0.70, 1.0 }, 'Wing-cycle check  ' ..
                    (shiftRemaining > 0 and format_seconds(shiftRemaining) or 'DUE - VERIFY STATE'));
            else
                imgui.TextColored({ 0.62, 0.66, 0.72, 1.0 }, '3-minute cycle; exact transition timing awaits verified animation evidence.');
            end

            if (doomPending) then
                imgui.TextColored({ 1.0, 0.45, 0.30, 1.0 }, 'SUPERNOVA READIED - WAITING FOR TARGET RESULTS');
            elseif (doomRemaining ~= nil) then
                imgui.TextColored({ 1.0, 0.30, 0.25, 1.0 }, 'DOOM TRIAGE  ' ..
                    (doomRemaining > 0 and format_seconds(doomRemaining) or 'COUNT EXPIRED - VERIFY'));
            end
            for i = 1, math.min(#doomRows, 6) do
                local target = doomRows[i];
                local label = target.status == 'doomed' and 'DOOM CONFIRMED' or
                    (target.status == 'cleared' and 'CLEARED' or 'CHECK DOOM');
                local color = target.status == 'doomed' and { 1.0, 0.25, 0.22, 1.0 } or
                    (target.status == 'cleared' and { 0.55, 1.0, 0.60, 1.0 } or { 1.0, 0.72, 0.25, 1.0 });
                imgui.TextColored(color, tostring(target.name) .. '  ' .. label);
            end
            if (#doomRows > 6) then
                imgui.TextColored({ 0.72, 0.78, 0.86, 1.0 }, string.format('+%d additional alliance targets', #doomRows - 6));
            end
        end
        for _, timer in ipairs(timerRows) do
            local value = timer.remaining > 0 and format_seconds(timer.remaining) or 'DUE / WAITING FOR RESET';
            imgui.TextColored(timer.remaining <= 15 and { 1.0, 0.35, 0.30, 1.0 } or { 0.94, 0.88, 0.70, 1.0 },
                tostring(timer.label) .. '  ' .. value);
        end
    end
    imgui.End();
    imgui.PopStyleColor(2);
end

--------------------------------------------------------------------------------------------------
-- GUI: Warning Abilities tab
--------------------------------------------------------------------------------------------------

function render_abilities_tab(compact)
    local paneHeight = compact and 220 or 330;
    imgui.TextColored({ 0.72, 0.80, 0.90, 1.0 },
        'Advanced fallback: receive a basic alert for a named ability without a curated encounter rule.');
    imgui.InputText('Search Custom Watches', warn.search, 255);

    imgui.BeginGroup();
    imgui.TextColored({ 1.0, 1.0, 1.0, 1.0 }, 'All Abilities');
    imgui.BeginChild('warn_leftpane', { 340, paneHeight }, ImGuiChildFlags_Borders);

    local searchTerm = warn.search[1] ~= nil and warn.search[1]:lower() or '';
    local idx = 1;
    warn.abilities:each(function (v)
        local show = true;
        if (searchTerm ~= '') then
            show = (v[1]:lower():find(searchTerm, 1, true) ~= nil);
        end
        if (show) then
            local prefix = v[2] and '[X] ' or '[ ] ';
            if (imgui.Selectable(prefix .. v[1] .. '##warn_ab_' .. idx, warn.selectedIndex[1] == idx)) then
                warn.selectedIndex[1] = idx;
            end
        end
        idx = idx + 1;
    end);
    imgui.EndChild();
    imgui.EndGroup();

    imgui.SameLine();

    imgui.BeginGroup();
    imgui.TextColored({ 1.0, 1.0, 1.0, 1.0 }, 'Warn?');
    imgui.BeginChild('warn_rightpane', { 250, paneHeight }, ImGuiChildFlags_Borders);
    if (warn.selectedIndex[1] > -1 and warn.abilities[warn.selectedIndex[1]] ~= nil) then
        local entry = warn.abilities[warn.selectedIndex[1]];
        if (imgui.Checkbox('##warn_toggle', { entry[2] })) then
            entry[2] = not entry[2];
            save_ability_settings();
            rebuild_enabled_lookup();
        end
        imgui.TextColored({ 1.0, 1.0, 0.4, 1.0 }, entry[1]);
    else
        imgui.TextColored({ 0.6, 0.6, 0.6, 1.0 }, 'Select an ability from the list.');
    end
    imgui.EndChild();
    imgui.EndGroup();

    imgui.Separator();

    if (imgui.Button('Enable All')) then
        enable_all_abilities();
    end
    imgui.SameLine();
    if (imgui.Button('Disable All')) then
        disable_all_abilities();
    end
    imgui.SameLine();
    if (imgui.Button('Clear Warnings')) then
        clear_warning_list();
    end

    imgui.Separator();
    imgui.TextColored({ 1.0, 1.0, 1.0, 1.0 }, string.format('Currently warning on %d ability/abilities:', count_enabled()));
    imgui.BeginChild('warn_enabled_list', { 0, 100 }, ImGuiChildFlags_Borders);
    warn.abilities:each(function (v)
        if (v[2]) then
            imgui.TextColored({ 0.4, 1.0, 0.4, 1.0 }, v[1]);
        end
    end);
    imgui.EndChild();
end

--------------------------------------------------------------------------------------------------
-- GUI: Appearance tab
--------------------------------------------------------------------------------------------------

function render_appearance_tab()
    ensure_ui_settings();
    local s = warn.settings.overlay;
    local ui = warn.settings.ui;

    local function apply_warning_anchor(anchor)
        local display = imgui.GetIO().DisplaySize;
        local previewScale = get_ui_scale() * math.max(0.70, math.min(1.40, tonumber(s.card_scale) or 1.0)) * 0.86;
        local previewWidth = math.min(display.x * 0.58, math.max(380 * previewScale, 560 * previewScale));
        local previewHeight = 136 * previewScale;
        local currentX, currentY = resolve_warning_card_position(display, previewWidth, previewHeight, s);
        s.position_x = currentX;
        s.position_y = currentY;
        s.position_anchor = anchor;
        s.position_x, s.position_y = resolve_warning_card_position(display, previewWidth, previewHeight, s);
        warn.ui.warning_preview_visible = true;
        save_settings();
    end

    imgui.TextColored({ 1.0, 0.88, 0.35, 1.0 }, 'Vana\'diel Tactical Interface');
    imgui.TextColored({ 0.70, 0.78, 0.88, 1.0 },
        'Warn keeps alert readability separate from decorative effects so neither has to obstruct the fight.');
    imgui.Separator();

    local preset_values = { 'auto', '1440p', '1080p', 'custom' };
    local preset_labels = 'Auto (Display Height)\0001440p Baseline\0001080p Baseline\000Custom\000\000';
    local preset_index = 0;
    for index, value in ipairs(preset_values) do if (ui.scale_preset == value) then preset_index = index - 1; end end
    local preset_selected = { preset_index };
    if (imgui.Combo('Interface Scale##warn_scale_preset', preset_selected, preset_labels)) then
        ui.scale_preset = preset_values[preset_selected[1] + 1] or 'auto';
        warn.guiSizeInitialized = false;
        save_settings();
    end
    if (ui.scale_preset == 'custom') then
        local custom_scale = { tonumber(ui.custom_scale) or 1.0 };
        if (imgui.SliderFloat('Custom Interface Scale', custom_scale, 0.60, 1.75, '%.2f')) then
            ui.custom_scale = custom_scale[1];
            warn.guiSizeInitialized = false;
            save_settings();
        end
    end
    imgui.TextColored({ 0.58, 0.65, 0.74, 1.0 }, string.format('Resolved scale: %.2fx', get_ui_scale()));
        if (imgui.Checkbox('Keep Warn Dashboard Above Other Addons', { ui.always_on_top })) then
        ui.always_on_top = not ui.always_on_top;
        save_settings();
    end
    imgui.TextColored({ 0.58, 0.65, 0.74, 1.0 },
        'Enabled by default. Disable this when you need to interact with another addon over Warn.');
    if (warn.ui.focus_api_available == false) then
        imgui.TextColored({ 0.85, 0.35, 0.35, 1.0 },
            'This Ashita build does not expose the ImGui focus API Warn needs for this option; it will have no effect here.');
    end

    local themes = uiTheme.list(addon.path);
    local theme_index = 0;
    for index, value in ipairs(themes) do if (value == ui.theme) then theme_index = index - 1; end end
    local theme_selected = { theme_index };
    local theme_labels = table.concat(themes, '\000') .. '\000\000';
    if (#themes > 0 and imgui.Combo('Theme##warn_theme', theme_selected, theme_labels)) then
        ui.theme = themes[theme_selected[1] + 1] or 'vana_tactical';
        reload_ui_theme();
        save_settings();
    end
    imgui.SameLine();
    if (imgui.Button('Reload Theme')) then
        uiTextures.clear();
        reload_ui_theme();
    end
    imgui.TextColored({ 0.58, 0.65, 0.74, 1.0 },
        'Community themes can override theme.txt and launcher.png under config/addons/warn/themes/<name>.');

    imgui.Separator();
    imgui.TextColored({ 1.0, 0.88, 0.35, 1.0 }, 'Launcher');
    if (imgui.Checkbox('Show Draggable W Launcher', { ui.launcher_enabled })) then
        ui.launcher_enabled = not ui.launcher_enabled;
        save_settings();
    end
    local launcher_size = { tonumber(ui.launcher_size) or 58 };
    if (imgui.SliderFloat('Launcher Size', launcher_size, 36, 96, '%.0f px')) then
        ui.launcher_size = launcher_size[1];
        save_settings();
    end
    if (imgui.Button('Reset Launcher Position')) then
        ui.launcher_position_x = -1;
        ui.launcher_position_y = -1;
        warn.ui.launcher_position_initialized = false;
        save_settings();
    end
    imgui.TextColored({ 0.58, 0.65, 0.74, 1.0 }, 'Drag the launcher normally to reposition it. Click without dragging to open or close Warn.');

    imgui.Separator();
    imgui.TextColored({ 1.0, 0.88, 0.35, 1.0 }, 'Ornate Live Warning Cards');
    if (imgui.Button(warn.ui.warning_preview_visible and 'Hide Warning Preview' or 'Show Warning Preview')) then
        warn.ui.warning_preview_visible = not warn.ui.warning_preview_visible;
    end
    imgui.SameLine();
    if (imgui.Button('Reset Warning Position')) then
        apply_warning_anchor('top_center');
    end
    imgui.TextColored({ 0.58, 0.65, 0.74, 1.0 },
        'The preview is temporary and closes automatically when you leave Appearance or close Warn.');
    local card_opacity = { tonumber(s.card_opacity) or 0.86 };
    if (imgui.SliderFloat('Warning Card Opacity', card_opacity, 0.0, 1.0, '%.2f')) then
        s.card_opacity = card_opacity[1];
        save_settings();
    end
    imgui.TextColored({ 0.58, 0.65, 0.74, 1.0 },
        'Changes only the message panel. Text and critical edge awareness remain readable.');

    local card_scale = { tonumber(s.card_scale) or 1.0 };
    if (imgui.SliderFloat('Warning Card Scale', card_scale, 0.70, 1.40, '%.2f')) then
        s.card_scale = card_scale[1];
        save_settings();
    end
    if (imgui.Checkbox('Enable Critical Screen-Edge Effect', { s.edge_enabled })) then
        s.edge_enabled = not s.edge_enabled;
        save_settings();
    end
    if (s.edge_enabled) then
        local edge_intensity = { tonumber(s.edge_intensity) or 0.65 };
        if (imgui.SliderFloat('Edge Effect Intensity', edge_intensity, 0.0, 1.0, '%.2f')) then
            s.edge_intensity = edge_intensity[1];
            save_settings();
        end
    end
    if (imgui.Checkbox('Reduced Motion', { s.reduced_motion })) then
        s.reduced_motion = not s.reduced_motion;
        save_settings();
    end
    imgui.TextColored({ 0.58, 0.65, 0.74, 1.0 }, 'Reduced Motion removes entry slides and decorative alert pulsing.');

    local dur = { s.duration };
    if (imgui.SliderFloat('Warning Duration', dur, 1.0, 15.0, '%.1f sec')) then
        s.duration = dur[1];
        save_settings();
    end

    imgui.TextColored({ 1.0, 1.0, 1.0, 1.0 }, 'Warning Position');
    imgui.TextColored({ 0.58, 0.65, 0.74, 1.0 },
        'Choose a screen-aware preset to work around other addons. Dragging or exact coordinates switch back to Custom.');

    if (imgui.Button('Top Left##warn_anchor_tl')) then apply_warning_anchor('top_left'); end
    imgui.SameLine();
    if (imgui.Button('Top Center##warn_anchor_tc')) then apply_warning_anchor('top_center'); end
    imgui.SameLine();
    if (imgui.Button('Top Right##warn_anchor_tr')) then apply_warning_anchor('top_right'); end

    if (imgui.Button('Middle Left##warn_anchor_ml')) then apply_warning_anchor('middle_left'); end
    imgui.SameLine();
    if (imgui.Button('Screen Center##warn_anchor_c')) then apply_warning_anchor('center'); end
    imgui.SameLine();
    if (imgui.Button('Middle Right##warn_anchor_mr')) then apply_warning_anchor('middle_right'); end

    if (imgui.Button('Bottom Left##warn_anchor_bl')) then apply_warning_anchor('bottom_left'); end
    imgui.SameLine();
    if (imgui.Button('Bottom Center##warn_anchor_bc')) then apply_warning_anchor('bottom_center'); end
    imgui.SameLine();
    if (imgui.Button('Bottom Right##warn_anchor_br')) then apply_warning_anchor('bottom_right'); end

    if (imgui.Button('Center Horizontally##warn_anchor_x')) then apply_warning_anchor('center_x'); end
    imgui.SameLine();
    if (imgui.Button('Center Vertically##warn_anchor_y')) then apply_warning_anchor('center_y'); end
    imgui.TextColored({ 0.72, 0.80, 0.90, 1.0 }, 'Current layout: ' .. tostring(s.position_anchor or 'custom'):gsub('_', ' '));

    local pos = { math.floor(s.position_x), math.floor(s.position_y) };
    if (imgui.InputInt2('X / Y##warn_position', pos)) then
        s.position_anchor = 'custom';
        s.position_x = pos[1];
        s.position_y = pos[2];
        warn.font.position_x = pos[1];
        warn.font.position_y = pos[2];
        save_settings();
    end

    imgui.Separator();
    imgui.TextColored({ 1.0, 0.88, 0.35, 1.0 }, 'Live Tactical HUD');
    local hudOpacity = { tonumber(ui.encounter_hud_opacity) or 0.86 };
    if (imgui.SliderFloat('Tactical HUD Opacity', hudOpacity, 0.20, 1.0, '%.2f')) then
        ui.encounter_hud_opacity = hudOpacity[1];
        save_settings();
    end
    local hudPosition = { math.floor(tonumber(ui.encounter_hud_x) or 24), math.floor(tonumber(ui.encounter_hud_y) or 150) };
    if (imgui.InputInt2('HUD X / Y##warn_hud_position', hudPosition)) then
        ui.encounter_hud_x = hudPosition[1];
        ui.encounter_hud_y = hudPosition[2];
        save_settings();
    end
    imgui.TextColored({ 0.58, 0.65, 0.74, 1.0 },
        'The compact HUD appears only while a verified timer or supported encounter state is active.');

    imgui.Separator();
    imgui.TextColored({ 1.0, 0.88, 0.35, 1.0 }, 'Controller Navigation');
    if (imgui.Checkbox('Enable Controller Navigation', { ui.controller_enabled })) then
        ui.controller_enabled = not ui.controller_enabled;
        save_settings();
    end
    local controller_values = { 'xinput', 'playstation', 'switch' };
    local controller_labels = 'Xbox / XInput\000PlayStation / DirectInput\000Switch Pro / DirectInput\000\000';
    local controller_index = 0;
    for index, value in ipairs(controller_values) do if (ui.controller_layout == value) then controller_index = index - 1; end end
    local controller_selected = { controller_index };
    if (imgui.Combo('Controller Layout', controller_selected, controller_labels)) then
        ui.controller_layout = controller_values[controller_selected[1] + 1] or 'xinput';
        save_settings();
    end
    imgui.TextColored({ 0.58, 0.65, 0.74, 1.0 },
        'Shoulders switch Encounters/Options. D-pad changes the active browser or option selection. Back closes Warn.');

    imgui.Separator();
    if (imgui.Button('Test Important')) then
        warn.ui.warning_preview_visible = false;
        warn.active.name = 'BILGESTORM'; warn.active.text = 'Informational mechanic or useful state change.';
        warn.active.severity = 'important'; warn.active.prediction = 'reactive'; warn.active.duration = s.duration;
        warn.active.startTime = os.clock(); warn.active.firing = true;
    end
    imgui.SameLine();
    if (imgui.Button('Test Danger')) then
        warn.ui.warning_preview_visible = false;
        warn.active.name = 'GATE OF TARTARUS'; warn.active.text = 'Meaningful damage or positioning risk.';
        warn.active.severity = 'danger'; warn.active.prediction = 'reactive'; warn.active.duration = s.duration;
        warn.active.startTime = os.clock(); warn.active.firing = true;
    end
    imgui.SameLine();
    if (imgui.Button('Test Critical')) then
        warn.ui.warning_preview_visible = false;
        warn.active.name = 'ZANTETSUKEN'; warn.active.text = 'Lethal area attack.';
        warn.active.severity = 'critical'; warn.active.prediction = 'reactive'; warn.active.duration = s.duration;
        warn.active.startTime = os.clock(); warn.active.firing = true;
    end
end

--------------------------------------------------------------------------------------------------
-- GUI: Context tab
--------------------------------------------------------------------------------------------------

local guiOps = {};

function guiOps.get_rule_group(rule)
    if (rule.group ~= nil and tostring(rule.group) ~= '') then return tostring(rule.group); end
    local encounter = tostring(rule.encounter or '');
    for _, entry in ipairs(warn.rules.catalog or {}) do
        if (entry.content == rule.content and entry.encounter == encounter) then return tostring(entry.group or 'General'); end
    end
    if (encounter:find('Volume 1', 1, true)) then return 'Volume 1'; end
    if (encounter:find('Volume 2', 1, true)) then return 'Volume 2'; end
    return 'General';
end

guiOps.encounterSeverityRank = { critical=1, danger=2, important=3 };

function guiOps.get_active_profile_rules(limit)
    local rows = {};
    for _, rule in ipairs(warn.activeEncounter.engine.rules_for_active(
        warn.activeEncounter.index, warn.activeEncounter.state)) do
        if (rule.verified == true and is_rule_enabled(rule)) then table.insert(rows, rule); end
    end
    table.sort(rows, function(a, b)
        local ar = guiOps.encounterSeverityRank[tostring(a.severity or 'important'):lower()] or 4;
        local br = guiOps.encounterSeverityRank[tostring(b.severity or 'important'):lower()] or 4;
        if (ar ~= br) then return ar < br; end
        return tostring(a.ability or a.actor or a.id):lower() < tostring(b.ability or b.actor or b.id):lower();
    end);
    if (limit ~= nil) then while (#rows > limit) do table.remove(rows); end end
    return rows;
end

function guiOps.first_message_line(rule)
    local message = tostring(rule.message or rule.loss_message or rule.ability or rule.actor or 'Verified mechanic');
    return message:match('([^\r\n]+)') or message;
end

function guiOps.get_active_counter_labels(limit)
    local labels, seen = {}, {};
    for _, rule in ipairs(guiOps.get_active_profile_rules()) do
        local counter = get_available_counter(rule);
        if (counter ~= nil) then
            local label = tostring(counter.label or counter.name or 'Available response'):gsub('[!\r\n]+$', '');
            local key = label:lower();
            if (not seen[key]) then
                seen[key] = true;
                table.insert(labels, label);
                if (#labels >= (tonumber(limit) or 3)) then break end
            end
        end
    end
    return labels;
end

function guiOps.get_encounter_categories()
    return encounterBrowser.build_categories(warn.rules.catalog or {}, get_all_context_rules(), guiOps.get_rule_group);
end

function guiOps.text_colored_wrapped(color, value)
    imgui.PushStyleColor(ImGuiCol_Text, color);
    imgui.TextWrapped(tostring(value or ''));
    imgui.PopStyleColor();
end

function guiOps.measure_text_width(value)
    if (type(imgui.CalcTextSize) == 'function') then
        local ok, measured = pcall(imgui.CalcTextSize, tostring(value or ''));
        if (ok and measured ~= nil) then
            local indexedOk, indexedWidth = pcall(function () return tonumber(measured[1]); end);
            if (indexedOk and indexedWidth ~= nil) then return indexedWidth; end
            local namedOk, namedWidth = pcall(function () return tonumber(measured.x); end);
            if (namedOk and namedWidth ~= nil) then return namedWidth; end
        end
    end
    return #tostring(value or '') * 8 * get_ui_scale();
end

function guiOps.centered_text_colored(color, value)
    local windowX = imgui.GetWindowPos();
    local windowWidth = imgui.GetWindowSize();
    local cursorX, cursorY = imgui.GetCursorScreenPos();
    local width = guiOps.measure_text_width(value);
    imgui.SetCursorScreenPos({ windowX + math.max(0, (windowWidth - width) * 0.5), cursorY });
    imgui.TextColored(color, tostring(value or ''));
end

function guiOps.render_current_encounter_panel()
    local scale = get_ui_scale();
    local state = warn.activeEncounter.state;
    local profile = warn.activeEncounter.engine.get_profile(warn.activeEncounter.index, state);
    local manualOpen = warn.manualEncounterOpen[1] == true;
    local profileRuleCount = profile ~= nil and #guiOps.get_active_profile_rules(4) or 0;
    local profileCounterCount = profile ~= nil and #guiOps.get_active_counter_labels(3) or 0;
    local profileHeight = 205 + (profileRuleCount * 22) + (profileCounterCount > 0 and 22 or 0);
    local panelHeight = profile ~= nil and profileHeight or 170;
    if (#(state.candidates or {}) > 0 and profile == nil) then panelHeight = 215; end
    if (manualOpen) then panelHeight = panelHeight + 175; end

    imgui.BeginChild('warn_current_encounter', { 0, panelHeight }, ImGuiChildFlags_Borders);
    local panelX, panelY = imgui.GetWindowPos();
    local panelWidth, panelChildHeight = imgui.GetWindowSize();
    guiOps.centered_text_colored({ 1.0, 0.88, 0.35, 1.0 }, 'Current Encounter');

    if (profile ~= nil) then
        local confidence = state.manual and 'MANUAL' or
            (state.confidence == 'confirmed' and 'AUTO / CONFIRMED' or 'AUTO / NEARBY');
        guiOps.centered_text_colored({ 0.96, 0.78, 0.32, 1.0 }, profile.encounter);
        guiOps.centered_text_colored(state.confidence == 'confirmed' and { 0.55, 1.0, 0.60, 1.0 }
            or { 0.72, 0.82, 0.94, 1.0 }, confidence);
        guiOps.text_colored_wrapped({ 0.66, 0.74, 0.86, 1.0 }, profile.content .. ' / ' .. profile.group ..
            (state.actor ~= nil and ('   Evidence: ' .. tostring(state.actor)) or ''));

        local rules = guiOps.get_active_profile_rules(4);
        if (#rules == 0) then
            imgui.TextColored({ 0.72, 0.72, 0.72, 1.0 }, 'Indexed only - no verified automatic alerts.');
        else
            for _, rule in ipairs(rules) do
                local severity = tostring(rule.severity or 'important'):lower();
                local color = severity == 'critical' and { 1.0, 0.38, 0.32, 1.0 } or
                    (severity == 'danger' and { 1.0, 0.72, 0.25, 1.0 } or { 0.55, 0.82, 1.0, 1.0 });
                imgui.TextColored(color, '[' .. severity:upper() .. '] ' .. tostring(rule.ability or rule.actor or rule.id));
                imgui.SameLine();
                imgui.TextColored({ 0.78, 0.82, 0.88, 1.0 }, ' - ' .. guiOps.first_message_line(rule));
            end
        end

        local counters = guiOps.get_active_counter_labels(3);
        if (#counters > 0) then
            imgui.TextColored({ 0.58, 0.92, 0.66, 1.0 }, 'Your available responses: ' .. table.concat(counters, '  /  '));
        end
        if (imgui.Button('Focus in Browser##warn_encounter_focus')) then
            warn.encounterContent = profile.content;
            warn.encounterGroup = profile.group;
            local rulesForProfile = guiOps.get_active_profile_rules(1);
            warn.selectedRuleId = rulesForProfile[1] ~= nil and rulesForProfile[1].id or nil;
        end
        imgui.SameLine();
        if (imgui.Button('Clear##warn_encounter_clear')) then
            warn.activeEncounter.engine.clear(state, 'user cleared', os.clock());
            warn.encounter = encounterRuntime.new_state();
        end
    elseif (#(state.candidates or {}) > 0) then
        guiOps.centered_text_colored({ 1.0, 0.72, 0.25, 1.0 },
            'Multiple verified encounters match the current evidence.');
        guiOps.text_colored_wrapped({ 0.66, 0.74, 0.86, 1.0 }, 'Warn will not guess. Choose the encounter manually or wait for a unique action.');
        for index = 1, math.min(#state.candidates, 4) do
            local candidate = warn.activeEncounter.index.profiles[state.candidates[index]];
            if (candidate ~= nil and imgui.Button(candidate.encounter .. '##warn_candidate_' .. index)) then
                warn.activeEncounter.engine.activate_manual(warn.activeEncounter.index, state, candidate.key, os.clock());
                warn.encounter = encounterRuntime.new_state();
            end
            if (index < math.min(#state.candidates, 4)) then imgui.SameLine(); end
        end
    else
        guiOps.centered_text_colored({ 0.72, 0.82, 0.94, 1.0 }, 'No active encounter detected.');
        guiOps.text_colored_wrapped({ 0.62, 0.68, 0.76, 1.0 },
            'Warn activates from a verified boss entity or action. Unknown abilities continue into Learning without producing alerts.');
    end

    if (manualOpen) then
        if (type(imgui.PushItemWidth) == 'function') then imgui.PushItemWidth(-1); end
        imgui.InputText('##warn_manual_encounter_search', warn.manualEncounterSearch, 255);
        if (type(imgui.PopItemWidth) == 'function') then imgui.PopItemWidth(); end
        imgui.BeginChild('warn_manual_encounter_results', { 0, 125 }, ImGuiChildFlags_Borders);
        local term = warn.manualEncounterSearch[1] or '';
        for _, candidate in ipairs(warn.activeEncounter.engine.search(warn.activeEncounter.index, term, 15)) do
            local verifiedCount = #(candidate.rules or {});
            local label = string.format('%s  /  %s  /  %s  [%d verified]',
                candidate.content, candidate.group, candidate.encounter, verifiedCount);
            if (imgui.Selectable(label .. '##warn_manual_' .. candidate.key, state.active_key == candidate.key)) then
                warn.activeEncounter.engine.activate_manual(warn.activeEncounter.index, state, candidate.key, os.clock());
                warn.encounter = encounterRuntime.new_state();
                warn.manualEncounterOpen[1] = false;
            end
        end
        imgui.EndChild();
    end

    local actionCursorX, actionCursorY = imgui.GetCursorScreenPos();
    local actionWidth = 292 * scale;
    local actionX = panelX + math.max(12 * scale, panelWidth - actionWidth - (12 * scale));
    local actionY = math.max(actionCursorY + (8 * scale), panelY + panelChildHeight - (43 * scale));
    imgui.SetCursorScreenPos({ actionX, actionY });
    if (imgui.Checkbox('Auto Detect##warn_encounter_auto', { warn.settings.context.encounter_detection })) then
        warn.settings.context.encounter_detection = not warn.settings.context.encounter_detection;
        if (not warn.settings.context.encounter_detection and not state.manual) then
            warn.activeEncounter.engine.clear(state, 'automatic detection disabled', os.clock());
            warn.encounter = encounterRuntime.new_state();
        end
        save_settings();
    end
    imgui.SameLine();
    if (imgui.Button((manualOpen and 'Hide Manual Selection' or 'Choose Manually') ..
        '##warn_manual_toggle', { 154 * scale, 0 })) then
        warn.manualEncounterOpen[1] = not manualOpen;
    end
    imgui.EndChild();
end

function guiOps.get_available_content_width(default_width)
    if (type(imgui.GetContentRegionAvail) == 'function') then
        local ok, size = pcall(imgui.GetContentRegionAvail);
        if (ok and size ~= nil) then
            -- Ashita builds expose ImGui vectors through different wrappers. SugarMath's
            -- numeric vector rejects unknown named fields instead of returning nil, so every
            -- access must be isolated rather than using `size.x or size[1]`.
            return encounterBrowser.vector_width(size, default_width);
        end
    end
    return tonumber(default_width) or 800;
end

function guiOps.render_rule_detail(selectedRule)
    if (selectedRule == nil) then
        imgui.TextColored({ 0.62, 0.62, 0.62, 1.0 }, 'Select an encounter alert to review it.');
        return;
    end

    guiOps.text_colored_wrapped({ 1.0, 0.90, 0.42, 1.0 }, get_rule_display_name(selectedRule));
    guiOps.text_colored_wrapped({ 0.72, 0.78, 0.86, 1.0 },
        tostring(selectedRule.content or 'Other') .. ' / ' .. tostring(selectedRule.encounter or selectedRule.actor or 'General'));

    local severity = tostring(selectedRule.severity or 'important');
    local prediction = warn.mechanics and warn.mechanics.prediction_labels[selectedRule.prediction] or selectedRule.prediction or 'Reactive';
    local shape = warn.mechanics and warn.mechanics.target_shape_labels[selectedRule.target_shape] or selectedRule.target_shape or 'Unspecified';
    local severityColor = severity == 'critical' and { 1.0, 0.35, 0.30, 1.0 }
        or (severity == 'danger' and { 1.0, 0.72, 0.25, 1.0 } or { 0.55, 0.82, 1.0, 1.0 });
    imgui.TextColored(severityColor, 'Severity: ' .. severity:upper());
    imgui.TextColored({ 0.62, 0.82, 1.0, 1.0 }, 'Prediction: ' .. tostring(prediction));
    imgui.SameLine();
    imgui.TextColored({ 0.72, 0.88, 0.72, 1.0 }, '  Target: ' .. tostring(shape));

    local enabled = is_rule_enabled(selectedRule);
    if (imgui.Checkbox('Enable This Alert##warn_rule_enabled', { enabled })) then set_rule_enabled(selectedRule, not enabled); end

    local override = get_rule_override(selectedRule, false);
    local storedSound = (override ~= nil and override.sound ~= nil) and override.sound or '__default__';
    local comboParts = { 'Default (' .. tostring(selectedRule.sound or 'Global Sound') .. ')' };
    local comboValues = { '__default__' };
    local soundIndex = 0;
    for i = 1, #warn.soundFiles do
        local filename = warn.soundFiles[i];
        local displayName = filename == 'None' and filename or filename:gsub('%.wav$', ''):gsub('%.WAV$', '');
        table.insert(comboParts, displayName);
        table.insert(comboValues, filename);
        if (storedSound ~= '__default__' and filename:lower() == tostring(storedSound):lower()) then soundIndex = #comboValues - 1; end
    end
    local selected = { soundIndex };
    if (imgui.Combo('Alert Sound##warn_rule_sound_combo', selected, table.concat(comboParts, '\0') .. '\0\0')) then
        set_rule_sound_override(selectedRule, comboValues[selected[1] + 1] or '__default__');
    end

    if (imgui.Button('Test Alert')) then trigger_context_rule(selectedRule, selectedRule.ability or selectedRule.actor or selectedRule.id); end
    imgui.SameLine();
    if (imgui.Button('Reset Alert')) then reset_rule_override(selectedRule); end
    if (selectedRule.message ~= nil) then
        guiOps.text_colored_wrapped({ 0.65, 1.0, 0.65, 1.0 }, 'Message: ' .. tostring(selectedRule.message):gsub('\n', ' / '));
    end
    guiOps.text_colored_wrapped({ 0.55, 0.58, 0.64, 1.0 }, 'Rule ID: ' .. tostring(selectedRule.id));
end

function guiOps.render_live_encounter_tools()
    local content = warn.encounterContent;
    local showBumba = content == 'Odyssey' or warn.encounter.bumba.active;
    local showOngo = content == 'Odyssey' or (warn.encounter.ongo ~= nil and warn.encounter.ongo.active);
    local showAminon = content == 'Sortie' or warn.encounter.aminon.active;
    local showCircles = content == 'Dynamis - Divergence' or warn.encounter.circles.active;
    local now = os.clock();

    imgui.TextColored({ 1.0, 0.88, 0.35, 1.0 }, 'Live Encounter Tools');
    if (not showBumba and not showOngo and not showAminon and not showCircles) then
        guiOps.text_colored_wrapped({ 0.62, 0.66, 0.72, 1.0 },
            'Select Odyssey, Sortie, or Dynamis - Divergence to prepare its live tactical panel.');
    end

    if (showOngo) then
        imgui.Separator();
        imgui.TextColored({ 0.72, 0.88, 1.0, 1.0 }, 'Ongo - Fetter Proc Objective');
        if (warn.encounter.ongo.active) then
            local objective = warn.encounter.objectives.ongo;
            imgui.Text(string.format('Cycle %d   |   Earth Magic Bursts %d / %d',
                warn.encounter.ongo.cycle or 1, objective.progress or 0, objective.required or 2));
            if (objective.status == 'awaiting_confirmation') then
                imgui.TextColored({ 1.0, 0.72, 0.25, 1.0 }, 'Expected burst count reached - verify the blue proc before clearing the hazard.');
            elseif (warn.encounter.ongo.proc_confirmed) then
                imgui.TextColored({ 0.55, 1.0, 0.60, 1.0 }, 'Blue proc confirmed - fetter / Shock objective complete.');
            else
                imgui.TextColored({ 1.0, 0.45, 0.30, 1.0 }, 'Fetters active; Shock is approximately 150 HP per tick.');
            end
            if (imgui.Button('Confirm Blue Proc##warn_ongo_proc')) then encounterRuntime.mark_ongo_proc(warn.encounter, now); end
            imgui.SameLine();
            if (imgui.Button('Clear Ongo State##warn_ongo_clear')) then
                local fresh = encounterRuntime.new_state();
                warn.encounter.ongo = fresh.ongo;
                warn.encounter.objectives.ongo = fresh.objectives.ongo;
            end
        else
            imgui.TextColored({ 0.62, 0.66, 0.72, 1.0 }, 'Waiting for Ongo to use Crashing Thunder.');
        end
        guiOps.text_colored_wrapped({ 0.62, 0.66, 0.72, 1.0 },
            'Earth Magic Bursts are counted from completed action packets. Warn still asks for blue-proc confirmation so a burst count is never mistaken for proof that the fetters cleared.');
    end

    if (showBumba) then
        imgui.Separator();
        imgui.TextColored({ 0.72, 0.88, 1.0, 1.0 }, 'Bumba - Element and Fetter Mode');
        local elementIndex = 0;
        local elementLabels = {};
        for index, row in ipairs(encounterRuntime.bumba_elements) do
            table.insert(elementLabels, row.label);
            if row.id == warn.encounter.bumba.element then elementIndex = index - 1; end
        end
        local selectedElement = { elementIndex };
        if (imgui.Combo('Absorbed Element##warn_bumba_element', selectedElement, table.concat(elementLabels, '\0') .. '\0\0')) then
            local row = encounterRuntime.bumba_elements[selectedElement[1] + 1] or encounterRuntime.bumba_elements[1];
            encounterRuntime.set_bumba_element(warn.encounter, row.id, now);
            if (row.id ~= 'unknown') then
                encounterRuntime.schedule_timer(warn.encounter, {
                    id='bumba_element_shift', label='BUMBA ELEMENT CHECK', interval=60, prewarn=5,
                    severity='danger', certainty='verified-cadence/manual-color',
                    prewarn_message='BUMBA ELEMENT MAY SHIFT IN 5 SECONDS!\nWATCH THE DUST-CLOUD COLOR',
                    due_message='BUMBA ELEMENT MAY SHIFT NOW!\nVERIFY THE DUST-CLOUD COLOR',
                }, now);
                trigger_context_rule({ id='__bumba_element', verified=true, severity='danger', prediction='reactive', sound='warning.wav' },
                    'BUMBA ELEMENT', 'ABSORBING ' .. row.label:upper() .. '!\nAVOID ' .. row.label:upper() .. ' DAMAGE AND SKILLCHAINS');
            end
        end

        local vengeanceIndex = 2;
        local vengeanceLabels = {};
        for index, row in ipairs(encounterRuntime.bumba_vengeance) do
            table.insert(vengeanceLabels, row.label);
            if row.id == warn.settings.context.bumba_vengeance then vengeanceIndex = index - 1; end
        end
        local selectedVengeance = { vengeanceIndex };
        if (imgui.Combo('Vengeance##warn_bumba_vengeance', selectedVengeance, table.concat(vengeanceLabels, '\0') .. '\0\0')) then
            local row = encounterRuntime.bumba_vengeance[selectedVengeance[1] + 1] or encounterRuntime.bumba_vengeance[3];
            warn.settings.context.bumba_vengeance = row.id;
            warn.encounter.bumba.vengeance = row.id;
            save_settings();
        end
        if (imgui.Button('Start / Reset Fetter Timer##warn_bumba_start')) then
            encounterRuntime.start_bumba(warn.encounter, warn.settings.context.bumba_vengeance, now);
        end
        imgui.SameLine();
        if (imgui.Button('Clear Bumba State##warn_bumba_clear')) then
            warn.encounter.bumba = encounterRuntime.new_state().bumba;
            warn.encounter.timers.bumba_fetters = nil;
            warn.encounter.timers.bumba_element_shift = nil;
        end
        guiOps.text_colored_wrapped({ 0.62, 0.66, 0.72, 1.0 },
            'Color remains manual until a stable packet signature is verified. The timer starts automatically on Bumba\'s first observed action or from the button above.');

        if (warn.settings.context.encounter_diagnostics) then
            imgui.TextColored({ 0.84, 0.70, 0.38, 1.0 }, 'Recent unique Bumba packet signatures');
            if (#warn.encounter.diagnostics.bumba_packets == 0) then
                imgui.TextColored({ 0.60, 0.62, 0.68, 1.0 }, 'No Bumba packets captured this session.');
            else
                for _, packet in ipairs(warn.encounter.diagnostics.bumba_packets) do
                    imgui.Text(tostring(packet.signature));
                end
            end
        end
    end

    if (showAminon) then
        imgui.Separator();
        imgui.TextColored({ 0.72, 0.88, 1.0, 1.0 }, 'Aminon - Elemental Response');
        if (warn.encounter.aminon.active) then
            local dt, age = encounterRuntime.aminon_dt_estimate(warn.encounter, now);
            local objective = warn.encounter.objectives.aminon;
            imgui.Text(string.format('Mode: %s   Response: %s   Hits: %d / 5   Age: %s',
                tostring(warn.encounter.aminon.mode):upper(), tostring(warn.encounter.aminon.response):upper(),
                objective.progress or 0, format_seconds(age)));
            if (warn.encounter.aminon.proc_confirmed) then
                imgui.TextColored({ 0.55, 1.0, 0.60, 1.0 }, 'Proc confirmed manually - current-mode DT growth stopped.');
            else
                imgui.TextColored({ 1.0, 0.72, 0.25, 1.0 }, string.format('Current mode may have added approximately %d%% DT.', dt));
            end
            if (imgui.Button('Mark Proc Confirmed##warn_aminon_proc')) then encounterRuntime.mark_aminon_proc(warn.encounter, now); end
            imgui.SameLine();
            if (imgui.Button('Clear Aminon State##warn_aminon_clear')) then warn.encounter.aminon = encounterRuntime.new_state().aminon; end
        else
            imgui.TextColored({ 0.62, 0.66, 0.72, 1.0 }, 'Waiting for an Aminon elemental TP move.');
        end
        guiOps.text_colored_wrapped({ 0.62, 0.66, 0.72, 1.0 },
            'Completed spell packets track the five consecutive matching elemental hits. A damaging wrong-element spell resets the displayed sequence.');
    end

    if (showCircles) then
        imgui.Separator();
        imgui.TextColored({ 0.72, 0.88, 1.0, 1.0 }, 'Divergence - Elemental Circles');
        local circles = warn.encounter.circles;
        if (circles.reliable) then
            local dt = encounterRuntime.circle_damage_reduction(warn.encounter);
            imgui.Text(string.format('%d / 8 cleared   |   %d alive   |   boss DT approximately -%d%%',
                circles.cleared or 0, circles.alive or 0, dt or 0));
        elseif (circles.active) then
            imgui.Text(string.format('%d Circle entities currently observed; full-zone count is not yet certain.', circles.alive or 0));
        else
            imgui.TextColored({ 0.62, 0.66, 0.72, 1.0 }, 'Waiting for Wave 3 Elemental Circles.');
        end
        local pulse = encounterRuntime.nearest_recent_circle_pulse(warn.encounter, get_player_position(), now, 6.0);
        if (pulse ~= nil) then
            imgui.TextColored(pulse.distance <= 45 and { 1.0, 0.35, 0.30, 1.0 } or { 1.0, 0.72, 0.25, 1.0 },
                string.format('Recent observed pulse: %.1f yalms away.', pulse.distance));
        end
        guiOps.text_colored_wrapped({ 0.62, 0.66, 0.72, 1.0 },
            'Proximity appears only after Warn observes an actual Circle pulse. Element identities remain unresolved because every object shares the same name.');
    end

    local timerRows = encounterRuntime.timer_rows(warn.encounter, now);
    if (#timerRows > 0) then
        imgui.Separator();
        imgui.TextColored({ 0.84, 0.70, 0.38, 1.0 }, 'Verified Timers');
        for _, timer in ipairs(timerRows) do
            local value = timer.remaining > 0 and format_seconds(timer.remaining) or 'DUE - awaiting observed reset';
            imgui.Text(tostring(timer.label) .. ': ' .. value);
        end
    end
end

function render_context_tab()
    ensure_context_settings();
    ensure_rule_settings();
    ensure_ui_settings();
    local uiSettings = warn.settings.ui;
    local scale = get_ui_scale();
    local scrollGutter = math.max(42, 56 * scale);
    imgui.BeginChild('warn_encounters_scroll', { 0, 0 }, 0);
    guiOps.centered_text_colored({ 1.0, 0.88, 0.35, 1.0 }, 'Encounter Intelligence');
    guiOps.centered_text_colored({ 0.70, 0.78, 0.88, 1.0 },
        'Browse verified mechanics. Unknown observations enter Learning and never alert unless explicitly');
    guiOps.centered_text_colored({ 0.70, 0.78, 0.88, 1.0 }, 'watched.');
    guiOps.render_current_encounter_panel();
    imgui.Spacing();
    imgui.Spacing();

    local categories = guiOps.get_encounter_categories();
    local allRules = get_all_context_rules();

    local availableWidth = guiOps.get_available_content_width(900);
    local categoryWidth = math.max(220, math.min(340, availableWidth * 0.29));
    imgui.BeginChild('warn_encounter_browser_shell', { -scrollGutter, 410 }, ImGuiChildFlags_Borders);
    imgui.BeginChild('warn_encounter_categories', { categoryWidth, 0 }, ImGuiChildFlags_Borders);
    if (imgui.Selectable('All Encounters', warn.encounterContent == nil)) then
        warn.encounterContent = nil; warn.encounterGroup = nil;
    end
    for _, category in ipairs(categories) do
        imgui.Separator();
        local collapsed = uiSettings.encounter_collapsed[category.content] == true;
        local categoryLabel = string.format('%s %s  [%d]', collapsed and '[+]' or '[-]', category.content, category.rule_count or 0);
        if (imgui.Selectable(categoryLabel .. '##content_' .. category.content, false)) then
            uiSettings.encounter_collapsed[category.content] = not collapsed;
            save_settings();
            collapsed = not collapsed;
        end
        if (not collapsed) then
            local contentSelected = warn.encounterContent == category.content and warn.encounterGroup == nil;
            if (imgui.Selectable('   All alerts  (' .. tostring(category.rule_count or 0) .. ')##all_' .. category.content, contentSelected)) then
                warn.encounterContent = category.content; warn.encounterGroup = nil;
            end
            for _, group in ipairs(category.groups) do
                if (encounterBrowser.group_is_visible(group, uiSettings.show_indexed_only)) then
                    local selectedGroup = warn.encounterContent == category.content and warn.encounterGroup == group.name;
                    if (imgui.Selectable('   ' .. encounterBrowser.group_label(group) .. '##category_' .. category.content .. '_' .. group.name, selectedGroup)) then
                        warn.encounterContent = category.content; warn.encounterGroup = group.name;
                    end
                end
            end
        end
    end
    imgui.EndChild();
    imgui.SameLine();
    imgui.SetCursorPosX(imgui.GetCursorPosX() + (34 * scale));

    imgui.BeginChild('warn_encounter_browser', { -scrollGutter, 0 }, ImGuiChildFlags_Borders);
    local browserX, browserY = imgui.GetWindowPos();
    local browserWidth, browserHeight = imgui.GetWindowSize();
    local searchTerm = warn.ruleSearch[1] ~= nil and warn.ruleSearch[1]:lower() or '';
    local visibleRules = {};
    for _, rule in ipairs(allRules) do
        local content = tostring(rule.content or 'Other');
        local group = guiOps.get_rule_group(rule);
        local encounter = tostring(rule.encounter or rule.actor or 'General');
        local haystack = (tostring(rule.id or '') .. ' ' .. content .. ' ' .. group .. ' ' .. encounter .. ' ' .. get_rule_display_name(rule) .. ' ' .. tostring(rule.message or '')):lower();
        local categoryMatch = (warn.encounterContent == nil or content == warn.encounterContent)
            and (warn.encounterGroup == nil or group == warn.encounterGroup);
        if (rule.verified == true and categoryMatch and (searchTerm == '' or haystack:find(searchTerm, 1, true) ~= nil)) then
            table.insert(visibleRules, rule);
        end
    end

    imgui.BeginChild('warn_encounter_rule_list', { -scrollGutter, 150 }, ImGuiChildFlags_Borders);
    for _, rule in ipairs(visibleRules) do
        local enabledPrefix = is_rule_enabled(rule) and '[X] ' or '[ ] ';
        local typePrefix = rule.__rule_type == 'state' and '[STATE] ' or '';
        if (imgui.Selectable(enabledPrefix .. typePrefix .. get_rule_display_name(rule) .. '##rule_' .. tostring(rule.id), warn.selectedRuleId == rule.id)) then
            warn.selectedRuleId = rule.id;
        end
    end
    if (#visibleRules == 0) then
        local selectedGroup = encounterBrowser.find_group(categories, warn.encounterContent, warn.encounterGroup);
        guiOps.text_colored_wrapped({ 0.62, 0.66, 0.72, 1.0 },
            encounterBrowser.empty_message(warn.encounterContent, warn.encounterGroup, searchTerm, selectedGroup));
    end
    imgui.EndChild();

    local selectedRule = find_context_rule_by_id(warn.selectedRuleId);
    local selectedVisible = false;
    for _, rule in ipairs(visibleRules) do
        if (selectedRule == rule) then
            selectedVisible = true;
            break
        end
    end
    if (not selectedVisible) then selectedRule = visibleRules[1]; warn.selectedRuleId = selectedRule and selectedRule.id or nil; end
    guiOps.render_rule_detail(selectedRule);

    local footerCursorX, footerCursorY = imgui.GetCursorScreenPos();
    local footerWidth = 462 * scale;
    local footerX = browserX + math.max(12 * scale, browserWidth - scrollGutter - footerWidth);
    local footerY = math.max(footerCursorY + (8 * scale), browserY + browserHeight - (43 * scale));
    imgui.SetCursorScreenPos({ footerX, footerY });
    if (imgui.Checkbox('Show Indexed-Only Groups##warn_show_indexed', { uiSettings.show_indexed_only })) then
        uiSettings.show_indexed_only = not uiSettings.show_indexed_only;
        if (not uiSettings.show_indexed_only) then
            local selectedGroup = encounterBrowser.find_group(categories, warn.encounterContent, warn.encounterGroup);
            if (selectedGroup ~= nil and (selectedGroup.rule_count or 0) == 0) then warn.encounterGroup = nil; end
        end
        save_settings();
    end
    imgui.SameLine();
    if (imgui.Button('Collapse All##warn_categories_collapse', { 112 * scale, 0 })) then
        for _, category in ipairs(categories) do uiSettings.encounter_collapsed[category.content] = true; end
        save_settings();
    end
    imgui.SameLine();
    if (imgui.Button('Expand All##warn_categories_expand', { 104 * scale, 0 })) then
        for _, category in ipairs(categories) do uiSettings.encounter_collapsed[category.content] = false; end
        save_settings();
    end
    imgui.EndChild();
    imgui.EndChild();

    imgui.TextColored({ 0.72, 0.78, 0.86, 1.0 }, 'Search encounter alerts');
    if (type(imgui.PushItemWidth) == 'function') then imgui.PushItemWidth(-1); end
    imgui.InputText('##warn_encounter_search', warn.ruleSearch, 255);
    if (type(imgui.PopItemWidth) == 'function') then imgui.PopItemWidth(); end
    imgui.Separator();
    guiOps.render_live_encounter_tools();
    imgui.Separator();
    if (imgui.CollapsingHeader('Custom Watches (Advanced)', 0)) then
        render_abilities_tab(true);
    else
        imgui.TextColored({ 0.58, 0.62, 0.68, 1.0 }, 'Collapsed - use this only for uncatalogued abilities you explicitly want to see.');
    end
    imgui.EndChild();
end

--------------------------------------------------------------------------------------------------
-- GUI: Global Debuffs tab
--------------------------------------------------------------------------------------------------

function guiOps.build_debuff_sound_combo(definition)
    local override = get_debuff_override(definition, true);
    local selectedValue = tostring(override.sound or '__global__');
    local inheritedLabel;
    if (definition ~= nil and definition.sound ~= nil and tostring(definition.sound) ~= '') then
        inheritedLabel = 'Default (' .. tostring(definition.sound) .. ')';
    else
        inheritedLabel = 'Global Sound (' .. tostring(warn.settings.sound.selected or 'None') .. ')';
    end
    local comboParts = { inheritedLabel };
    local comboValues = { '__global__' };
    local selectedIndex = 0;

    for i = 1, #warn.soundFiles do
        local filename = warn.soundFiles[i];
        local displayName = filename;
        if (filename ~= 'None') then
            displayName = filename:gsub('%.wav$', ''):gsub('%.WAV$', '');
        end
        table.insert(comboParts, displayName);
        table.insert(comboValues, filename);
        if (selectedValue ~= '__global__' and tostring(filename):lower() == selectedValue:lower()) then
            selectedIndex = #comboValues - 1;
        end
    end

    return table.concat(comboParts, '\0') .. '\0\0', comboValues, selectedIndex;
end

function render_debuffs_tab()
    ensure_debuff_settings();
    local cfg = warn.settings.debuffs;

    imgui.BeginChild('warn_debuff_scroll', { 0, 0 }, 0);

    if (imgui.Checkbox('Enable Global Debuff Tracking', { cfg.enabled })) then
        cfg.enabled = not cfg.enabled;
        if (not cfg.enabled) then clear_debuff_tracker(false); end
        save_settings();
    end
    imgui.TextColored({ 0.7, 0.7, 0.7, 1.0 },
        'No setup is required: Recommended statuses are enabled automatically.');
    imgui.TextColored({ 0.7, 0.7, 0.7, 1.0 },
        'Warn tracks debuffs on hostile monsters globally, even when they are not your target.');

    if (imgui.Checkbox('Smart Reapply Alerts', { cfg.smart_reapply })) then
        cfg.smart_reapply = not cfg.smart_reapply;
        save_settings();
    end
    imgui.TextColored({ 0.65, 0.65, 0.65, 1.0 },
        'For maintenance debuffs, wait to alert until this character can actually reapply the effect.');

    if (imgui.Checkbox('Play Debuff Alert Sounds', { cfg.sound_enabled })) then
        cfg.sound_enabled = not cfg.sound_enabled;
        save_settings();
    end
    if (imgui.Checkbox('Center Critical Crowd-Control Alerts', { cfg.critical_center })) then
        cfg.critical_center = not cfg.critical_center;
        save_settings();
    end
    imgui.TextColored({ 0.65, 0.65, 0.65, 1.0 },
        'Sleep and Petrify loss use a dedicated center-screen alert by default.');

    if (imgui.Checkbox('Show Estimated Durations', { cfg.show_estimates })) then
        cfg.show_estimates = not cfg.show_estimates;
        save_settings();
    end
    if (imgui.Checkbox('Warn Before Crowd Control Expires', { cfg.prewarn_enabled })) then
        cfg.prewarn_enabled = not cfg.prewarn_enabled;
        save_settings();
    end
    if (cfg.prewarn_enabled) then
        imgui.SameLine();
        local prewarn = { tonumber(cfg.prewarn_seconds) or 5.0 };
        if (imgui.SliderFloat('Seconds##warn_debuff_prewarn_seconds', prewarn, 1.0, 30.0, '%.0f')) then
            cfg.prewarn_seconds = prewarn[1];
            save_settings();
        end
    end
    imgui.TextColored({ 0.65, 0.65, 0.65, 1.0 },
        'Timers are estimates: when they expire, Warn shows ? until a real loss/removal event confirms the status is gone.');

    imgui.Separator();
    imgui.TextColored({ 1.0, 1.0, 1.0, 1.0 }, 'Quick Setup');
    if (imgui.Button('Recommended')) then apply_debuff_preset('recommended'); end
    imgui.SameLine();
    if (imgui.Button('Crowd Control')) then apply_debuff_preset('cc'); end
    imgui.SameLine();
    if (imgui.Button('All Supported')) then apply_debuff_preset('all'); end
    imgui.SameLine();
    if (imgui.Button('Off')) then apply_debuff_preset('off'); end

    imgui.Separator();
    imgui.TextColored({ 1.0, 1.0, 1.0, 1.0 },
        string.format('Currently Tracked Debuffs: %d', get_debuff_tracked_count(nil)));

    imgui.BeginChild('warn_debuff_active_list', { 0, 105 }, ImGuiChildFlags_Borders);
    local activeRows = {};
    local now = os.clock();
    for _, definition in ipairs(warn.debuffs.definitions or {}) do
        local statusTable = warn.debuffs.tracked[definition.id] or {};
        for _, entry in pairs(statusTable) do
            if ((entry.count or 0) > 0) then
                table.insert(activeRows, {
                    status = definition.name,
                    name = entry.name,
                    count = entry.count,
                    elapsed = math.max(0, now - (entry.last_applied or now)),
                    time_text = get_debuff_time_text(entry, now),
                    uncertain = entry.uncertain == true,
                });
            end
        end
    end
    table.sort(activeRows, function (a, b)
        if a.name == b.name then return a.status < b.status; end
        return tostring(a.name):lower() < tostring(b.name):lower();
    end);
    if (#activeRows == 0) then
        imgui.TextColored({ 0.6, 0.6, 0.6, 1.0 }, 'No hostile debuffs currently tracked.');
    else
        for _, row in ipairs(activeRows) do
            local suffix = cfg.show_estimates and (' [' .. row.time_text .. ']') or string.format(' (%.1fs)', row.elapsed);
            if (row.uncertain and cfg.show_estimates) then
                imgui.TextColored({ 1.0, 0.75, 0.25, 1.0 }, string.format('%s - %s x%d%s', row.name, row.status, row.count, suffix));
            else
                imgui.Text(string.format('%s - %s x%d%s', row.name, row.status, row.count, suffix));
            end
        end
    end
    imgui.EndChild();

    imgui.Separator();
    imgui.TextColored({ 1.0, 1.0, 1.0, 1.0 }, 'Tracked Statuses');

    local lastCategory = nil;
    for _, definition in ipairs(warn.debuffs.definitions or {}) do
        if definition.experimental ~= true then
            local category = tostring(definition.category or 'Other');
            if category ~= lastCategory then
                if (lastCategory ~= nil) then imgui.Separator(); end
                imgui.TextColored({ 0.75, 0.85, 1.0, 1.0 }, category);
                lastCategory = category;
            end

            local enabled = is_debuff_enabled(definition);
            local toggle = { enabled };
            if (imgui.Checkbox(definition.name .. '##warn_debuff_toggle_' .. definition.id, toggle)) then
                set_debuff_enabled(definition, not enabled);
            end
            if (definition.alert_policy == 'smart') then
                imgui.SameLine();
                imgui.TextColored({ 0.55, 0.75, 0.55, 1.0 }, '(smart)');
            end
        end
    end

    imgui.Separator();
    imgui.Checkbox('Show Advanced Debuff Options', warn.debuffs.advanced_open);

    if (warn.debuffs.advanced_open[1]) then
        imgui.TextColored({ 0.65, 0.65, 0.65, 1.0 },
            'Advanced options include per-status sounds, alert policy, experimental trackers and testing.');

        imgui.BeginGroup();
        imgui.BeginChild('warn_debuff_advanced_list', { 185, 175 }, ImGuiChildFlags_Borders);
        for _, definition in ipairs(warn.debuffs.definitions or {}) do
            local prefix = is_debuff_enabled(definition) and '[X] ' or '[ ] ';
            if (definition.experimental == true) then prefix = prefix .. '[EXP] '; end
            if (imgui.Selectable(prefix .. definition.name .. '##warn_debuff_select_' .. definition.id,
                                 warn.debuffs.selected_id == definition.id)) then
                warn.debuffs.selected_id = definition.id;
            end
        end
        imgui.EndChild();
        imgui.EndGroup();

        imgui.SameLine();

        imgui.BeginGroup();
        imgui.BeginChild('warn_debuff_advanced_detail', { 0, 175 }, ImGuiChildFlags_Borders);
        local definition = get_debuff_definition(warn.debuffs.selected_id);
        if (definition ~= nil) then
            imgui.TextColored({ 1.0, 0.9, 0.45, 1.0 }, definition.name);
            imgui.TextColored({ 0.7, 0.7, 0.7, 1.0 }, tostring(definition.category or 'Other'));
            if (definition.experimental == true) then
                imgui.TextColored({ 1.0, 0.65, 0.35, 1.0 }, 'Experimental log coverage - disabled by default.');
            end

            local enabled = is_debuff_enabled(definition);
            if (imgui.Checkbox('Track This Status##warn_debuff_detail_enable', { enabled })) then
                set_debuff_enabled(definition, not enabled);
            end

            local duration = { get_debuff_estimated_duration(definition) or 60.0 };
            if (imgui.SliderFloat('Estimated Duration##warn_debuff_duration', duration, 1.0, 600.0, '%.0f sec')) then
                set_debuff_estimated_duration(definition, duration[1]);
            end
            imgui.TextColored({ 0.60, 0.60, 0.60, 1.0 }, 'Used only for countdown display and pre-expire warnings; real loss packets still win.');

            local prewarn = debuff_prewarn_enabled(definition);
            if (imgui.Checkbox('Warn before estimate expires##warn_debuff_prewarn_status', { prewarn })) then
                local override = get_debuff_override(definition, true);
                override.prewarn = not prewarn;
                save_settings();
            end

            local onlyCapable = debuff_only_if_capable(definition);
            if (definition.counters ~= nil and #definition.counters > 0) then
                if (imgui.Checkbox('Only alert when I can reapply##warn_debuff_only_capable', { onlyCapable })) then
                    local override = get_debuff_override(definition, true);
                    override.only_if_capable = not onlyCapable;
                    save_settings();
                end

                local counterNames = {};
                for _, counter in ipairs(definition.counters) do
                    table.insert(counterNames, tostring(counter.name));
                end
                imgui.TextColored({ 0.65, 0.65, 0.65, 1.0 },
                    'Methods: ' .. table.concat(counterNames, ', '));
                local available = get_available_debuff_counter(definition);
                if (available ~= nil) then
                    imgui.TextColored({ 0.45, 1.0, 0.45, 1.0 },
                        'Available now: ' .. tostring(available.name));
                else
                    imgui.TextColored({ 0.65, 0.65, 0.65, 1.0 }, 'Available now: none detected');
                end
            end

            imgui.Text('Alert Sound:');
            local comboText, comboValues, selectedIndex = guiOps.build_debuff_sound_combo(definition);
            local soundSelection = { selectedIndex };
            if (imgui.Combo('##warn_debuff_sound_combo', soundSelection, comboText)) then
                local override = get_debuff_override(definition, true);
                override.sound = comboValues[soundSelection[1] + 1] or '__global__';
                save_settings();
            end

            if (imgui.Button('Test Loss Alert##warn_debuff_test')) then
                local counter = get_available_debuff_counter(definition);
                queue_debuff_loss(definition, 'Test Monster', counter);
                warn.debuffs.batch_deadline = 0;
                flush_debuff_loss_batch();
            end
            imgui.SameLine();
            if (imgui.Button('Clear Tracked##warn_debuff_clear_status')) then
                clear_debuff_status(definition, true);
            end
        else
            imgui.TextColored({ 0.6, 0.6, 0.6, 1.0 }, 'Select a status.');
        end
        imgui.EndChild();
        imgui.EndGroup();
    end

    imgui.EndChild();
end

--------------------------------------------------------------------------------------------------
-- GUI: Timer Learning tab
--------------------------------------------------------------------------------------------------

function render_timer_learning_tab()
    ensure_learning_settings();
    local cfg = warn.settings.learning;
    local counts = get_learning_counts();

    imgui.BeginChild('warn_learning_scroll', { 0, 0 }, 0);

    if (imgui.Checkbox('Learn Encounter Timings Automatically', { cfg.enabled })) then
        cfg.enabled = not cfg.enabled;
        save_settings();
    end
    imgui.TextColored({ 0.70, 0.78, 0.88, 1.0 },
        'Warn observes repeated hostile actions locally. Learned data is never submitted automatically.');
    imgui.TextColored({ 0.70, 0.78, 0.88, 1.0 },
        'Unknown abilities never alert automatically. Accepted observations remain uncertain readiness windows, not countdowns.');

    local unknownOrder = warn.activeEncounter.state.unknown_order or {};
    if (#unknownOrder > 0) then
        imgui.Separator();
        imgui.TextColored({ 1.0, 0.88, 0.35, 1.0 }, 'Recent Unverified Encounter Observations');
        imgui.TextColored({ 0.62, 0.66, 0.72, 1.0 },
            'Session-only diagnostics linked to the active encounter. They remain non-actionable until curated and verified.');
        imgui.BeginChild('warn_learning_encounter_unknown', { 0, 95 }, ImGuiChildFlags_Borders);
        local first = math.max(1, #unknownOrder - 7);
        for index = #unknownOrder, first, -1 do
            local entry = warn.activeEncounter.state.unknown[unknownOrder[index]];
            if (entry ~= nil) then
                imgui.Text(string.format('%s - %s   [%d observation%s]', entry.actor, entry.ability,
                    entry.count or 1, (entry.count or 1) == 1 and '' or 's'));
            end
        end
        imgui.EndChild();
    end

    local minimumUses = { tonumber(cfg.minimum_uses) or 3 };
    if (imgui.SliderFloat('Uses Before Suggesting##warn_learning_uses', minimumUses, 3.0, 6.0, '%.0f')) then
        cfg.minimum_uses = math.floor(minimumUses[1] + 0.5);
        save_settings();
    end

    imgui.Separator();
    imgui.TextColored({ 1.0, 1.0, 1.0, 1.0 }, string.format(
        'Review Queue: %d   Accepted Readiness Windows: %d   Still Observing: %d',
        counts.suggested, counts.approved, counts.observing));

    imgui.Separator();
    imgui.TextColored({ 1.0, 0.88, 0.35, 1.0 }, 'Readiness Suggestions');
    imgui.BeginChild('warn_learning_suggestions', { 0, 205 }, ImGuiChildFlags_Borders);
    local suggestions = get_sorted_learning_entries({ suggested = true });
    if (#suggestions == 0) then
        imgui.TextColored({ 0.62, 0.62, 0.62, 1.0 },
                'No readiness suggestions yet. Play normally; consistent repeats will appear here.');
    else
        for index, row in ipairs(suggestions) do
            local key = row.key;
            local entry = row.entry;
            if (index > 1) then imgui.Separator(); end
            imgui.TextColored({ 1.0, 0.90, 0.45, 1.0 },
                tostring(entry.actor) .. ' - ' .. tostring(entry.ability));
            imgui.TextColored({ 0.75, 0.82, 0.90, 1.0 }, string.format(
                'About %s   |   %d uses   |   %.0f%% confidence   |   observed %s to %s',
                format_seconds(entry.interval or 0), tonumber(entry.uses) or 0,
                (tonumber(entry.confidence) or 0) * 100,
                format_seconds(entry.minimum or entry.interval or 0),
                format_seconds(entry.maximum or entry.interval or 0)));
            if (entry.encounter ~= nil) then
                imgui.TextColored({ 0.62, 0.72, 0.84, 1.0 },
                    'Observed during: ' .. tostring(entry.content or 'Encounter') .. ' / ' .. tostring(entry.encounter));
            end
            if (imgui.Button('Accept Readiness Window##warn_learning_approve_' .. key)) then
                set_learning_status(key, entry, 'approved');
            end
            imgui.SameLine();
            if (imgui.Button('Keep Observing##warn_learning_observe_' .. key)) then
                entry.status = 'observing';
                entry.suggested_at = nil;
                mark_learning_dirty(true);
            end
            imgui.SameLine();
            if (imgui.Button('Ignore##warn_learning_ignore_' .. key)) then
                set_learning_status(key, entry, 'ignored');
            end
        end
    end
    imgui.EndChild();

    imgui.Separator();
    imgui.TextColored({ 0.55, 1.0, 0.60, 1.0 }, 'Accepted Readiness Windows');
    imgui.BeginChild('warn_learning_approved', { 0, 190 }, ImGuiChildFlags_Borders);
    local approved = get_sorted_learning_entries({ approved = true });
    if (#approved == 0) then
        imgui.TextColored({ 0.62, 0.62, 0.62, 1.0 }, 'No readiness windows accepted.');
    else
        local now = os.clock();
        for index, row in ipairs(approved) do
            local key = row.key;
            local entry = row.entry;
            if (index > 1) then imgui.Separator(); end
            local active = warn.timerLearning.active_timers[key];
            local timingText = 'Waiting for the next observed use';
            if (active ~= nil) then
                local earliest = (active.started_at or now) + (active.minimum or active.interval or 0);
                local latest = (active.started_at or now) + (active.maximum or active.interval or 0);
                if (now < earliest) then
                    timingText = 'Possible readiness in ' .. format_seconds(earliest - now) .. ' to ' .. format_seconds(latest - now);
                elseif (now <= latest) then
                    timingText = 'Likely ready now (uncertain window)';
                else
                    timingText = 'Readiness window overdue: ? +' .. format_seconds(now - latest);
                end
            end
            imgui.TextColored({ 0.65, 1.0, 0.70, 1.0 },
                tostring(entry.actor) .. ' - ' .. tostring(entry.ability));
            imgui.Text(string.format('Observed range: %s to %s   |   %s',
                format_seconds(entry.minimum or entry.approved_interval or entry.interval or 0),
                format_seconds(entry.maximum or entry.approved_interval or entry.interval or 0), timingText));
            if (entry.encounter ~= nil) then
                imgui.TextColored({ 0.62, 0.72, 0.84, 1.0 },
                    'Encounter context: ' .. tostring(entry.content or 'Encounter') .. ' / ' .. tostring(entry.encounter));
            end
            if (imgui.Button('Return to Review##warn_learning_review_' .. key)) then
                set_learning_status(key, entry, 'suggested');
            end
            imgui.SameLine();
            if (imgui.Button('Forget##warn_learning_forget_' .. key)) then
                forget_learning_entry(key);
            end
        end
    end
    imgui.EndChild();

    imgui.Separator();
    imgui.Checkbox('Show Ignored Observations', warn.timerLearning.show_ignored);
    if (warn.timerLearning.show_ignored[1]) then
        local ignored = get_sorted_learning_entries({ ignored = true });
        imgui.BeginChild('warn_learning_ignored', { 0, 110 }, ImGuiChildFlags_Borders);
        if (#ignored == 0) then
            imgui.TextColored({ 0.62, 0.62, 0.62, 1.0 }, 'No ignored observations.');
        else
            for _, row in ipairs(ignored) do
                local key = row.key;
                local entry = row.entry;
                imgui.Text(tostring(entry.actor) .. ' - ' .. tostring(entry.ability));
                imgui.SameLine();
                if (imgui.Button('Restore##warn_learning_restore_' .. key)) then
                    set_learning_status(key, entry, 'observing');
                end
            end
        end
        imgui.EndChild();
    end

    imgui.EndChild();
end

--------------------------------------------------------------------------------------------------
-- GUI: Community Database tab
--------------------------------------------------------------------------------------------------

function render_community_database_tab()
    ensure_community_settings();
    local cfg = warn.settings.community;
    local installedVersion = warn.community.installed and tonumber(warn.community.installed.database_version) or 0;

    imgui.BeginChild('warn_community_scroll', { 0, 0 }, 0);
    imgui.TextColored({ 1.0, 0.88, 0.35, 1.0 }, 'Community Encounter Database');
    imgui.TextColored({ 0.70, 0.78, 0.88, 1.0 },
        'Updates contain validated encounter data only. Warn never downloads or replaces addon code.');

    if (imgui.Checkbox('Enable Installed Community Rules', { cfg.enabled })) then
        cfg.enabled = not cfg.enabled;
        save_settings();
        load_context_rules();
    end
    if (imgui.Checkbox('Check Automatically When Warn Opens', { cfg.auto_check })) then
        cfg.auto_check = not cfg.auto_check;
        warn.community.auto_check_queued = false;
        save_settings();
    end
    imgui.TextColored({ 0.62, 0.62, 0.62, 1.0 }, 'Automatic checks run at most once every 24 hours. Installation always requires your approval.');

    imgui.Separator();
    imgui.Text(string.format('Installed Database: v%d', installedVersion));
    imgui.Text(string.format('Installed Community Content: %d rules / %d encounters',
        warn.community.loaded_rule_count or 0, warn.community.loaded_catalog_count or 0));
    imgui.Text(string.format('Combined Runtime Rules: %d action / %d state',
        #(warn.rules.ability_rules or {}), #(warn.rules.state_rules or {})));

    local statusColors = {
        error = { 1.0, 0.40, 0.35, 1.0 },
        update_available = { 1.0, 0.85, 0.25, 1.0 },
        installed = { 0.45, 1.0, 0.55, 1.0 },
        rolled_back = { 0.55, 0.85, 1.0, 1.0 },
        up_to_date = { 0.55, 1.0, 0.65, 1.0 },
    };
    imgui.TextColored(statusColors[warn.community.status] or { 0.75, 0.75, 0.75, 1.0 },
        'Status: ' .. tostring(warn.community.message));

    if (not warn.community.busy) then
        if (imgui.Button('Check for Updates')) then warn.community.check_requested = true; end
        local manifest = warn.community.remote_manifest;
        if (manifest ~= nil and tonumber(manifest.database_version) > installedVersion) then
            imgui.SameLine();
            if (imgui.Button('Install Database v' .. tostring(manifest.database_version))) then
                warn.community.update_requested = true;
            end
        end
        if (warn.community.backup_available) then
            imgui.SameLine();
            if (imgui.Button('Roll Back Database')) then warn.community.rollback_requested = true; end
        end
    else
        imgui.TextColored({ 1.0, 0.85, 0.25, 1.0 }, 'Database operation in progress...');
    end

    if (warn.community.remote_manifest ~= nil) then
        local manifest = warn.community.remote_manifest;
        imgui.Separator();
        imgui.TextColored({ 0.75, 0.85, 1.0, 1.0 }, 'Latest Published Database');
        imgui.Text(string.format('Version %d   |   Published %s', manifest.database_version, tostring(manifest.published_at)));
        imgui.Text(string.format('%d rules   |   %d encounters', manifest.rule_count, manifest.encounter_count));
        if (manifest.release_notes ~= nil and manifest.release_notes ~= '') then
            imgui.TextColored({ 0.75, 0.75, 0.75, 1.0 }, 'Notes: ' .. tostring(manifest.release_notes));
        end
    end

    imgui.Separator();
    imgui.TextColored({ 0.65, 0.65, 0.65, 1.0 },
        'Safety: 2 MB limit, strict JSON schema, official repository URL restriction, SHA-256 verification, and automatic backup.');
    imgui.TextColored({ 0.65, 0.65, 0.65, 1.0 },
        'Downloaded content cannot run Lua code and cannot change your personal settings or learned timers.');
    imgui.EndChild();
end

--------------------------------------------------------------------------------------------------
-- GUI: Sound tab
--------------------------------------------------------------------------------------------------

function guiOps.build_sound_combo(selectedName)
    selectedName = tostring(selectedName or 'None');
    local values = {};
    local labels = {};
    local selectedIndex = 0;
    local found = false;

    for i = 1, #warn.soundFiles do
        local filename = warn.soundFiles[i];
        local displayName = filename;
        if (filename ~= 'None') then
            displayName = filename:gsub('%.wav$', ''):gsub('%.WAV$', '');
        end
        table.insert(values, filename);
        table.insert(labels, displayName);
        if (filename:lower() == selectedName:lower()) then
            selectedIndex = i - 1;
            found = true;
        end
    end

    -- Keep configured custom filenames visible even when the WAV has not yet
    -- been copied into the sounds folder.
    if (not found and selectedName ~= '' and selectedName ~= 'None') then
        table.insert(values, selectedName);
        table.insert(labels, '[Missing] ' .. selectedName:gsub('%.wav$', ''):gsub('%.WAV$', ''));
        selectedIndex = #values - 1;
    end
    return values, table.concat(labels, '\0') .. '\0\0', selectedIndex;
end

function render_sound_tab()
    ensure_sound_settings();
    if (imgui.Checkbox('Enable Warning Sound', { warn.settings.sound.enabled })) then
        warn.settings.sound.enabled = not warn.settings.sound.enabled;
        save_settings();
    end

    imgui.TextColored({ 1.0, 1.0, 1.0, 1.0 }, 'Sound:');

    local values, soundNames, soundIndex = guiOps.build_sound_combo(warn.settings.sound.selected);
    local selected = { soundIndex };
    if (imgui.Combo('##warn_sound_combo', selected, soundNames)) then
        warn.settings.sound.selected = values[selected[1] + 1] or 'None';
        save_settings();
    end

    if (imgui.Button('Test Sound')) then
        play_selected_sound();
    end
    imgui.SameLine();
    if (imgui.Button('Refresh Sounds')) then
        refresh_sound_files(true);
    end

    imgui.Separator();
    imgui.TextColored({ 1.0, 0.84, 0.35, 1.0 }, 'First GUI Open');
    if (imgui.Checkbox('Play Sound on First GUI Open', { warn.settings.sound.first_open_enabled })) then
        warn.settings.sound.first_open_enabled = not warn.settings.sound.first_open_enabled;
        save_settings();
    end
    imgui.TextColored({ 0.7, 0.7, 0.7, 1.0 },
        'Plays once per FFXI launch. Reloading Warn will not play it again.');

    local firstValues, firstNames, firstIndex = guiOps.build_sound_combo(warn.settings.sound.first_open_selected);
    local firstSelected = { firstIndex };
    if (imgui.Combo('##warn_first_open_sound_combo', firstSelected, firstNames)) then
        warn.settings.sound.first_open_selected = firstValues[firstSelected[1] + 1] or 'None';
        save_settings();
    end
    if (imgui.Button('Test First-Open Sound')) then
        play_sound_file(warn.settings.sound.first_open_selected);
    end

    imgui.Separator();
    imgui.TextColored({ 0.7, 0.7, 0.7, 1.0 }, string.format('%d WAV file(s) found in the sounds folder.', math.max(0, #warn.soundFiles - 1)));
    imgui.TextColored({ 0.7, 0.7, 0.7, 1.0 }, [[Drop any .wav file into warn\sounds\ and click Refresh Sounds.]]);
    imgui.TextColored({ 0.7, 0.7, 0.7, 1.0 }, 'The new file will appear automatically in the dropdown above.');
end

--------------------------------------------------------------------------------------------------
-- GUI: Options navigation
--------------------------------------------------------------------------------------------------

function guiOps.draw_role_icon(icon, x, y, size)
    local draw = imgui.GetWindowDrawList();
    local texture = warn.ui.role_textures and warn.ui.role_textures[icon] or nil;
    local pointer = uiTextures.pointer(texture);
    if (pointer ~= nil) then
        draw:AddImage(pointer, { x, y }, { x + size, y + size },
            { 0, 0 }, { 1, 1 }, 0xFFFFFFFF);
        return;
    end
    local color = imgui.GetColorU32((warn.ui.theme and warn.ui.theme.brass_hover) or { 1.0, 0.84, 0.50, 1.0 });
    local dim = imgui.GetColorU32((warn.ui.theme and warn.ui.theme.brass_dim) or { 0.55, 0.45, 0.25, 1.0 });
    local accent = imgui.GetColorU32((warn.ui.theme and warn.ui.theme.important) or { 0.30, 0.68, 1.0, 1.0 });
    local thickness = math.max(1, get_ui_scale() * 1.5);
    local fine = math.max(1, get_ui_scale());

    if (icon == 'shield') then
        local outline = {
            { x + size * 0.16, y + size * 0.12 }, { x + size * 0.84, y + size * 0.12 },
            { x + size * 0.78, y + size * 0.66 }, { x + size * 0.50, y + size * 0.91 },
            { x + size * 0.22, y + size * 0.66 },
        };
        draw_line_path(draw, outline, color, thickness, true);
        draw:AddLine({ x + size * 0.50, y + size * 0.17 },
            { x + size * 0.50, y + size * 0.82 }, dim, thickness);
        draw:AddLine({ x + size * 0.24, y + size * 0.24 },
            { x + size * 0.50, y + size * 0.17 }, dim, fine);
        draw:AddLine({ x + size * 0.50, y + size * 0.17 },
            { x + size * 0.76, y + size * 0.24 }, color, fine);
    elseif (icon == 'potion') then
        -- A compact alchemist bottle: broad body, narrow neck, and a blue liquid line.
        local bottle = {
            { x + size * 0.39, y + size * 0.10 }, { x + size * 0.61, y + size * 0.10 },
            { x + size * 0.61, y + size * 0.30 }, { x + size * 0.73, y + size * 0.42 },
            { x + size * 0.80, y + size * 0.59 }, { x + size * 0.76, y + size * 0.75 },
            { x + size * 0.65, y + size * 0.85 }, { x + size * 0.35, y + size * 0.85 },
            { x + size * 0.24, y + size * 0.75 }, { x + size * 0.20, y + size * 0.59 },
            { x + size * 0.27, y + size * 0.42 }, { x + size * 0.39, y + size * 0.30 },
        };
        draw_line_path(draw, bottle, color, thickness, true);
        draw:AddLine({ x + size * 0.35, y + size * 0.10 },
            { x + size * 0.65, y + size * 0.10 }, dim, thickness);
        draw:AddLine({ x + size * 0.27, y + size * 0.62 },
            { x + size * 0.73, y + size * 0.62 }, accent, thickness + fine);
        draw:AddLine({ x + size * 0.31, y + size * 0.69 },
            { x + size * 0.69, y + size * 0.69 }, dim, fine);
    elseif (icon == 'bow') then
        -- One bow and one arrow only; broad spacing keeps the silhouette readable at 24 px.
        draw_line_path(draw, {
            { x + size * 0.30, y + size * 0.10 }, { x + size * 0.17, y + size * 0.31 },
            { x + size * 0.15, y + size * 0.57 }, { x + size * 0.28, y + size * 0.88 },
        }, color, thickness + fine, false);
        draw:AddLine({ x + size * 0.30, y + size * 0.10 },
            { x + size * 0.31, y + size * 0.50 }, dim, fine);
        draw:AddLine({ x + size * 0.31, y + size * 0.50 },
            { x + size * 0.28, y + size * 0.88 }, dim, fine);
        draw:AddLine({ x + size * 0.12, y + size * 0.82 },
            { x + size * 0.86, y + size * 0.18 }, accent, thickness);
        draw_line_path(draw, {
            { x + size * 0.86, y + size * 0.18 }, { x + size * 0.72, y + size * 0.20 },
            { x + size * 0.84, y + size * 0.32 },
        }, color, thickness, true);
        draw:AddLine({ x + size * 0.11, y + size * 0.82 },
            { x + size * 0.12, y + size * 0.68 }, color, fine);
        draw:AddLine({ x + size * 0.11, y + size * 0.82 },
            { x + size * 0.25, y + size * 0.81 }, color, fine);
    elseif (icon == 'harp') then
        -- Open lyre silhouette with four separated strings for instant recognition.
        draw_line_path(draw, {
            { x + size * 0.24, y + size * 0.16 }, { x + size * 0.70, y + size * 0.18 },
            { x + size * 0.81, y + size * 0.31 }, { x + size * 0.72, y + size * 0.70 },
            { x + size * 0.62, y + size * 0.84 }, { x + size * 0.24, y + size * 0.80 },
        }, color, thickness, false);
        draw:AddLine({ x + size * 0.24, y + size * 0.16 },
            { x + size * 0.24, y + size * 0.80 }, color, thickness + fine);
        draw:AddLine({ x + size * 0.20, y + size * 0.84 },
            { x + size * 0.67, y + size * 0.88 }, dim, thickness);
        draw:AddLine({ x + size * 0.35, y + size * 0.24 },
            { x + size * 0.35, y + size * 0.76 }, accent, fine);
        draw:AddLine({ x + size * 0.46, y + size * 0.23 },
            { x + size * 0.46, y + size * 0.77 }, dim, fine);
        draw:AddLine({ x + size * 0.57, y + size * 0.22 },
            { x + size * 0.57, y + size * 0.78 }, accent, fine);
        draw:AddLine({ x + size * 0.67, y + size * 0.21 },
            { x + size * 0.64, y + size * 0.80 }, dim, fine);
    end
end

function guiOps.render_role_choice(definition, profile)
    local scale = get_ui_scale();
    local cursor_x, cursor_y = imgui.GetCursorScreenPos();
    local icon_clicked = false;
    if (definition.icon ~= nil) then
        local icon_size = math.max(28, 32 * scale);
        guiOps.draw_role_icon(definition.icon, cursor_x, cursor_y, icon_size);
        imgui.InvisibleButton('##responsibility_icon_' .. definition.id, { icon_size, icon_size });
        icon_clicked = imgui.IsItemClicked(0);
        imgui.SameLine();
        imgui.SetCursorScreenPos({ cursor_x + icon_size + (8 * scale),
            cursor_y + math.max(0, (icon_size - (24 * scale)) * 0.5) });
    end
    local enabled = profile[definition.id] == true;
    if (imgui.Checkbox(definition.label .. '##responsibility_' .. definition.id, { enabled }) or icon_clicked) then
        profile[definition.id] = not enabled;
        save_settings();
    end
    imgui.SameLine();
    imgui.TextColored({ 0.62, 0.66, 0.72, 1.0 }, definition.description);
    imgui.Spacing();
end

function guiOps.render_responsibility_options()
    ensure_responsibility_settings();
    local profile, key = get_current_responsibility_profile(true);
    imgui.TextColored({ 1.0, 0.88, 0.35, 1.0 }, 'Roles');
    imgui.TextColored({ 0.70, 0.78, 0.88, 1.0 }, 'Profile: ' .. get_player_job_text());
    imgui.TextColored({ 0.66, 0.72, 0.80, 1.0 },
        'Warn detects capabilities automatically. Roles describe your party function; assignments describe specific duties.');
    imgui.TextColored({ 0.66, 0.72, 0.80, 1.0 },
        'Critical mechanic facts always remain visible; these settings only suppress role-specific action instructions.');
    imgui.Separator();

    if (profile == nil or warn.mechanics == nil) then
        imgui.TextColored({ 1.0, 0.45, 0.35, 1.0 }, 'Character/job information is not available yet.');
        return;
    end

    imgui.TextColored({ 0.84, 0.70, 0.38, 1.0 }, 'Party Role');
    for _, definition in ipairs(warn.mechanics.responsibilities) do
        if (definition.group == 'role') then guiOps.render_role_choice(definition, profile); end
    end

    imgui.Spacing();
    imgui.Separator();
    imgui.TextColored({ 0.84, 0.70, 0.38, 1.0 }, 'Special Assignments');
    for _, definition in ipairs(warn.mechanics.responsibilities) do
        if (definition.group == 'assignment') then guiOps.render_role_choice(definition, profile); end
    end

    imgui.Separator();
    if (imgui.Button('Reset This Role Profile')) then
        local _, mainJob = get_player_profile_identity();
        local defaults = warn.mechanics.default_profile(mainJob);
        local replacement = T{};
        for responsibility, enabled in pairs(defaults) do replacement[responsibility] = enabled; end
        warn.settings.responsibilities.profiles[key] = replacement;
        save_settings();
    end
    imgui.TextColored({ 0.58, 0.62, 0.68, 1.0 },
        'This role profile is remembered automatically for this character and main job/subjob combination.');
end

function guiOps.render_alert_options()
    ensure_context_settings();
    local cfg = warn.settings.context;
    imgui.TextColored({ 1.0, 0.88, 0.35, 1.0 }, 'Alert Behavior');

    local controls = {
        { key = 'enabled', label = 'Enable Verified Encounter Alerts', help = 'Only verified database rules create contextual alerts.' },
        { key = 'job_counters', label = 'Show Assigned Action Instructions', help = 'Requires both an enabled role or assignment and a capability Ashita confirms is usable.' },
        { key = 'packet_recognition', label = 'Use Passive Packet Recognition', help = 'Reads incoming actions for faster reaction; never modifies, blocks or injects packets.' },
        { key = 'encounter_detection', label = 'Detect the Active Encounter Automatically', help = 'Uses only verified boss names and actions. Ambiguous evidence is never guessed.' },
        { key = 'encounter_hud', label = 'Show Compact Live Tactical HUD', help = 'Shows the current verified encounter, relevant mechanics, available role actions, timers and objectives.' },
        { key = 'encounter_diagnostics', label = 'Capture Bumba Packet Diagnostics', help = 'Keeps the 12 most recent unique Bumba action signatures in memory for retail verification; nothing is uploaded.' },
        { key = 'state_triggers', label = 'Enable Encounter State Triggers', help = 'Allows verified movement, presence and maintained-state mechanics.' },
        { key = 'contextual_sounds', label = 'Use Contextual / Per-Alert Sounds', help = 'When disabled, every encounter alert uses the global sound.' },
    };
    for _, control in ipairs(controls) do
        local enabled = cfg[control.key] == true;
        if (imgui.Checkbox(control.label .. '##alert_' .. control.key, { enabled })) then
            cfg[control.key] = not enabled;
            if (control.key == 'encounter_detection' and cfg[control.key] ~= true and not warn.activeEncounter.state.manual) then
                warn.activeEncounter.engine.clear(warn.activeEncounter.state, 'automatic detection disabled', os.clock());
                warn.encounter = encounterRuntime.new_state();
            end
            save_settings();
        end
        imgui.TextColored({ 0.62, 0.66, 0.72, 1.0 }, control.help);
    end

    if (cfg.encounter_detection) then
        local dismiss = { tonumber(cfg.encounter_dismiss_seconds) or 12 };
        if (imgui.SliderFloat('Encounter End Grace##warn_encounter_grace', dismiss, 5.0, 30.0, '%.0f sec')) then
            cfg.encounter_dismiss_seconds = math.floor(dismiss[1] + 0.5);
            save_settings();
        end
        imgui.TextColored({ 0.62, 0.66, 0.72, 1.0 },
            'Prevents a brief unload, draw-in or entity-table gap from ending the encounter card too early.');
    end

    if (cfg.packet_recognition) then
        local layoutValues = { 'auto', 'retail', 'legacy' };
        local layoutLabels = 'Auto Detect\000Retail / XiPackets\000SimpleLog / DSP Legacy\000\000';
        local layoutIndex = cfg.packet_layout == 'retail' and 1 or (cfg.packet_layout == 'legacy' and 2 or 0);
        local selectedLayout = { layoutIndex };
        if (imgui.Combo('Action Packet Layout##warn_packet_layout', selectedLayout, layoutLabels)) then
            cfg.packet_layout = layoutValues[selectedLayout[1] + 1] or 'auto';
            save_settings();
        end
        imgui.TextColored({ 0.62, 0.66, 0.72, 1.0 },
            'Auto detects the common legacy target-count header used by SimpleLog and DSP-based servers.');
    end

    imgui.Separator();
    imgui.TextColored({ 0.72, 0.80, 0.90, 1.0 }, 'Notification Burst Protection');
    local overlay = warn.settings.overlay;
    if (imgui.Checkbox('Protect Against AoE Alert Bursts##warn_burst_protection', { overlay.burst_protection })) then
        overlay.burst_protection = not overlay.burst_protection;
        if (not overlay.burst_protection) then warn.alertGuard.engine.clear(warn.alertGuard.state); end
        save_settings();
    end
    imgui.TextColored({ 0.62, 0.66, 0.72, 1.0 },
        'Rapid duplicates share one card and one sound. Only a small priority queue is retained; stale alerts expire automatically.');
    if (overlay.burst_protection) then
        local repeatWindow = { tonumber(overlay.repeat_suppression) or 1.25 };
        if (imgui.SliderFloat('Repeat Suppression##warn_repeat_window', repeatWindow, 0.50, 3.00, '%.2f sec')) then
            overlay.repeat_suppression = repeatWindow[1];
            save_settings();
        end
        local queueLimit = { tonumber(overlay.alert_queue_limit) or 4 };
        if (imgui.SliderFloat('Maximum Queued Alerts##warn_queue_limit', queueLimit, 1.0, 8.0, '%.0f')) then
            overlay.alert_queue_limit = math.floor(queueLimit[1] + 0.5);
            warn.alertGuard.engine.clear(warn.alertGuard.state);
            save_settings();
        end
        imgui.TextColored({ 0.58, 0.62, 0.68, 1.0 }, string.format(
            'Queued now: %d   Suppressed this session: %d   Capacity drops: %d   Critical preemptions: %d',
            #(warn.alertGuard.state.queue or {}), warn.alertGuard.state.suppressed or 0,
            warn.alertGuard.state.dropped or 0, warn.alertGuard.state.preempted or 0));
        if (#(warn.alertGuard.state.queue or {}) > 0 and imgui.Button('Clear Pending Alerts##warn_clear_alert_queue')) then
            warn.alertGuard.state.queue = {};
        end
    end

    imgui.Separator();
    imgui.TextColored({ 0.72, 0.80, 0.90, 1.0 }, 'Severity Levels');
    imgui.TextColored({ 0.55, 0.82, 1.0, 1.0 }, 'IMPORTANT - informational mechanic or useful state change');
    imgui.TextColored({ 1.0, 0.72, 0.25, 1.0 }, 'DANGER - meaningful damage, control or positioning risk');
    imgui.TextColored({ 1.0, 0.35, 0.30, 1.0 }, 'CRITICAL - lethal or fight-changing mechanic; factual warning always remains visible');
    imgui.TextColored({ 0.58, 0.62, 0.68, 1.0 }, string.format(
        'Reactive packets recognized this session: %d%s%s   Targets in last action: %d', warn.reactive.packet_actions or 0,
        warn.reactive.last_packet_action ~= '' and ('   Last: ' .. warn.reactive.last_packet_action) or '',
        warn.reactive.last_packet_layout ~= '' and ('   Layout: ' .. warn.reactive.last_packet_layout) or '',
        warn.reactive.last_target_count or 0));
    if (warn.reactive.last_status_observation ~= '') then
        imgui.TextColored({ 0.58, 0.62, 0.68, 1.0 }, 'Last party-status observation: ' .. warn.reactive.last_status_observation);
    end
end

function render_options_tab()
    local learningCounts = get_learning_counts();
    local sections = {
        { label = 'Roles', render = guiOps.render_responsibility_options },
        { label = learningCounts.suggested > 0 and ('Learning (' .. learningCounts.suggested .. ')') or 'Learning', render = render_timer_learning_tab },
        { label = warn.community.status == 'update_available' and 'Database (!)' or 'Database', render = render_community_database_tab },
        { label = 'Debuffs', render = render_debuffs_tab },
        { label = 'Alerts', render = guiOps.render_alert_options },
        { label = 'Appearance', render = render_appearance_tab },
        { label = 'Sound', render = render_sound_tab },
    };

    imgui.BeginChild('warn_options_nav', { 175, 0 }, ImGuiChildFlags_Borders);
    imgui.TextColored({ 1.0, 0.88, 0.35, 1.0 }, 'Options');
    imgui.Separator();
    for index, section in ipairs(sections) do
        if (imgui.Selectable(section.label .. '##warn_option_' .. index, warn.optionsSection[1] == index)) then
            warn.optionsSection[1] = index;
        end
    end
    imgui.EndChild();
    imgui.SameLine();
    imgui.BeginChild('warn_options_content', { 0, 0 }, ImGuiChildFlags_Borders);
    local selected = sections[warn.optionsSection[1]] or sections[1];
    selected.render();
    imgui.EndChild();
end

--------------------------------------------------------------------------------------------------
-- GUI: main window
--------------------------------------------------------------------------------------------------

function guiOps.render_launcher()
    ensure_ui_settings();
    local ui = warn.settings.ui;
    if (ui.launcher_enabled ~= true) then return; end
    if (warn.ui.theme == nil) then reload_ui_theme(); end

    local scale = get_ui_scale();
    local size = math.max(36, math.min(96, tonumber(ui.launcher_size) or 58)) * scale;
    local display = imgui.GetIO().DisplaySize;
    if (warn.ui.launcher_position_initialized ~= true) then
        if ((tonumber(ui.launcher_position_x) or -1) < 0 or (tonumber(ui.launcher_position_y) or -1) < 0) then
            ui.launcher_position_x = 34 * scale;
            ui.launcher_position_y = math.max(20, display.y - size - (54 * scale));
        end
        warn.ui.launcher_position_initialized = true;
    end

    local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoBringToFrontOnFocus, ImGuiWindowFlags_NoMove);

    imgui.SetNextWindowPos({ ui.launcher_position_x, ui.launcher_position_y }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ size, size }, ImGuiCond_Always);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    if (imgui.Begin('##warn_launcher', true, flags)) then
        local pointer = uiTextures.pointer(warn.ui.launcher_texture);
        local item_x, item_y = imgui.GetCursorScreenPos();
        local draw = imgui.GetWindowDrawList();
        if (pointer ~= nil) then
            draw:AddImage(pointer, { item_x, item_y }, { item_x + size, item_y + size },
                { 0, 0 }, { 1, 1 }, 0xFFFFFFFF);
        else
            draw:AddCircleFilled({ item_x + size / 2, item_y + size / 2 }, size * 0.46,
                imgui.GetColorU32(warn.ui.theme.panel_bg), 48);
            draw:AddCircle({ item_x + size / 2, item_y + size / 2 }, size * 0.43,
                imgui.GetColorU32(warn.ui.theme.brass), 48, math.max(2, scale * 2));
            draw:AddText({ item_x + size * 0.31, item_y + size * 0.23 },
                imgui.GetColorU32(warn.ui.theme.brass_hover), 'W');
        end
        imgui.InvisibleButton('##warn_launcher_control', { size, size });

        if (imgui.IsItemClicked(0)) then
            warn.ui.launcher_press_active = true;
            warn.ui.launcher_dragged = false;
            warn.ui.launcher_drag_mouse_x, warn.ui.launcher_drag_mouse_y = imgui.GetMousePos();
        end

        if (warn.ui.launcher_press_active and imgui.IsMouseDown(0)) then
            local mouse_x, mouse_y = imgui.GetMousePos();
            if (imgui.IsMouseDragging(0, 3) and warn.ui.launcher_drag_mouse_x ~= nil and
                warn.ui.launcher_drag_mouse_y ~= nil) then
                warn.ui.launcher_dragged = true;
                ui.launcher_position_x = math.max(0, math.min(display.x - size,
                    ui.launcher_position_x + mouse_x - warn.ui.launcher_drag_mouse_x));
                ui.launcher_position_y = math.max(0, math.min(display.y - size,
                    ui.launcher_position_y + mouse_y - warn.ui.launcher_drag_mouse_y));
                warn.ui.next_launcher_save = os.clock() + 0.35;
            end
            warn.ui.launcher_drag_mouse_x = mouse_x;
            warn.ui.launcher_drag_mouse_y = mouse_y;
        elseif (warn.ui.launcher_press_active and imgui.IsMouseReleased(0)) then
            if (warn.ui.launcher_dragged ~= true) then
                set_gui_open(not warn.isGuiOpen[1]);
            end
            warn.ui.launcher_press_active = false;
            warn.ui.launcher_dragged = false;
            warn.ui.launcher_drag_mouse_x = nil;
            warn.ui.launcher_drag_mouse_y = nil;
        elseif (not imgui.IsMouseDown(0)) then
            warn.ui.launcher_press_active = false;
            warn.ui.launcher_dragged = false;
            warn.ui.launcher_drag_mouse_x = nil;
            warn.ui.launcher_drag_mouse_y = nil;
        end

        local x, y = imgui.GetWindowPos();
        x = math.floor(x); y = math.floor(y);
        warn.ui.last_launcher_x = x;
        warn.ui.last_launcher_y = y;
    end
    imgui.End();
    imgui.PopStyleVar();

    if (warn.ui.next_launcher_save ~= nil and os.clock() >= warn.ui.next_launcher_save) then
        warn.ui.next_launcher_save = nil;
        save_settings();
    end
end

function render_config_window()
    if (not warn.isGuiOpen[1]) then
        return;
    end

    queue_automatic_community_check();

    ensure_ui_settings();
    if (warn.ui.theme == nil) then reload_ui_theme(); end
    local scale = get_ui_scale();
    if (not warn.guiSizeInitialized) then
        local display = imgui.GetIO().DisplaySize;
        local starterWidth = math.min(1320 * scale, math.max(720 * scale, tonumber(display.x) - 40));
        local starterHeight = math.min(1080 * scale, math.max(600 * scale, tonumber(display.y) - 40));
        imgui.SetNextWindowSize({ starterWidth, starterHeight }, ImGuiCond_FirstUseEver);
        warn.guiSizeInitialized = true;
    end
    imgui.SetNextWindowSizeConstraints({ 720 * scale, 600 * scale, }, { FLT_MAX, FLT_MAX, });
    warn.ui.focus_api_available = (type(imgui.SetNextWindowFocus) == 'function') or (type(imgui.SetWindowFocus) == 'function');
    if (warn.settings.ui.always_on_top and type(imgui.SetNextWindowFocus) == 'function') then
        imgui.SetNextWindowFocus();
    end
    uiTheme.push(warn.ui.theme, scale);
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse);
    -- Warn has its own close control and custom header. Passing a mutable open-state
    -- pointer can make some Ashita ImGui builds restore their native title bar.
    if (imgui.Begin('##warn_dashboard', true, flags)) then
        if (warn.settings.ui.always_on_top and type(imgui.SetWindowFocus) == 'function') then
            imgui.SetWindowFocus();
        end
        local window_x, window_y = imgui.GetWindowPos();
        local window_x, window_y = imgui.GetWindowPos();
        local window_width, window_height = imgui.GetWindowSize();
        local draw = imgui.GetWindowDrawList();
        local brass = imgui.GetColorU32(warn.ui.theme.brass);
        local dim = imgui.GetColorU32(warn.ui.theme.brass_dim);
        local corner = 17 * scale;
        draw:AddRect({ window_x, window_y }, { window_x + window_width, window_y + window_height },
            brass, warn.ui.theme.rounding * scale, 0, math.max(1, warn.ui.theme.border_size * scale));
        draw:AddLine({ window_x + 7 * scale, window_y + corner },
            { window_x + 7 * scale, window_y + 7 * scale }, dim, 2 * scale);
        draw:AddLine({ window_x + 7 * scale, window_y + 7 * scale },
            { window_x + corner, window_y + 7 * scale }, dim, 2 * scale);
        draw:AddLine({ window_x + window_width - corner, window_y + 7 * scale },
            { window_x + window_width - 7 * scale, window_y + 7 * scale }, dim, 2 * scale);
        draw:AddLine({ window_x + window_width - 7 * scale, window_y + 7 * scale },
            { window_x + window_width - 7 * scale, window_y + corner }, dim, 2 * scale);

        local pointer = uiTextures.pointer(warn.ui.launcher_texture);
        if (pointer ~= nil) then
            imgui.Image(pointer, { 44 * scale, 44 * scale }, { 0, 0 }, { 1, 1 });
            imgui.SameLine();
        end
        local headerTitle = 'WARN';
        local headerSubtitle = 'VANA\'DIEL TACTICAL ENCOUNTER ASSISTANT';
        local headerContext = warn.mainTab[1] == 1 and 'Verified encounter intelligence and custom watches'
            or 'Roles, learning, alerts, appearance, and sound';
        local headerWidth = math.max(guiOps.measure_text_width(headerTitle),
            guiOps.measure_text_width(headerSubtitle), guiOps.measure_text_width(headerContext));
        local headerLeft = math.max(imgui.GetCursorPosX(), (window_width - headerWidth) * 0.5);
        imgui.BeginGroup();
        set_ui_font_scale(1.28 * scale);
        imgui.SetCursorPosX(headerLeft + math.max(0, (headerWidth - guiOps.measure_text_width(headerTitle)) * 0.5));
        imgui.TextColored(warn.ui.theme.brass_hover, headerTitle);
        set_ui_font_scale(0.82 * scale);
        imgui.SetCursorPosX(headerLeft + math.max(0, (headerWidth - guiOps.measure_text_width(headerSubtitle)) * 0.5));
        imgui.TextColored(warn.ui.theme.text_muted, headerSubtitle);
        set_ui_font_scale(0.76 * scale);
        imgui.SetCursorPosX(headerLeft + math.max(0, (headerWidth - guiOps.measure_text_width(headerContext)) * 0.5));
        imgui.TextColored(warn.ui.theme.text_muted, headerContext);
        set_ui_font_scale(1.0);
        imgui.EndGroup();
        imgui.SameLine();
        imgui.SetCursorPosX(math.max(imgui.GetCursorPosX(), window_width - 45 * scale));
        if (imgui.Button('X##warn_close', { 28 * scale, 28 * scale })) then warn.isGuiOpen[1] = false; end

        imgui.Separator();
        local tab_width = 172 * scale;
        local tabsWidth = (tab_width * 2) + (8 * scale);
        imgui.SetCursorPosX(math.max(imgui.GetCursorPosX(), (window_width - tabsWidth) * 0.5));
        if (warn.mainTab[1] == 1) then imgui.PushStyleColor(ImGuiCol_Button, warn.ui.theme.selected); end
        if (imgui.Button('ENCOUNTERS##warn_main_encounters', { tab_width, 34 * scale })) then warn.mainTab[1] = 1; end
        if (warn.mainTab[1] == 1) then imgui.PopStyleColor(); end
        imgui.SameLine();
        if (warn.mainTab[1] == 2) then imgui.PushStyleColor(ImGuiCol_Button, warn.ui.theme.selected); end
        if (imgui.Button('OPTIONS##warn_main_options', { tab_width, 34 * scale })) then warn.mainTab[1] = 2; end
        if (warn.mainTab[1] == 2) then imgui.PopStyleColor(); end
        imgui.Separator();

        local mainScrollGutter = math.max(18, 24 * scale);
        imgui.BeginChild('warn_main_content', { -mainScrollGutter, -28 * scale }, 0);
        if (warn.mainTab[1] == 1) then render_context_tab(); else render_options_tab(); end
        imgui.EndChild();
        imgui.Separator();
        if (warn.settings.ui.controller_enabled) then
            imgui.TextColored(warn.ui.theme.text_muted,
                'Controller: LB/RB tabs   D-pad navigate   B/Circle close');
        else
            imgui.TextColored(warn.ui.theme.text_muted,
                'Tip: click the W launcher to reopen Warn, or drag it normally to reposition it.');
        end
    end
    imgui.End();
    uiTheme.pop();
end

function guiOps.controller_visible_rules()
    local result = {};
    for _, rule in ipairs(get_all_context_rules()) do
        if (rule.verified == true) then
            local content = tostring(rule.content or 'Other');
            local group = guiOps.get_rule_group(rule);
            if (warn.encounterContent == nil or content == warn.encounterContent) and
               (warn.encounterGroup == nil or group == warn.encounterGroup) then
                table.insert(result, rule);
            end
        end
    end
    table.sort(result, function (a, b) return get_rule_display_name(a):lower() < get_rule_display_name(b):lower(); end);
    return result;
end

function guiOps.controller_move_category(delta)
    local choices = { { content = nil, group = nil } };
    for _, category in ipairs(guiOps.get_encounter_categories()) do
        table.insert(choices, { content = category.content, group = nil });
        for _, group in ipairs(category.groups) do
            if (encounterBrowser.group_is_visible(group, warn.settings.ui.show_indexed_only)) then
                table.insert(choices, { content = category.content, group = group.name });
            end
        end
    end
    local count = #choices;
    if (count == 0) then return; end
    warn.ui.encounter_category_index = ((warn.ui.encounter_category_index - 1 + delta) % count) + 1;
    local selected = choices[warn.ui.encounter_category_index];
    warn.encounterContent = selected.content;
    warn.encounterGroup = selected.group;
    if (selected.content ~= nil) then warn.settings.ui.encounter_collapsed[selected.content] = false; end
    warn.ui.encounter_rule_index = 1;
    local rules = guiOps.controller_visible_rules();
    warn.selectedRuleId = rules[1] and rules[1].id or nil;
end

function guiOps.controller_move_rule(delta)
    local rules = guiOps.controller_visible_rules();
    if (#rules == 0) then return; end
    warn.ui.encounter_rule_index = ((warn.ui.encounter_rule_index - 1 + delta) % #rules) + 1;
    warn.selectedRuleId = rules[warn.ui.encounter_rule_index].id;
end

function guiOps.handle_controller_action(action)
    if (warn.settings == nil or warn.isGuiOpen[1] ~= true) then return false; end
    ensure_ui_settings();
    if (warn.settings.ui.controller_enabled ~= true) then return false; end
    if (action == 'tab_left' or action == 'tab_right') then
        warn.mainTab[1] = warn.mainTab[1] == 1 and 2 or 1;
    elseif (action == 'up' or action == 'down') then
        local delta = action == 'up' and -1 or 1;
        if (warn.mainTab[1] == 1) then guiOps.controller_move_category(delta);
        else warn.optionsSection[1] = ((warn.optionsSection[1] - 1 + delta) % 7) + 1; end
    elseif (action == 'left' or action == 'right') then
        if (warn.mainTab[1] == 1) then guiOps.controller_move_rule(action == 'left' and -1 or 1);
        else return false; end
    elseif (action == 'close') then
        warn.isGuiOpen[1] = false;
    else
        return false;
    end
    return true;
end

--------------------------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------------------------

ashita.events.register('load', 'load_cb', function ()
    warn.settings = settings.load(default_settings, 'warn_settings');
    warn.abilitySettings = settings.load(default_ability_settings, 'warn_abilities');
    warn.ruleSettings = settings.load(default_rule_settings, 'warn_rule_settings');
    warn.learningData = settings.load(default_learning_data, 'warn_learning');
    ensure_context_settings();
    ensure_ui_settings();
    ensure_sound_settings();
    ensure_responsibility_settings();
    ensure_learning_settings();
    ensure_community_settings();
    ensure_debuff_settings();
    ensure_rule_settings();
    reload_ui_theme();

    warn.templateBuf = T{ warn.settings.overlay.template };

    warn.font = fonts.new(T{
        visible = true,
        font_family = 'Arial',
        bold = true,
        font_height = math.floor(14 * warn.settings.overlay.size) + 1,
        draw_flags = 0x10,
        color = warn.settings.overlay.text_color,
        color_outline = warn.settings.overlay.outline_color,
        position_x = warn.settings.overlay.position_x,
        position_y = warn.settings.overlay.position_y,
        padding = 4,
        background = T{
            visible = true,
            color = warn.settings.overlay.bg_color,
            scale_x = 1.0,
            scale_y = 1.0,
            width = 0.0,
            height = 0.0,
        },
    });

    warn.criticalFont = fonts.new(T{
        visible = false,
        font_family = 'Arial',
        bold = true,
        font_height = 36,
        draw_flags = 0x10,
        color = 0xFFFFFF00,
        color_outline = 0xFF000000,
        position_x = 400,
        position_y = 300,
        padding = 12,
        background = T{
            visible = true,
            color = 0xE0660000,
            scale_x = 1.0,
            scale_y = 1.0,
            width = 0.0,
            height = 0.0,
        },
    });

    load_abilities();
    local mechanicOk, mechanicErr = load_mechanic_modules();
    if (not mechanicOk) then
        print(chat.header(addon.name):append(chat.error(mechanicErr)));
    end
    local communityOk, communityErr = load_community_modules();
    if (communityOk) then
        load_installed_community_database(false);
    else
        set_community_status('error', communityErr);
        print(chat.header(addon.name):append(chat.error(communityErr)));
    end
    load_context_rules();
    load_debuff_definitions();
    load_timer_learning();
    refresh_sound_files(false);
end);

ashita.events.register('unload', 'unload_cb', function ()
    if (warn.timerLearning.dirty) then save_learning_data(); end
    if (warn.font ~= nil) then
        warn.font:destroy();
        warn.font = nil;
    end
    if (warn.criticalFont ~= nil) then
        warn.criticalFont:destroy();
        warn.criticalFont = nil;
    end
    uiTextures.clear();
end);

ashita.events.register('xinput_button', 'warn_xinput_button_cb', function (e)
    if (e == nil or e.injected == true or tonumber(e.state) ~= 1) then return; end
    local actions = {
        [0] = 'up', [1] = 'down', [2] = 'left', [3] = 'right',
        [5] = 'close', [8] = 'tab_left', [9] = 'tab_right', [13] = 'close',
    };
    local action = actions[tonumber(e.button)];
    if (action ~= nil and guiOps.handle_controller_action(action)) then e.blocked = true; end
end);

ashita.events.register('dinput_button', 'warn_dinput_button_cb', function (e)
    if (e == nil or e.injected == true or warn.settings == nil or warn.isGuiOpen[1] ~= true) then return; end
    ensure_ui_settings();
    if (warn.settings.ui.controller_enabled ~= true or warn.settings.ui.controller_layout == 'xinput') then return; end
    local button = tonumber(e.button);
    local state = tonumber(e.state);
    local action = nil;
    if (button == 32) then
        local directions = { [0] = 'up', [9000] = 'right', [18000] = 'down', [27000] = 'left' };
        action = directions[state];
    elseif (state == 128 or state == 1) then
        if (button == 52) then action = 'tab_left';
        elseif (button == 53) then action = 'tab_right';
        elseif (warn.settings.ui.controller_layout == 'playstation' and button == 50) then action = 'close';
        elseif (warn.settings.ui.controller_layout == 'switch' and button == 49) then action = 'close';
        end
    end
    if (action ~= nil and guiOps.handle_controller_action(action)) then e.blocked = true; end
end);

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/warn')) then
        return;
    end

    e.blocked = true;

    -- /warn - toggle the GUI.
    if (#args == 1) then
        set_gui_open(not warn.isGuiOpen[1]);
        return;
    end

    local sub = args[2]:lower();

    if (sub == 'debuffs' or sub == 'debuff') then
        ensure_debuff_settings();
        if (#args == 2 or args[3]:lower() == 'list') then
            print_debuff_tracker(nil);
            return;
        end

        local action = args[3]:lower();
        if (action == 'clear') then
            clear_debuff_tracker(true);
            return;
        end

        if (action == 'reload') then
            clear_debuff_tracker(false);
            if (load_debuff_definitions()) then
                refresh_sound_files(false);
                print(chat.header(addon.name):append(chat.message(string.format(
                    'Reloaded %d global debuff definitions.', #warn.debuffs.definitions))));
            end
            return;
        end

        if (action == 'preset') then
            local preset = (#args >= 4) and args[4] or 'recommended';
            if (apply_debuff_preset(preset)) then
                print(chat.header(addon.name):append(chat.message('Global debuff preset: ')):append(chat.warning(preset)));
            else
                print(chat.header(addon.name):append(chat.error(
                    'Unknown preset. Use recommended, cc, all, or off.')));
            end
            return;
        end

        if (action == 'soon') then
            if (#args < 4) then
                print(chat.header(addon.name):append(chat.error('Usage: /warn debuffs soon <status> [mob name]')));
                return;
            end
            local definition = get_debuff_definition(args[4]);
            if (definition == nil) then
                print(chat.header(addon.name):append(chat.error('Unknown debuff: ' .. tostring(args[4]))));
                return;
            end
            local name = (#args >= 5) and table.concat(args, ' ', 5) or 'Test Monster';
            local fake = { name = name, expires_at = os.clock() + (tonumber(warn.settings.debuffs.prewarn_seconds) or 5.0) };
            queue_debuff_prewarn(definition, fake);
            warn.debuffs.prewarn_deadline = 0;
            flush_debuff_prewarn_batch();
            return;
        end

        if (action == 'test' or action == 'gain') then
            if (#args < 4) then
                print(chat.header(addon.name):append(chat.error('Usage: /warn debuffs test <status> [mob name]')));
                return;
            end
            local definition = get_debuff_definition(args[4]);
            if (definition == nil) then
                print(chat.header(addon.name):append(chat.error('Unknown debuff: ' .. tostring(args[4]))));
                return;
            end
            local name = (#args >= 5) and table.concat(args, ' ', 5) or 'Test Monster';
            debuff_mark_gained(definition, name);
            print(chat.header(addon.name):append(chat.message(
                name .. ' marked with ' .. definition.name .. ' for testing. Estimated: ' ..
                tostring(get_debuff_time_text((get_debuff_status_table(definition, false) or {})[name:lower()], os.clock())))));
            return;
        end

        if (action == 'lose' or action == 'loss') then
            if (#args < 4) then
                print(chat.header(addon.name):append(chat.error('Usage: /warn debuffs lose <status> [mob name]')));
                return;
            end
            local definition = get_debuff_definition(args[4]);
            if (definition == nil) then
                print(chat.header(addon.name):append(chat.error('Unknown debuff: ' .. tostring(args[4]))));
                return;
            end
            local name = (#args >= 5) and table.concat(args, ' ', 5) or 'Test Monster';
            local statusTable = get_debuff_status_table(definition, false);
            if (statusTable == nil or statusTable[name:lower()] == nil) then
                debuff_mark_gained(definition, name);
            end
            debuff_mark_lost(definition, name, false);
            warn.debuffs.batch_deadline = 0;
            flush_debuff_loss_batch();
            return;
        end

        print(chat.header(addon.name):append(chat.error(
            'Usage: /warn debuffs [list|clear|reload|preset <recommended|cc|all|off>|test <status> [mob]|lose <status> [mob]|soon <status> [mob]]')));
        return;
    end

    -- Backward-compatible Sleep commands now use the unified Debuff Engine.
    if (sub == 'sleep') then
        local definition = get_debuff_definition('sleep');
        if (definition == nil) then return; end
        if (#args == 2 or args[3]:lower() == 'list') then
            print_debuff_tracker('sleep');
            return;
        end
        local action = args[3]:lower();
        if (action == 'clear') then
            clear_debuff_status(definition, true);
            return;
        end
        local name = (#args >= 4) and table.concat(args, ' ', 4) or 'Test Monster';
        if (action == 'test') then
            debuff_mark_gained(definition, name);
            print(chat.header(addon.name):append(chat.message(
                name .. ' marked asleep for testing. Use /warn sleep wake ' .. name)));
            return;
        end
        if (action == 'wake') then
            local statusTable = get_debuff_status_table(definition, false);
            if (statusTable == nil or statusTable[name:lower()] == nil) then debuff_mark_gained(definition, name); end
            debuff_mark_lost(definition, name, false);
            warn.debuffs.batch_deadline = 0;
            flush_debuff_loss_batch();
            return;
        end
        print(chat.header(addon.name):append(chat.error('Usage: /warn sleep [list|clear|test <mob>|wake <mob>]')));
        return;
    end

    -- Backward-compatible Petrify commands now use the unified Debuff Engine.
    if (sub == 'petrify') then
        local definition = get_debuff_definition('petrify');
        if (definition == nil) then return; end
        if (#args == 2 or args[3]:lower() == 'list') then
            print_debuff_tracker('petrify');
            return;
        end
        local action = args[3]:lower();
        if (action == 'clear') then
            clear_debuff_status(definition, true);
            return;
        end
        local name = (#args >= 4) and table.concat(args, ' ', 4) or 'Test Monster';
        if (action == 'test') then
            debuff_mark_gained(definition, name);
            print(chat.header(addon.name):append(chat.message(
                name .. ' marked petrified for testing. Use /warn petrify recover ' .. name)));
            return;
        end
        if (action == 'recover') then
            local statusTable = get_debuff_status_table(definition, false);
            if (statusTable == nil or statusTable[name:lower()] == nil) then debuff_mark_gained(definition, name); end
            debuff_mark_lost(definition, name, false);
            warn.debuffs.batch_deadline = 0;
            flush_debuff_loss_batch();
            return;
        end
        print(chat.header(addon.name):append(chat.error('Usage: /warn petrify [list|clear|test <mob>|recover <mob>]')));
        return;
    end

    if (sub == 'capability') then
        if (#args < 3) then
            print(chat.header(addon.name):append(chat.error('Usage: /warn capability <spell name>')));
            return;
        end
        local spellName = table.concat(args, ' ', 3);
        local resource = find_spell_resource(spellName);
        local ok, spell, reason;
        if (resource ~= nil and tonumber(resource.Skill) == 43) then
            ok, spell, reason = can_use_blu_spell_now(spellName);
        else
            ok, spell, reason = can_use_spell_now(spellName);
        end
        local canonical = (spell ~= nil and spell.Name ~= nil and spell.Name[1] ~= nil) and tostring(spell.Name[1]) or spellName;
        if (ok) then
            print(chat.header(addon.name):append(chat.message(canonical .. ': ')):append(chat.warning('AVAILABLE NOW')));
        else
            print(chat.header(addon.name):append(chat.message(canonical .. ': ')):append(chat.warning('NOT AVAILABLE - ' .. tostring(reason))));
        end
        return;
    end

    if (sub == 'teststate') then
        if (#args < 4) then
            print(chat.header(addon.name):append(chat.error('Usage: /warn teststate <rule id> <gained|lost>')));
            return;
        end
        local rule = find_context_rule_by_id(args[3]);
        if (rule == nil or rule.type ~= 'debuff_maintenance') then
            print(chat.header(addon.name):append(chat.error('Maintained-debuff rule not found: ' .. tostring(args[3]))));
            return;
        end
        local state = warn.ruleState[rule.id];
        if (state == nil) then return; end
        local change = args[4]:lower();
        if (change == 'gained') then
            state.status_active = true;
            state.triggered = true;
            print(chat.header(addon.name):append(chat.message(tostring(rule.actor) .. ': tracked debuff marked ACTIVE.')));
        elseif (change == 'lost') then
            state.status_active = false;
            state.triggered = false;
            if (not trigger_context_rule(rule, rule.actor, rule.loss_message or rule.message)) then
                print(chat.header(addon.name):append(chat.warning('Loss state recorded, but no configured counter is currently usable.')));
            else
                state.triggered = true;
            end
        else
            print(chat.header(addon.name):append(chat.error('State must be gained or lost.')));
        end
        return;
    end

    if (sub == 'sounds') then
        refresh_sound_files(true);
        return;
    end

    if (sub == 'rules') then
        print_rule_summary();
        return;
    end

    if (sub == 'coverage') then
        print_coverage_summary();
        return;
    end

    if (sub == 'rule') then
        if (#args < 3) then
            print(chat.header(addon.name):append(chat.error('Usage: /warn rule <rule id>  OR  /warn rule reset <rule id>')));
            return;
        end

        if (args[3]:lower() == 'reset') then
            if (#args < 4) then
                print(chat.header(addon.name):append(chat.error('Usage: /warn rule reset <rule id>')));
                return;
            end
            local ruleId = table.concat(args, ' ', 4);
            local rule = find_context_rule_by_id(ruleId);
            if (rule == nil) then
                print(chat.header(addon.name):append(chat.error('Context rule not found: ')):append(chat.warning(ruleId)));
                return;
            end
            reset_rule_override(rule);
            print(chat.header(addon.name):append(chat.message('Reset alert settings for: ')):append(chat.warning(tostring(rule.id))));
            return;
        end

        local ruleId = table.concat(args, ' ', 3);
        local rule = find_context_rule_by_id(ruleId);
        if (rule == nil) then
            print(chat.header(addon.name):append(chat.error('Context rule not found: ')):append(chat.warning(ruleId)));
            return;
        end
        warn.selectedRuleId = rule.id;
        warn.ruleSearch[1] = '';
        set_gui_open(true);
        return;
    end

    if (sub == 'testrule') then
        if (#args < 3) then
            print(chat.header(addon.name):append(chat.error('Usage: /warn testrule <rule id>')));
            return;
        end
        local wanted = table.concat(args, ' ', 3):lower();
        local found = nil;
        for _, rule in ipairs(warn.rules.ability_rules or {}) do
            if (tostring(rule.id):lower() == wanted) then
                found = rule;
                break
            end
        end
        if (found == nil) then
            for _, rule in ipairs(warn.rules.state_rules or {}) do
                if (tostring(rule.id):lower() == wanted) then
                    found = rule;
                    break
                end
            end
        end
        if (found == nil) then
            print(chat.header(addon.name):append(chat.error('Context rule not found: ')):append(chat.warning(wanted)));
            return;
        end
        if (not trigger_context_rule(found, found.ability or found.actor or found.id)) then
            print(chat.header(addon.name):append(chat.warning('Rule did not fire because its required player counter is not currently available.')));
        end
        return;
    end

    if (sub == 'list') then
        print_warning_list();
        return;
    end

    if (sub == 'clear') then
        clear_warning_list();
        return;
    end

    if (sub == 'debug') then
        warn.debug = not warn.debug;
        print(chat.header(addon.name):append(chat.message('Debug logging: ')):append(chat.warning(warn.debug and 'ON' or 'OFF')));
        return;
    end

    if (sub == 'test') then
        if (#args < 3) then
            print(chat.header(addon.name):append(chat.error('Usage: /warn test <ability name>')));
            return;
        end

        local testName = table.concat(args, ' ', 3);
        local entry = find_ability_entry(testName);
        local displayName = entry ~= nil and entry[1] or testName;
        submit_warning_payload({
            name=displayName, dedupe_key='test|' .. displayName:lower(),
            sound_policy='global', severity='important', prediction='reactive',
        });
        return;
    end

    if (sub == 'off') then
        if (#args < 3) then
            print(chat.header(addon.name):append(chat.error('Usage: /warn off <ability name>')));
            return;
        end
        set_ability_enabled(table.concat(args, ' ', 3), false);
        return;
    end

    -- Otherwise treat the remaining arguments as an ability name to add.
    set_ability_enabled(table.concat(args, ' ', 2), true);
end);

ashita.events.register('text_in', 'text_in_cb', function (e)
    if (e.message == nil or e.message == '') then
        return;
    end

    -- Global crowd-control and encounter-state messages are not necessarily ability/cast
    -- lines, so process them before attempting to parse readies / uses / casting verbs.
    process_global_debuff_message(e.message);
    process_maintained_debuff_messages(e.message);

    -- Distinguish the warning phase from the resolution phase. This lets a rule warn
    -- early on dangerous readies, while other rules (such as Waning Vigor) can wait
    -- until the move actually resolves before telling the player to resume attacking.
    local eventType = nil;
    local verbStart = nil;
    local verbEnd = nil;

    verbStart, verbEnd = string.find(e.message, 'readies', 1, true);
    if (verbStart ~= nil) then
        eventType = 'readies';
    else
        verbStart, verbEnd = string.find(e.message, 'uses', 1, true);
        if (verbStart ~= nil) then
            eventType = 'uses';
        else
            verbStart, verbEnd = string.find(e.message, 'starts casting', 1, true);
            if (verbStart ~= nil) then
                eventType = 'starts_casting';
            else
                verbStart, verbEnd = string.find(e.message, 'casts', 1, true);
                if (verbStart ~= nil) then
                    eventType = 'casts';
                else
                    verbStart, verbEnd = string.find(e.message, 'ready', 1, true);
                    if (verbStart ~= nil) then eventType = 'readies'; end
                end
            end
        end
    end

    if (eventType == nil) then
        return;
    end

    local abilityName = '';
    if (string.len(e.message) >= (verbEnd + 2)) then
        abilityName = string.sub(e.message, verbEnd + 2, math.max(verbEnd + 2, string.len(e.message) - 3));
        abilityName = trim(abilityName);
    end

    if (warn.debug) then
        print(chat.header(addon.name):append(chat.message('Raw: ' .. tostring(e.message))));
        print(chat.header(addon.name):append(chat.message('Event: ' .. tostring(eventType) .. ' / Parsed ability: ' .. tostring(abilityName))));
    end

    if (abilityName == '') then
        return;
    end

    local actorName = clean_action_name(string.sub(e.message, 1, math.max(0, verbStart - 1)));
    process_detected_action(actorName, abilityName, eventType, e.message, 'text');
end);

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if (e.id == 0x0028) then
        process_action_packet(e);
    end

    -- Use the raw battle-message packet as the primary debuff-loss signal.  This avoids
    -- dependency on chat filters, localization wording, or whether text_in sees the line.
    if (e.id == 0x0029) then
        process_encounter_status_packet(e);
        process_debuff_loss_packet(e);
    end

    -- Packet 0x000A is the zone-enter packet. Global debuff state is zone-local and
    -- must never survive zoning, otherwise same-named monsters could false-alert.
    if (e.id == 0x000A) then
        clear_debuff_tracker(false);
        warn.debuffs.mob_names = {};
        warn.debuffs.mob_counts = {};
        warn.debuffs.next_scan = 0;
        warn.timerLearning.active_timers = {};
        warn.reactive.recent = {};
        warn.reactive.last_target_count = 0;
        warn.reactive.last_status_observation = '';
        warn.encounter = encounterRuntime.new_state();
        warn.activeEncounter.state = warn.activeEncounter.engine.new_state();
        warn.alertGuard.engine.clear(warn.alertGuard.state);
        warn.active.firing = false;
        warn.critical.firing = false;
    end
end);

ashita.events.register('d3d_present', 'present_cb', function ()
    update_debuff_mob_cache(false);
    update_state_rules();
    update_divergence_circle_state();
    update_verified_encounter_timers();
    process_debuff_estimates();
    process_deferred_debuff_losses();
    flush_debuff_loss_batch();
    save_pending_learning_data();
    process_community_requests();
    guiOps.render_launcher();
    render_config_window();
    render_overlay();
    render_encounter_hud();
    render_critical_debuff_alert();
end);
