-- Dynamis - Divergence wave-boss index and mechanics with clear player responses.

return {
    encounters = {
        { content='Dynamis - Divergence', group="San d'Oria / Wave 1", encounter="Overseer's Tombstone", family='Replica', status='indexed' },
        { content='Dynamis - Divergence', group="San d'Oria / Wave 2", encounter='Halphas', family='Orc', status='indexed' },
        { content='Dynamis - Divergence', group="San d'Oria / Wave 3", encounter='Disjoined Elvaan', family='Fomor', status='indexed' },
        { content='Dynamis - Divergence', group='Bastok / Wave 1', encounter="Mu'Sha Effigy", family='Replica', status='indexed' },
        { content='Dynamis - Divergence', group='Bastok / Wave 2', encounter="Ka'Rho Fearsinger", family='Quadav', status='indexed' },
        { content='Dynamis - Divergence', group='Bastok / Wave 3', encounter='Disjoined Galka', family='Fomor', status='indexed' },
        { content='Dynamis - Divergence', group='Windurst / Wave 1', encounter='Evincing Idol', family='Replica', status='indexed' },
        { content='Dynamis - Divergence', group='Windurst / Wave 2', encounter='Fii Pexu the Eternal', family='Yagudo', status='indexed' },
        { content='Dynamis - Divergence', group='Windurst / Wave 3', encounter='Disjoined Tarutaru', family='Fomor', status='indexed' },
        { content='Dynamis - Divergence', group='Jeuno / Wave 1', encounter='Impish Golem', family='Replica', status='indexed' },
        { content='Dynamis - Divergence', group='Jeuno / Wave 2', encounter='Obstatrix', family='Goblin', status='indexed' },
        { content='Dynamis - Divergence', group='Jeuno / Wave 3', encounter='Disjoined Mithra', family='Fomor', status='indexed' },
        { content='Dynamis - Divergence', group='All Zones', encounter='Aurix', family='Goblin', status='indexed' },
    },

    ability_rules = {
        { id='divergence_halphas_counterstance', content='Dynamis - Divergence', group="San d'Oria / Wave 2", encounter='Halphas', actor='Halphas', event='uses', ability='Orcish Counterstance', message='HIGH-RATE COUNTER STANCE!\nHOLD MELEE ATTACKS', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='self', source="https://www.bg-wiki.com/ffxi/Dynamis_-_San_d'Oria_(D)" },
        { id='divergence_halphas_tornado_edge', content='Dynamis - Divergence', group="San d'Oria / Wave 2", encounter='Halphas', actor='Halphas', event='readies', ability='Tornado Edge', message='MAX HP / MP / TP DOWN INCOMING!', severity='danger', sound='warning.wav', verified=true, prediction='reactive', target_shape='single', source='https://www.bg-wiki.com/ffxi/Halphas' },
        { id='divergence_karho_wrath', content='Dynamis - Divergence', group='Bastok / Wave 2', encounter="Ka'Rho Fearsinger", actor="Ka'Rho Fearsinger", event='readies', ability="Wrath of Gu'Dha", message='HEAVY AOE KNOCKBACK + GRAVITY!\nAVOID NEARBY STATUES', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Ka%27Rho_Fearsinger' },
        { id='divergence_fii_pexu_doom', content='Dynamis - Divergence', group='Windurst / Wave 2', encounter='Fii Pexu the Eternal', actor='Fii Pexu the Eternal', event='readies', ability='Doom', message='10-COUNT DOOM!\nHOLY WATER / CURSNA', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='single', source='https://www.bg-wiki.com/ffxi/Dynamis_-_Windurst_(D)', counter={type='spell',name='Cursna',label='CAST CURSNA!',responsibility='cleanse'} },
        { id='divergence_obstatrix_goblin_dice', content='Dynamis - Divergence', group='Jeuno / Wave 2', encounter='Obstatrix', actor='Obstatrix', event='uses', ability='Goblin Dice', message='GOBLIN DICE RESOLVED\nWATCH FOR RANDOM EFFECTS / ABILITY RESET', severity='important', sound='alert.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Obstatrix' },
    },

    state_rules = {
        { id='divergence_disjoined_elvaan_fetters', content='Dynamis - Divergence', group="San d'Oria / Wave 3", encounter='Disjoined Elvaan', type='entity_present', actor='Disjoined Elvaan', message='WAVE 3 BOSS ACTIVE\nDEFEAT ELEMENTAL CIRCLES TO REMOVE DAMAGE REDUCTION', severity='important', sound='alert.wav', once_per_spawn=true, verified=true, source="https://www.bg-wiki.com/ffxi/Dynamis_-_San_d'Oria_(D)" },
        { id='divergence_disjoined_galka_fetters', content='Dynamis - Divergence', group='Bastok / Wave 3', encounter='Disjoined Galka', type='entity_present', actor='Disjoined Galka', message='WAVE 3 BOSS ACTIVE\nDEFEAT ELEMENTAL CIRCLES TO REMOVE DAMAGE REDUCTION', severity='important', sound='alert.wav', once_per_spawn=true, verified=true, source='https://www.bg-wiki.com/ffxi/Dynamis_-_Bastok_(D)' },
        { id='divergence_disjoined_tarutaru_fetters', content='Dynamis - Divergence', group='Windurst / Wave 3', encounter='Disjoined Tarutaru', type='entity_present', actor='Disjoined Tarutaru', message='WAVE 3 BOSS ACTIVE\nDEFEAT ELEMENTAL CIRCLES TO REMOVE DAMAGE REDUCTION', severity='important', sound='alert.wav', once_per_spawn=true, verified=true, source='https://www.bg-wiki.com/ffxi/Disjoined_Tarutaru' },
        { id='divergence_disjoined_mithra_fetters', content='Dynamis - Divergence', group='Jeuno / Wave 3', encounter='Disjoined Mithra', type='entity_present', actor='Disjoined Mithra', message='WAVE 3 BOSS ACTIVE\nDEFEAT ELEMENTAL CIRCLES TO REMOVE DAMAGE REDUCTION', severity='important', sound='alert.wav', once_per_spawn=true, verified=true, source='https://www.bg-wiki.com/ffxi/Dynamis_-_Jeuno_(D)' },
    },
};
