-- Generic mechanics that behave consistently enough to be useful without a
-- monster-specific override. Encounter-specific rules should take priority.

return {
    ability_rules = {
        {
            id = 'generic_discoid',
            content = 'Generic',
            encounter = 'Shared Mechanics',
            actor = nil,
            event = 'readies',
            ability = 'Discoid',
            message = "DISCOID!\n>10' FROM TARGET OR STACK TO SPLIT",
            severity = 'danger',
            sound = 'warning.wav',
            verified = true,
            source = 'https://www.bg-wiki.com/ffxi/Zhayolm_Remnants_Guide',
            notes = 'Discoid is targeted AoE fixed damage split among targets in roughly 10 yalms of its target. The exact best response is encounter/target dependent.',
        },
    },
    state_rules = {},
};
