-- Original and Alluvion Skirmish index. Sparse documentation remains index-only.

return {
    encounters = {
        { content='Skirmish', group='Rala Waterways / NM Pool', encounter='Woecroak Toad', family='Toad', status='indexed' },
        { content='Skirmish', group='Rala Waterways / NM Pool', encounter='Skulking Spider', family='Spider', status='indexed' },
        { content='Skirmish', group='Rala Waterways / NM Pool', encounter='Forsaken Obdella', family='Obdella', status='indexed' },
        { content='Skirmish', group='Rala Waterways / NM Pool', encounter='Sewer Tarichuk', family='Eft', status='indexed' },
        { content='Skirmish', group='Rala Waterways / NM Pool', encounter='Photophobic Bat', family='Bat', status='indexed' },
        { content='Skirmish', group='Rala Waterways / NM Pool', encounter='Crustnibbler Twitherym', family='Twitherym', status='indexed' },
        { content='Skirmish', group='Rala Waterways / NM Pool', encounter='Sludgeslither Slime', family='Slime', status='indexed' },
        { content='Skirmish', group='Rala Waterways / NM Pool', encounter='Karst Crab', family='Crab', status='indexed' },
        { content='Skirmish', group='Cirdas Caverns', encounter='Monster Elimination', status='indexed' },
        { content='Skirmish', group='Yorcia Weald', encounter='Cantonment Defense', status='indexed' },
        { content='Skirmish', group="Outer Ra'Kaznar", encounter='Fragment Hunt', status='indexed' },
        { content='Skirmish', group='Alluvion / Cirdas', encounter='Mistmaw Xelhua', family='Behemoth', status='indexed' },
        { content='Skirmish', group='Alluvion / Cirdas', encounter='Mistmaw Cacus', family='Golem', status='indexed' },
        { content='Skirmish', group='Alluvion / Cirdas', encounter='Mistmaw Tawhiri', family='Giant Gnat', status='indexed' },
        { content='Skirmish', group='Alluvion / Cirdas', encounter='Mistmaw Aatxe', family='Bugard', status='indexed' },
        { content='Skirmish', group='Alluvion / Rala', encounter='Mistmaw Kroni', status='indexed' },
        { content='Skirmish', group='Alluvion / Rala', encounter='Mistmaw Guayota', status='indexed' },
        { content='Skirmish', group='Alluvion / Rala', encounter='Mistmaw Tecciztecatl', status='indexed' },
        { content='Skirmish', group='Alluvion / Rala', encounter='Mistmaw Leraje', status='indexed' },
        { content='Skirmish', group='Alluvion / Yorcia', encounter='Stronghold Defense', status='indexed' },
        { content='Skirmish', group='Alluvion / Yorcia', encounter="Balamor's Adumbration", family='Balamor', status='indexed' },
    },

    ability_rules = {
        { id='skirmish_spider_break', content='Skirmish', group='Rala Waterways / NM Pool', encounter='Skulking Spider', actor='Skulking Spider', event='starts_casting', ability='Break', message='PETRIFY CASTING!', severity='danger', sound='warning.wav', verified=true, prediction='reactive', target_shape='single', source='https://www.bg-wiki.com/ffxi/Rala_Waterways_(U)' },
        { id='skirmish_xelhua_howl', content='Skirmish', group='Alluvion / Cirdas', encounter='Mistmaw Xelhua', actor='Mistmaw Xelhua', event='uses', ability='Howl', message='MISTMAW LEVELED UP!\nFIGHT FROM BEHIND TO LIMIT HOWL', severity='danger', sound='warning.wav', verified=true, prediction='reactive', target_shape='self', source='https://www.bg-wiki.com/ffxi/Mistmaw_Xelhua' },
        { id='skirmish_cacus_volcanic_wrath', content='Skirmish', group='Alluvion / Cirdas', encounter='Mistmaw Cacus', actor='Mistmaw Cacus', event='readies', ability='Volcanic Wrath', message='AOE MAX HP DOWN + BURN!\nMOVE OUT', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Mistmaw_Cacus' },
        { id='skirmish_tawhiri_chainspell', content='Skirmish', group='Alluvion / Cirdas', encounter='Mistmaw Tawhiri', actor='Mistmaw Tawhiri', event='uses', ability='Chainspell', message='CHAIN-SPELL BLIZZAGA III PHASE!', severity='critical', sound='alarm.wav', verified=true, prediction='scripted', target_shape='self', source='https://www.bg-wiki.com/ffxi/Mistmaw_Tawhiri' },
        { id='skirmish_aatxe_awful_eye', content='Skirmish', group='Alluvion / Cirdas', encounter='Mistmaw Aatxe', actor='Mistmaw Aatxe', event='readies', ability='Awful Eye', message='PETRIFY + HATE RESET INCOMING!\nTANK RECLAIM', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='gaze', source='https://www.bg-wiki.com/ffxi/Mistmaw_Aatxe' },
        { id='skirmish_aatxe_breakga', content='Skirmish', group='Alluvion / Cirdas', encounter='Mistmaw Aatxe', actor='Mistmaw Aatxe', event='starts_casting', ability='Breakga', message='AOE PETRIFY CASTING!', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Mistmaw_Aatxe' },
    },

    state_rules = {
        { id='skirmish_woecroak_poison', content='Skirmish', group='Rala Waterways / NM Pool', encounter='Woecroak Toad', type='entity_present', actor='Woecroak Toad', message='WOECROAK ATTACKS INFLICT POTENT POISON\n100-150 HP PER TICK', severity='important', sound='alert.wav', once_per_spawn=true, verified=true, source='https://www.bg-wiki.com/ffxi/Rala_Waterways_(U)' },
        { id='skirmish_yorcia_stronghold', content='Skirmish', group='Alluvion / Yorcia', encounter='Stronghold Defense', type='entity_present', actor='Stronghold', message='USE ARS MONSTRUM SUMMONS TO DESTROY THE STRONGHOLD\nPROTECT THE MARCHLAND', severity='important', sound='alert.wav', once_per_spawn=true, verified=true, source='https://www.bg-wiki.com/ffxi/Category:Alluvion_Skirmish' },
    },
};
