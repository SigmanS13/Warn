local file = assert(io.open('warn.lua', 'rb'));
local source = file:read('*a');
file:close();
source = source:gsub('\r\n', '\n');

assert(source:find("actorGuard = require('data.actor_guard')", 1, true) ~= nil,
    'Warn must load the shared hostile-actor guard without adding a top-level local');

local matcher = assert(source:match(
    'local function find_context_ability_rule.-\nend\n\nlocal function find_entity_by_name'
), 'contextual ability matcher not found');
assert(matcher:find('warn.actorGuard.rule_matches_zone(rule, zoneId)', 1, true) ~= nil,
    'ability rules must enforce configured encounter zones');

local processor = assert(source:match(
    'local function process_detected_action.-\nend\n\nlocal function find_entity_name_by_server_id'
), 'detected-action processor not found');
assert(processor:find('warn.classify_action_actor(actorName)', 1, true) ~= nil,
    'text and fallback actions must classify their source actor');
assert(processor:find('warn.actorGuard.allows_encounter_action(context.actor_disposition)', 1, true) ~= nil,
    'all detected actions must pass the hostile-only boundary');
assert(processor:find('record_timer_learning_event', 1, true) ~= nil and
    processor:find('find_context_ability_rule', 1, true) ~= nil,
    'the hostile-only boundary must protect learning and contextual rule matching');

local packet = assert(source:match(
    'local function process_action_packet.-\nend\n\nlocal function save_pending_learning_data'
), 'action packet processor not found');
assert(packet:find('local actor, actorDisposition = find_entity_name_by_server_id(parsed.actor_id);', 1, true) ~= nil,
    'packet actors must carry entity disposition');
assert(packet:find("if (actorDisposition ~= 'hostile') then return; end", 1, true) ~= nil,
    'completed Trust/friendly actions must be rejected before encounter side effects');
local _, dispositionPasses = packet:gsub('actor_disposition=actorDisposition', '');
assert(dispositionPasses == 2, 'ready/cast and completion paths must pass packet disposition');

local stateScan = assert(source:match(
    'local function update_state_rules.-\nend\n\nlocal function trigger_runtime_timer_alert'
), 'state rule scanner not found');
assert(stateScan:find('local hostile = warn.actorGuard.is_hostile_entity(entity);', 1, true) ~= nil,
    'state scans must classify entities');
assert(stateScan:find('if (hostile and wanted[entityName])', 1, true) ~= nil,
    'Trusts and friendly NPCs must not arm state rules');

print('hostile_actor_paths_spec: every automatic encounter path is hostile-only');
