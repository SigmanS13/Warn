-- Classic Dynamis principal-boss index and verified high-impact mechanics.
-- Ordinary roaming NMs remain learning candidates; the browser focuses on progression bosses.

return {
    encounters = {
        { content='Dynamis', group="San d'Oria", encounter="Overlord's Tombstone", family='Replica', status='indexed' },
        { content='Dynamis', group="San d'Oria", encounter='Arch Overlord Tombstone', family='Replica', status='indexed' },
        { content='Dynamis', group='Bastok', encounter="Gu'Dha Effigy", family='Replica', status='indexed' },
        { content='Dynamis', group='Bastok', encounter="Arch Gu'Dha Effigy", family='Replica', status='indexed' },
        { content='Dynamis', group='Windurst', encounter='Tzee Xicu Idol', family='Replica', status='indexed' },
        { content='Dynamis', group='Windurst', encounter='Arch Tzee Xicu Idol', family='Replica', status='indexed' },
        { content='Dynamis', group='Jeuno', encounter='Goblin Golem', family='Replica', status='indexed' },
        { content='Dynamis', group='Jeuno', encounter='Arch Goblin Golem', family='Replica', status='indexed' },
        { content='Dynamis', group='Beaucedine', encounter='Angra Mainyu', family='Ahriman', status='indexed' },
        { content='Dynamis', group='Beaucedine', encounter='Arch Angra Mainyu', family='Ahriman', status='indexed' },
        { content='Dynamis', group='Xarcabard', encounter='Dynamis Lord', family='Demon', status='indexed' },
        { content='Dynamis', group='Xarcabard', encounter='Arch Dynamis Lord', family='Demon', status='indexed' },
        { content='Dynamis', group='Valkurm', encounter='Cirrate Christelle', family='Morbol', status='indexed' },
        { content='Dynamis', group='Valkurm', encounter='Arch Christelle', family='Morbol', status='indexed' },
        { content='Dynamis', group='Buburimu', encounter='Apocalyptic Beast', family='Dragon', status='indexed' },
        { content='Dynamis', group='Buburimu', encounter='Arch Apocalyptic Beast', family='Dragon', status='indexed' },
        { content='Dynamis', group='Qufim', encounter='Antaeus', family='Golem', status='indexed' },
        { content='Dynamis', group='Qufim', encounter='Arch Antaeus', family='Golem', status='indexed' },
        { content='Dynamis', group='Tavnazia', encounter='Diabolos Heart', family='Diabolos', status='indexed' },
        { content='Dynamis', group='Tavnazia', encounter='Diabolos Diamond', family='Diabolos', status='indexed' },
        { content='Dynamis', group='Tavnazia', encounter='Diabolos Club', family='Diabolos', status='indexed' },
        { content='Dynamis', group='Tavnazia', encounter='Diabolos Spade', family='Diabolos', status='indexed' },
        { content='Dynamis', group='Tavnazia / Arch', encounter='Diabolos Nox', family='Diabolos', status='indexed' },
        { content='Dynamis', group='Tavnazia / Arch', encounter='Diabolos Umbra', family='Diabolos', status='indexed' },
        { content='Dynamis', group='Tavnazia / Arch', encounter='Diabolos Somnus', family='Diabolos', status='indexed' },
        { content='Dynamis', group='Tavnazia / Arch', encounter='Diabolos Letum', family='Diabolos', status='indexed' },
    },

    ability_rules = {
        { id='dynamis_adl_tera_slash', content='Dynamis', group='Xarcabard', encounter='Arch Dynamis Lord', actor='Arch Dynamis Lord', event='readies', ability='Tera Slash', message='LETHAL CONE - MOVE BEHIND!\nCAN INFLICT INSTANT DEATH', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='cone', source='https://www.bg-wiki.com/ffxi/Arch_Dynamis_Lord' },
        { id='dynamis_adl_dynamic_implosion', content='Dynamis', group='Xarcabard', encounter='Arch Dynamis Lord', actor='Arch Dynamis Lord', event='readies', ability='Dynamic Implosion', message='AOE TERROR INCOMING!\nMOVE OUT', severity='danger', sound='warning.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Arch_Dynamis_Lord' },
        { id='dynamis_adl_death', content='Dynamis', group='Xarcabard', encounter='Arch Dynamis Lord', actor='Arch Dynamis Lord', event='starts_casting', ability='Death', message='DEATH CASTING!', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='single', source='https://www.bg-wiki.com/ffxi/Arch_Dynamis_Lord', counter={type='spell',name='Stun',label='STUN DEATH!',responsibility='interrupt'} },
        { id='dynamis_arch_angra_death', content='Dynamis', group='Beaucedine', encounter='Arch Angra Mainyu', actor='Arch Angra Mainyu', event='starts_casting', ability='Death', message='DEATH CASTING!', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='single', source='https://www.bg-wiki.com/ffxi/Arch_Angra_Mainyu', counter={type='spell',name='Stun',label='STUN DEATH!',responsibility='interrupt'} },
        { id='dynamis_arch_angra_voidsong', content='Dynamis', group='Beaucedine', encounter='Arch Angra Mainyu', actor='Arch Angra Mainyu', event='readies', ability='Voidsong', message='BUFF WIPE INCOMING!\nPREPARE TO REAPPLY SHELL', severity='danger', sound='warning.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Arch_Angra_Mainyu' },
        { id='dynamis_christelle_charm', content='Dynamis', group='Valkurm', encounter='Cirrate Christelle', actor='Cirrate Christelle', event='readies', ability='Charm', message='CHARM INCOMING!\nMOVE OUT', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Cirrate_Christelle' },
        { id='dynamis_arch_christelle_charm', content='Dynamis', group='Valkurm', encounter='Arch Christelle', actor='Arch Christelle', event='readies', ability='Charm', message='CHARM INCOMING!\nMOVE OUT', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Cirrate_Christelle' },
        { id='dynamis_christelle_bad_breath', content='Dynamis', group='Valkurm', encounter='Cirrate Christelle', actor='Cirrate Christelle', event='readies', ability='Extremely Bad Breath', message='LETHAL BREATH CONE!\nMOVE BEHIND', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='cone', source='https://www.bg-wiki.com/ffxi/Cirrate_Christelle' },
        { id='dynamis_arch_christelle_bad_breath', content='Dynamis', group='Valkurm', encounter='Arch Christelle', actor='Arch Christelle', event='readies', ability='Extremely Bad Breath', message='LETHAL BREATH CONE!\nMOVE BEHIND', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='cone', source='https://www.bg-wiki.com/ffxi/Cirrate_Christelle' },
        { id='dynamis_diabolos_nightmare', content='Dynamis', group='Tavnazia', encounter='Diabolos', actor='Diabolos Heart', actor_aliases={'Diabolos Diamond','Diabolos Club','Diabolos Spade','Diabolos Nox','Diabolos Umbra','Diabolos Somnus','Diabolos Letum'}, event='readies', ability='Nightmare', message='AOE SLEEP + DAMAGE OVER TIME!\nWAKE PARTY MEMBERS', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Dynamis_-_Tavnazia' },
        { id='dynamis_diabolos_ruinous_omen', content='Dynamis', group='Tavnazia', encounter='Diabolos', actor='Diabolos Heart', actor_aliases={'Diabolos Diamond','Diabolos Club','Diabolos Spade','Diabolos Nox','Diabolos Umbra','Diabolos Somnus','Diabolos Letum'}, event='readies', ability='Ruinous Omen', message='SEVERE ALLIANCE-WIDE HP CUT!\nHEALERS PREPARE', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='party', source='https://www.bg-wiki.com/ffxi/Dynamis_-_Tavnazia' },
    },

    state_rules = {},
};
