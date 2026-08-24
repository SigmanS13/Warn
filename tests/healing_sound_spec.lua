local modules = {
    'data/rules/abyssea.lua',
    'data/rules/ambuscade_v1.lua',
    'data/rules/ambuscade_v2_history.lua',
    'data/rules/dynamis.lua',
    'data/rules/geas_fete.lua',
    'data/rules/high_tier_battlefields.lua',
    'data/rules/omen.lua',
    'data/rules/sinister_reign.lua',
    'data/rules/unity_wanted.lua',
    'data/rules/vagary.lua',
};

local rules = {};
for _, path in ipairs(modules) do
    local module = dofile(path);
    for _, rule in ipairs(module.ability_rules or {}) do rules[rule.id] = rule; end
end

local healingRules = {
    'abyssea_cirein_deathgnash',
    'abyssea_resheph_tarsal_slam',
    'ambu_qutrub_reinforce',
    'ambu_qutrub_enforce',
    'ambu_troll_head_seize',
    'ambu_v2_ironclad_ballistic_kick',
    'dynamis_diabolos_ruinous_omen',
    'geas_erinys_feral_peck',
    'htbf_shinryu_cataclysmic_vortex',
    'htbf_shadowlord_damning_edict',
    'htbf_shadowlord_implosion',
    'htbf_legacy_gessho_mijin',
    'htbf_diabolos_ruinous_omen',
    'omen_craver_impalement',
    'omen_gin_zero_hour',
    'omen_ou_zero_hour',
    'sinister_sajjaka_denounce',
    'unity_clawberry_throat_stab',
    'unity_tumult_homing_missile',
    'vagary_palloritus_kaustra',
    'vagary_palloritus_last_laugh',
    'vagary_rancibus_nullifying_rain',
};

for _, id in ipairs(healingRules) do
    assert(rules[id] ~= nil, 'missing healing rule: ' .. id);
    assert(rules[id].sound == 'healme.wav', id .. ' must use healme.wav');
end

local notHealingRules = {
    'ambu_doppel_odin_zantetsuken',       -- /heal means kneeling here
    'ambu_dullahan_eisenschneider',       -- /heal means kneeling here
    'abyssea_briareus_colossal_slam',     -- Zombie: healing fails
    'abyssea_itzpapalotl_exuviation',     -- enemy self-heal
    'geas_woc_benediction',               -- enemy self-heal
    'geas_vinipata_sakra_storm',          -- explicitly stop healing
    'htbf_shinryu_mighty_guard',          -- enemy self-heal
};

for _, id in ipairs(notHealingRules) do
    assert(rules[id] ~= nil, 'missing non-healing control rule: ' .. id);
    assert(rules[id].sound ~= 'healme.wav', id .. ' must not use the player-healing cue');
end

print(string.format('healing_sound_spec: %d player-healing alerts use healme.wav; semantic exclusions preserved',
    #healingRules));
