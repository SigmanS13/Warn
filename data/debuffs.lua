--[[
    Warn global debuff definitions.
    Created by Sigman

    This file is intentionally data-driven.  The core addon does not need a new
    subsystem for every enfeeble; add or refine a definition here instead.

    Alert policy:
      always            - loss is important even if the current player cannot reapply it.
      smart             - by default, alert only when the current player has a usable counter.
                          Users can override this per status in /warn -> Debuffs -> Advanced.

    "effect_names" are also used to recognize common FFXI log forms such as:
      <mob> receives the effect of <effect>.
      <mob>'s <effect> effect wears off.
]]

return {
    version = 1,

    statuses = {
        {
            id = 'sleep',
            name = 'Sleep',
            category = 'Crowd Control',
            recommended = true,
            default_enabled = true,
            alert_policy = 'always',
            center_alert = true,
            sound = 'alarm.wav',
            loss_label = 'WOKE UP!',
            action = 'RE-SLEEP / CONTROL IT!',
            multi_loss_label = 'MONSTERS WOKE UP!',
            multi_action = 'RE-SLEEP / CONTROL THEM!',
            effect_names = { 'Sleep', 'Sleep II', 'Lullaby' },
            gain_fragments = {
                ' falls asleep',
                ' is asleep',
                ' is put to sleep',
            },
            loss_fragments = {
                ' wakes up',
                ' is no longer asleep',
                ' awakens',
            },
            counters = {
                { type = 'spell', name = 'Sleep II', label = 'CAST SLEEP II!' },
                { type = 'spell', name = 'Sleep', label = 'CAST SLEEP!' },
                { type = 'spell', name = 'Sleepga II', label = 'CAST SLEEPGA II!' },
                { type = 'spell', name = 'Sleepga', label = 'CAST SLEEPGA!' },
                { type = 'spell', name = 'Foe Lullaby II', label = 'USE FOE LULLABY II!' },
                { type = 'spell', name = 'Horde Lullaby II', label = 'USE HORDE LULLABY II!' },
                { type = 'spell', name = 'Foe Lullaby', label = 'USE FOE LULLABY!' },
                { type = 'spell', name = 'Horde Lullaby', label = 'USE HORDE LULLABY!' },
                { type = 'blu_spell', name = 'Dream Flower', label = 'CAST DREAM FLOWER!' },
                { type = 'blu_spell', name = 'Sheep Song', label = 'CAST SHEEP SONG!' },
                { type = 'blu_spell', name = 'Soporific', label = 'CAST SOPORIFIC!' },
                { type = 'blu_spell', name = 'Yawn', label = 'CAST YAWN!' },
            },
        },

        {
            id = 'petrify',
            name = 'Petrify',
            category = 'Crowd Control',
            recommended = true,
            default_enabled = true,
            alert_policy = 'always',
            center_alert = true,
            sound = 'alarm.wav',
            loss_label = 'PETRIFY WORE OFF!',
            action = 'RE-CONTROL / BE READY!',
            multi_loss_label = 'MONSTERS LOST PETRIFY!',
            multi_action = 'RE-CONTROL / BE READY!',
            effect_names = { 'Petrification', 'Petrify' },
            gain_fragments = {
                ' is petrified',
                ' becomes petrified',
                ' has been petrified',
            },
            loss_fragments = {
                ' is no longer petrified',
                ' recovers from petrification',
                ' recovers from petrify',
            },
            counters = {
                { type = 'spell', name = 'Break', label = 'CAST BREAK!' },
                { type = 'blu_spell', name = 'Entomb', label = 'CAST ENTOMB!' },
            },
        },

        {
            id = 'bind',
            name = 'Bind',
            category = 'Crowd Control',
            recommended = true,
            default_enabled = true,
            alert_policy = 'always',
            loss_label = 'BIND WORE OFF!',
            action = 'RE-BIND / CONTROL IT!',
            multi_loss_label = 'MONSTERS LOST BIND!',
            multi_action = 'RE-BIND / CONTROL THEM!',
            effect_names = { 'Bind' },
            gain_fragments = {
                ' is bound',
            },
            loss_fragments = {
                ' is no longer bound',
            },
            counters = {
                { type = 'spell', name = 'Bind', label = 'CAST BIND!' },
            },
        },

        {
            id = 'gravity',
            name = 'Gravity',
            category = 'Crowd Control',
            recommended = true,
            default_enabled = true,
            alert_policy = 'always',
            loss_label = 'GRAVITY WORE OFF!',
            action = 'REAPPLY GRAVITY / WATCH POSITION!',
            multi_loss_label = 'MONSTERS LOST GRAVITY!',
            multi_action = 'REAPPLY GRAVITY / WATCH POSITION!',
            effect_names = { 'Gravity', 'Weight' },
            gain_fragments = {
                ' is weighed down',
            },
            loss_fragments = {
                ' is no longer weighed down',
            },
            counters = {
                { type = 'spell', name = 'Gravity II', label = 'CAST GRAVITY II!' },
                { type = 'spell', name = 'Gravity', label = 'CAST GRAVITY!' },
                { type = 'blu_spell', name = 'Subduction', label = 'CAST SUBDUCTION!' },
            },
        },

        {
            id = 'silence',
            name = 'Silence',
            category = 'Maintenance',
            recommended = true,
            default_enabled = true,
            alert_policy = 'smart',
            loss_label = 'SILENCE WORE OFF!',
            action = 'REAPPLY SILENCE!',
            multi_loss_label = 'SILENCE WORE OFF!',
            multi_action = 'REAPPLY SILENCE!',
            effect_names = { 'Silence' },
            gain_fragments = {
                ' is silenced',
            },
            loss_fragments = {
                ' is no longer silenced',
            },
            counters = {
                { type = 'spell', name = 'Silence', label = 'CAST SILENCE!' },
                { type = 'blu_spell', name = 'Silent Storm', label = 'CAST SILENT STORM!' },
                { type = 'blu_spell', name = 'Chaotic Eye', label = 'CAST CHAOTIC EYE!' },
            },
        },

        {
            id = 'paralyze',
            name = 'Paralyze',
            category = 'Maintenance',
            recommended = true,
            default_enabled = true,
            alert_policy = 'smart',
            loss_label = 'PARALYZE WORE OFF!',
            action = 'REAPPLY PARALYZE!',
            effect_names = { 'Paralysis', 'Paralyze' },
            gain_fragments = {
                ' is paralyzed',
            },
            loss_fragments = {
                ' is no longer paralyzed',
            },
            counters = {
                { type = 'spell', name = 'Paralyze II', label = 'CAST PARALYZE II!' },
                { type = 'spell', name = 'Paralyze', label = 'CAST PARALYZE!' },
            },
        },

        {
            id = 'slow',
            name = 'Slow',
            category = 'Maintenance',
            recommended = true,
            default_enabled = true,
            alert_policy = 'smart',
            loss_label = 'SLOW WORE OFF!',
            action = 'REAPPLY SLOW!',
            effect_names = { 'Slow' },
            gain_fragments = {
                ' is slowed',
            },
            loss_fragments = {
                ' is no longer slowed',
            },
            counters = {
                { type = 'spell', name = 'Slow II', label = 'CAST SLOW II!' },
                { type = 'spell', name = 'Slow', label = 'CAST SLOW!' },
            },
        },

        {
            id = 'addle',
            name = 'Addle',
            category = 'Maintenance',
            recommended = true,
            default_enabled = true,
            alert_policy = 'smart',
            loss_label = 'ADDLE WORE OFF!',
            action = 'REAPPLY ADDLE!',
            effect_names = { 'Addle' },
            gain_fragments = {
                ' is addled',
            },
            loss_fragments = {
                ' is no longer addled',
            },
            counters = {
                { type = 'spell', name = 'Addle II', label = 'CAST ADDLE II!' },
                { type = 'spell', name = 'Addle', label = 'CAST ADDLE!' },
            },
        },

        {
            id = 'blind',
            name = 'Blind',
            category = 'Maintenance',
            recommended = true,
            default_enabled = true,
            alert_policy = 'smart',
            loss_label = 'BLIND WORE OFF!',
            action = 'REAPPLY BLIND!',
            effect_names = { 'Blindness', 'Blind' },
            gain_fragments = {
                ' is blinded',
            },
            loss_fragments = {
                ' is no longer blinded',
            },
            counters = {
                { type = 'spell', name = 'Blind II', label = 'CAST BLIND II!' },
                { type = 'spell', name = 'Blind', label = 'CAST BLIND!' },
            },
        },

        {
            id = 'poison',
            name = 'Poison',
            category = 'Damage over Time',
            recommended = false,
            default_enabled = false,
            alert_policy = 'smart',
            loss_label = 'POISON WORE OFF!',
            action = 'REAPPLY POISON!',
            effect_names = { 'Poison' },
            gain_fragments = {
                ' is poisoned',
            },
            loss_fragments = {
                ' is no longer poisoned',
            },
            counters = {
                { type = 'spell', name = 'Poison II', label = 'CAST POISON II!' },
                { type = 'spell', name = 'Poison', label = 'CAST POISON!' },
            },
        },

        -- The following maintenance effects are included for advanced users. Their
        -- common "<effect> effect wears off" forms are recognized, but they are not
        -- enabled by the Recommended preset until more live-log variants are collected.
        {
            id = 'dia',
            name = 'Dia',
            category = 'Advanced Maintenance',
            recommended = false,
            default_enabled = false,
            alert_policy = 'smart',
            experimental = true,
            loss_label = 'DIA WORE OFF!',
            action = 'REAPPLY DIA!',
            effect_names = { 'Dia III', 'Dia II', 'Dia' },
            counters = {
                { type = 'spell', name = 'Dia III', label = 'CAST DIA III!' },
                { type = 'spell', name = 'Dia II', label = 'CAST DIA II!' },
                { type = 'spell', name = 'Dia', label = 'CAST DIA!' },
            },
        },

        {
            id = 'bio',
            name = 'Bio',
            category = 'Advanced Maintenance',
            recommended = false,
            default_enabled = false,
            alert_policy = 'smart',
            experimental = true,
            loss_label = 'BIO WORE OFF!',
            action = 'REAPPLY BIO!',
            effect_names = { 'Bio III', 'Bio II', 'Bio' },
            counters = {
                { type = 'spell', name = 'Bio III', label = 'CAST BIO III!' },
                { type = 'spell', name = 'Bio II', label = 'CAST BIO II!' },
                { type = 'spell', name = 'Bio', label = 'CAST BIO!' },
            },
        },

        {
            id = 'elegy',
            name = 'Elegy',
            category = 'Advanced Maintenance',
            recommended = false,
            default_enabled = false,
            alert_policy = 'smart',
            experimental = true,
            loss_label = 'ELEGY WORE OFF!',
            action = 'REAPPLY ELEGY!',
            effect_names = { 'Carnage Elegy', 'Battlefield Elegy', 'Elegy' },
            counters = {
                { type = 'spell', name = 'Carnage Elegy', label = 'USE CARNAGE ELEGY!' },
                { type = 'spell', name = 'Battlefield Elegy', label = 'USE BATTLEFIELD ELEGY!' },
            },
        },

        {
            id = 'distract',
            name = 'Distract',
            category = 'Advanced Maintenance',
            recommended = false,
            default_enabled = false,
            alert_policy = 'smart',
            experimental = true,
            loss_label = 'DISTRACT WORE OFF!',
            action = 'REAPPLY DISTRACT!',
            effect_names = { 'Distract III', 'Distract II', 'Distract' },
            counters = {
                { type = 'spell', name = 'Distract III', label = 'CAST DISTRACT III!' },
                { type = 'spell', name = 'Distract II', label = 'CAST DISTRACT II!' },
                { type = 'spell', name = 'Distract', label = 'CAST DISTRACT!' },
            },
        },

        {
            id = 'frazzle',
            name = 'Frazzle',
            category = 'Advanced Maintenance',
            recommended = false,
            default_enabled = false,
            alert_policy = 'smart',
            experimental = true,
            loss_label = 'FRAZZLE WORE OFF!',
            action = 'REAPPLY FRAZZLE!',
            effect_names = { 'Frazzle III', 'Frazzle II', 'Frazzle' },
            counters = {
                { type = 'spell', name = 'Frazzle III', label = 'CAST FRAZZLE III!' },
                { type = 'spell', name = 'Frazzle II', label = 'CAST FRAZZLE II!' },
                { type = 'spell', name = 'Frazzle', label = 'CAST FRAZZLE!' },
            },
        },
    },
};
