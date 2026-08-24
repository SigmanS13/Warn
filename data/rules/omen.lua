-- Verified Omen encounter rules. These focus on mechanics where the reaction is documented
-- and materially changes how the party should respond.

return {
    encounters = {
        { content='Omen', group='Mid-Bosses', encounter='Glassy Craver', family='Craver', status='indexed' },
        { content='Omen', group='Mid-Bosses', encounter='Glassy Gorger', family='Gorger', status='indexed' },
        { content='Omen', group='Mid-Bosses', encounter='Glassy Thinker', family='Thinker', status='indexed' },
        { content='Omen', group='Caturae Bosses', encounter='Fu', family='Caturae', status='indexed' },
        { content='Omen', group='Caturae Bosses', encounter='Kyou', family='Caturae', status='indexed' },
        { content='Omen', group='Caturae Bosses', encounter='Kei', family='Caturae', status='indexed' },
        { content='Omen', group='Caturae Bosses', encounter='Gin', family='Caturae', status='indexed' },
        { content='Omen', group='Caturae Bosses', encounter='Kin', family='Caturae', status='indexed' },
        { content='Omen', group='Caturae Bosses', encounter='Ou', family='Caturae', status='indexed' },
    },

    ability_rules = {
        -- Glassy mid-bosses ---------------------------------------------------------------
        { id='omen_craver_view_sync', content='Omen', encounter='Glassy Craver', actor='Glassy Craver', event='readies', ability='View Sync', message='DRAW-IN + CAROUSEL NEXT!\nBRACE AGAINST A WALL', severity='danger', sound='warning.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Glassy_Craver' },
        { id='omen_craver_impalement', content='Omen', encounter='Glassy Craver', actor='Glassy Craver', event='readies', ability='Impalement', message='HP-CRITICAL HIT + HATE RESET!\nHEAL / TANK RECLAIM', severity='critical', sound='healme.wav', verified=true, prediction='reactive', target_shape='single', source='https://www.bg-wiki.com/ffxi/Glassy_Craver' },

        { id='omen_gorger_blessing_sync', content='Omen', encounter='Glassy Gorger', actor='Glassy Gorger', event='readies', ability='Blessing Sync', message='BUFF COPY IN 10\'!\nLIMIT BUFFS - DISPEL COPIED EFFECTS', severity='danger', sound='warning.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Glassy_Gorger', counter={type='spell',name='Dispel',label='DISPEL COPIED BUFFS!'} },
        { id='omen_gorger_spirit_absorption', content='Omen', encounter='Glassy Gorger', actor='Glassy Gorger', event='readies', ability='Spirit Absorption', message='BUFF DRAIN + DAMAGE!\nMAX MELEE RANGE REDUCES DAMAGE', severity='danger', sound='warning.wav', verified=true, prediction='reactive', target_shape='single', source='https://www.bg-wiki.com/ffxi/Glassy_Gorger' },

        { id='omen_thinker_pain_sync', content='Omen', encounter='Glassy Thinker', actor='Glassy Thinker', event='readies', ability='Pain Sync', message='STOP ALL DAMAGE!\nRETALIATES FOR DAMAGE TAKEN WHILE READYING', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Glassy_Thinker' },
        { id='omen_thinker_shadow_spread', content='Omen', encounter='Glassy Thinker', actor='Glassy Thinker', event='readies', ability='Shadow Spread', message='AOE SLEEP + CURSE + BLIND!\nWAKE / CLEANSE PARTY', severity='danger', sound='warning.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Glassy_Thinker' },
        { id='omen_thinker_trinary_tap', content='Omen', encounter='Glassy Thinker', actor='Glassy Thinker', event='readies', ability='Trinary Tap', message='THREE-BUFF ABSORB INCOMING!', severity='danger', sound='warning.wav', verified=true, prediction='reactive', target_shape='single', source='https://www.bg-wiki.com/ffxi/Glassy_Thinker', counter={type='spell',name='Dispel',label='DISPEL STOLEN BUFFS!'} },

        -- Omen Caturae bosses -------------------------------------------------------------
        { id='omen_fu_ebullient_nullification', content='Omen', encounter='Fu', actor='Fu', event='readies', ability='Ebullient Nullification', message='BUFF ABSORB IN 20\'!\nTOO MANY BUFFS POWER UP FU', severity='critical', sound='alarm.wav', verified=true, prediction='scripted', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Fu' },
        { id='omen_fu_interference', content='Omen', encounter='Fu', actor='Fu', event='readies', ability='Interference', message='HEAVY DARK AOE + DISPEL + KNOCKBACK!', severity='danger', sound='warning.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Fu' },

        { id='omen_kyou_unfaltering_bravado', content='Omen', encounter='Kyou', actor='Kyou', event='readies', ability='Unfaltering Bravado', message='STACK IN FRONT!\n10,000 CONE DAMAGE SPLIT BETWEEN TARGETS', severity='critical', sound='alarm.wav', verified=true, prediction='scripted', target_shape='cone', source='https://www.bg-wiki.com/ffxi/Kyou' },
        { id='omen_kyou_meteor', content='Omen', encounter='Kyou', actor='Kyou', event='starts_casting', ability='Meteor', message='METEOR CASTING!\nHEAVY 25\' AOE DAMAGE', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Kyou' },

        { id='omen_kei_dancing_fullers', content='Omen', encounter='Kei', actor='Kei', event='readies', ability='Dancing Fullers', message='MOVE OUTSIDE 10\' - STAY WITHIN 20\'!\nUNMITIGATABLE DAMAGE PER TARGET IN RANGE', severity='critical', sound='alarm.wav', verified=true, prediction='scripted', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Kei' },
        { id='omen_kei_interference', content='Omen', encounter='Kei', actor='Kei', event='readies', ability='Interference', message='HEAVY DARK AOE + DISPEL + KNOCKBACK!', severity='danger', sound='warning.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Kei' },

        { id='omen_gin_suppressive_sphere', content='Omen', encounter='Gin', actor='Gin', event='uses', ability='Suppressive Sphere', aliases={'Supressive Sphere'}, message='MAGIC ABSORB SHIELD ACTIVE!\nUSE NONMAGICAL DAMAGE TO REMOVE IT', severity='important', sound='alert.wav', verified=true, prediction='reactive', target_shape='self', source='https://www.bg-wiki.com/ffxi/Gin' },
        { id='omen_gin_zero_hour', content='Omen', encounter='Gin', actor='Gin', event='readies', ability='Zero Hour', message='HP-CRITICAL AOE + HATE RESET!\nINHIBIT TP FOR 60 SEC', severity='critical', sound='healme.wav', verified=true, prediction='scripted', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Gin' },

        { id='omen_kin_target', content='Omen', encounter='Kin', actor='Kin', event='uses', ability='Target', message='TARGET LOCK ACTIVE!\nCHANGE TOP HATE OR USE COVER WITHIN 90 SEC', severity='critical', sound='alarm.wav', verified=true, prediction='scripted', target_shape='single', source='https://www.bg-wiki.com/ffxi/Kin' },
        { id='omen_kin_eleventh_dimension', content='Omen', encounter='Kin', actor='Kin', event='readies', ability='Eleventh Dimension', message='THREE-MINUTE TERROR INCOMING!\nTARGET LOCK WAS NOT BROKEN', severity='critical', sound='alarm.wav', verified=true, prediction='scripted', target_shape='single', source='https://www.bg-wiki.com/ffxi/Kin' },
        { id='omen_kin_death_sentence', content='Omen', encounter='Kin', actor='Kin', event='readies', ability='Death Sentence', message='SHORT-COUNT DOOM!\nHOLY WATER / CURSNA IMMEDIATELY', severity='critical', sound='alarm.wav', verified=true, prediction='reactive', target_shape='single', source='https://www.bg-wiki.com/ffxi/Kin', counter={type='spell',name='Cursna',label='CAST CURSNA!'} },
        { id='omen_kin_interference', content='Omen', encounter='Kin', actor='Kin', event='readies', ability='Interference', message='HEAVY DARK AOE + DISPEL + KNOCKBACK!', severity='danger', sound='warning.wav', verified=true, prediction='reactive', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Kin' },

        -- Ou executes the five preceding bosses' signature mechanics at fixed HP gates.
        { id='omen_ou_ebullient_nullification', content='Omen', encounter='Ou', actor='Ou', event='readies', ability='Ebullient Nullification', message='95%: BUFF ABSORB IN 20\'!\nLIMIT BUFFS', severity='critical', sound='alarm.wav', verified=true, prediction='scripted', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Ou' },
        { id='omen_ou_unfaltering_bravado', content='Omen', encounter='Ou', actor='Ou', event='readies', ability='Unfaltering Bravado', message='75%: STACK IN FRONT!\n10,000 CONE DAMAGE SPLIT BETWEEN TARGETS', severity='critical', sound='alarm.wav', verified=true, prediction='scripted', target_shape='cone', source='https://www.bg-wiki.com/ffxi/Ou' },
        { id='omen_ou_chainspell', content='Omen', encounter='Ou', actor='Ou', event='uses', ability='Chainspell', message='65%: CHAIN-SPELL ACTIVE!\nPREPARE FOR RAPID MAGIC', severity='danger', sound='warning.wav', verified=true, prediction='scripted', target_shape='self', source='https://www.bg-wiki.com/ffxi/Ou' },
        { id='omen_ou_dancing_fullers', content='Omen', encounter='Ou', actor='Ou', event='readies', ability='Dancing Fullers', message='60%: MOVE OUTSIDE 10\' - STAY WITHIN 20\'!', severity='critical', sound='alarm.wav', verified=true, prediction='scripted', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Ou' },
        { id='omen_ou_zero_hour', content='Omen', encounter='Ou', actor='Ou', event='readies', ability='Zero Hour', message='45%: HP-CRITICAL AOE + HATE RESET!', severity='critical', sound='healme.wav', verified=true, prediction='scripted', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Ou' },
        { id='omen_ou_target', content='Omen', encounter='Ou', actor='Ou', event='readies', ability='Target', message='30%: TARGET LOCK ACTIVE!\nTARGET: {target}\nSHIFT HATE OR USE COVER', severity='critical', sound='alarm.wav', verified=true, prediction='scripted', target_shape='single', source='https://www.bg-wiki.com/ffxi/Ou' },
        { id='omen_ou_eleventh_dimension', content='Omen', encounter='Ou', actor='Ou', event='readies', ability='Eleventh Dimension', message='THREE-MINUTE TERROR INCOMING!\nTARGET LOCK WAS NOT BROKEN', severity='critical', sound='alarm.wav', verified=true, prediction='scripted', target_shape='single', source='https://www.bg-wiki.com/ffxi/Ou' },
        { id='omen_ou_gardez', content='Omen', encounter='Ou', actor='Ou', event='readies', ability='Gardez', message='15%: 20\' AOE TERROR INCOMING!', severity='critical', sound='alarm.wav', verified=true, prediction='scripted', target_shape='radial', source='https://www.bg-wiki.com/ffxi/Ou' },
        { id='omen_ou_prophylaxis', content='Omen', encounter='Ou', actor='Ou', event='uses', ability='Prophylaxis', message='KILL OU WITHIN 30 SECONDS!\nFULL-HP FIGHT RESET IF TIMER EXPIRES', severity='critical', sound='alarm.wav', duration=8.0, verified=true, prediction='scripted', target_shape='self', source='https://www.bg-wiki.com/ffxi/Ou' },
    },
}
