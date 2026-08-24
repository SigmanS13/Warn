local mechanics = dofile('data/mechanics.lua');

local function assert_equal(actual, expected, label)
    if (actual ~= expected) then
        error(string.format('%s: expected %s, got %s', label, tostring(expected), tostring(actual)));
    end
end

local whm = mechanics.default_profile(3);
assert_equal(whm.primary_healer, true, 'WHM healer default');
assert_equal(whm.cleanse, true, 'WHM cleanse default');
assert_equal(whm.interrupt, false, 'WHM interrupt default');
assert_equal(mechanics.responsibilities[1].id, 'tank', 'primary role ordering');
assert_equal(mechanics.responsibilities[1].group, 'role', 'primary role grouping');
assert_equal(mechanics.responsibilities[1].icon, 'shield', 'Tank shield glyph');
assert_equal(mechanics.responsibilities[2].icon, 'potion', 'Primary Healer potion glyph');
assert_equal(mechanics.responsibilities[3].label, 'Damage Dealer', 'Damage Dealer visible label');
assert_equal(mechanics.responsibilities[3].icon, 'bow', 'Damage Dealer bow glyph');
assert_equal(mechanics.responsibilities[4].icon, 'harp', 'Support harp glyph');
assert_equal(mechanics.responsibilities[5].id, 'cleanse', 'assignment ordering');
assert_equal(mechanics.responsibilities[5].group, 'assignment', 'assignment grouping');

local blu = mechanics.default_profile(16);
assert_equal(blu.interrupt, true, 'BLU interrupt default');
assert_equal(blu.crowd_control, true, 'BLU crowd-control default');

local assigned, responsibility = mechanics.counter_is_assigned({ name = 'Stun' }, whm);
assert_equal(assigned, false, 'WHM Stun prompt suppressed');
assert_equal(responsibility, 'interrupt', 'Stun responsibility');

assigned = mechanics.counter_is_assigned({ name = 'Cursna' }, whm);
assert_equal(assigned, true, 'WHM Cursna prompt enabled');

local rule = mechanics.normalize_rule({ severity = 'critical' });
assert_equal(rule.prediction, 'reactive', 'rule prediction default');
assert_equal(rule.target_shape, 'unspecified', 'rule shape default');
assert_equal(rule.audience[1], 'everyone', 'rule audience default');

assert_equal(mechanics.profile_key('Test Name', 3, 5), 'test_name|3|5', 'stable profile key');

local htbf = dofile('data/rules/high_tier_battlefields.lua');
local odinRules = {};
local shadowLordRules = {};
local puppetRules = {};
local headWindRules = {};
local legacyRules = {};
for _, entry in ipairs(htbf.ability_rules or {}) do
    if entry.actor == 'Odin Prime' then odinRules[entry.id] = entry; end
    if entry.actor == 'Shadow Lord' then shadowLordRules[entry.id] = entry; end
    if entry.actor == 'Lancelord Gaheel Ja' then puppetRules[entry.id] = entry; end
    if entry.encounter == 'Head Wind' then headWindRules[entry.id] = entry; end
    if entry.encounter == 'Legacy of the Lost' then legacyRules[entry.id] = entry; end
end
assert_equal(odinRules.htbf_odin_dread_spikes.event, 'starts_casting', 'Dread Spikes warns from packet-visible cast start');
assert_equal(odinRules.htbf_odin_dread_spikes.severity, 'critical', 'Dread Spikes critical severity');
assert_equal(odinRules.htbf_odin_ofnir.ability, 'Ofnir', 'Odin Ofnir coverage');
assert_equal(odinRules.htbf_odin_yggr.counter.name, 'Dispel', 'Odin Yggr Dispel counter');
assert_equal(shadowLordRules.htbf_shadowlord_damning_edict.event, 'readies', 'Damning Edict early reaction');
assert_equal(shadowLordRules.htbf_shadowlord_implosion.severity, 'critical', 'packet-only Implosion severity');
assert_equal(shadowLordRules.htbf_shadowlord_firaja.event, 'starts_casting', 'Firaja cast warning');
assert_equal(puppetRules.htbf_gaheel_burning_memories.counter.responsibility, 'interrupt', 'Burning Memories role filter');
assert_equal(puppetRules.htbf_gaheel_granite_skin.event, 'uses', 'Granite Skin state warning');
assert_equal(headWindRules.htbf_headwind_rabbit_breakga.event, 'starts_casting', 'Head Wind Breakga cast warning');
assert_equal(headWindRules.htbf_headwind_rabbit_breakga.counter.responsibility, 'interrupt', 'Head Wind Breakga role filter');
assert_equal(headWindRules.htbf_headwind_x_charm.severity, 'critical', 'Head Wind Charm severity');
assert_equal(legacyRules.htbf_legacy_gessho_mijin.severity, 'critical', 'Legacy Mijin severity');

print('mechanics_spec: all checks passed');
