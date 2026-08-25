# Changelog

## 3.1.2
- Fixed all dashboard dropdowns and other popup controls losing focus by focusing Warn only once when it opens instead of on every rendered frame.
- Fixed XIUI integration commands being truncated to the single token `local`, which caused a Lua `'<name>' expected near '<eof>'` error when opening or closing Warn.

## 3.1.1
- Fixed XIUI hotbars briefly hiding and then reappearing over Warn by targeting XIUI's exact cached `modules.hotbar.init` instance for both suppression and restoration.
- Changed the fresh-install controller toggle chord to L3 + R3 across supported controller layouts; existing saved chord selections remain unchanged.
- Added a 350 ms chord window so stick clicks pressed too far apart do not accidentally open or close the dashboard.

## 3.1.0
- Replaced the ineffective XIUI z-order workaround with dashboard lifecycle integration: opening Warn temporarily hides only XIUI's hotbar/crossbar module through Ashita's runtime addon interface, and every close path restores XIUI's original runtime function and prior visibility.
- Added a default-enabled **Hide XIUI Hotbars While Warn Is Open** option without modifying XIUI or requiring a custom XIUI installation.
- Added configurable controller chords for opening and closing Warn across XInput, PlayStation DirectInput and Switch Pro DirectInput layouts.
- Corrected XInput navigation to Ashita's current button identifiers and made B/Circle the consistent controller close action.
- Increased the fresh-install dashboard baseline from 1320×1080 to 1480×1160 logical pixels with a 32-pixel display safety margin.

## 3.0.9
- Added a default-enabled **Keep Warn Dashboard Above Other Addons** option under Appearance. Warn requests foreground focus while its dashboard is open; the option can be disabled when another addon's controls need to appear over it.
- Increased the fresh-install dashboard baseline from 1160×820 to 1320×1080 logical pixels, producing approximately the large layout shown at automatic 1440p scaling while remaining capped to the current display with a 40-pixel safety margin.
- Changed starter sizing to `FirstUseEver`, preserving user-resized ImGui dimensions on later addon and game launches instead of reapplying the default every session.

## 3.0.8
- Fixed Encounter Intelligence centering by measuring against each active ImGui child window's real screen position and width instead of the unreliable content-region wrapper and its 800-pixel fallback.
- Allowed the Encounter Intelligence scroll pane to fill the dashboard content region and reduced only the non-scrolling outer dashboard reserve, moving its scrollbar substantially farther right while preserving the 42/56-pixel separation between nested browser scrollbars.

## 3.0.7
- Rebuilt the Encounters dashboard around the approved edited mockup: centered three-line header hierarchy, centered main tabs, and centered Encounter Intelligence copy.
- Reworked Current Encounter into a taller non-nested-scroll summary with centered encounter state and a shared lower-right Auto Detect / Choose Manually action row.
- Moved Collapse All, Expand All, and Show Indexed-Only Groups into the lower-right footer of the encounter browser.
- Moved encounter search beneath the complete browser window, immediately above Live Encounter Tools.
- Added a bordered browser shell and a larger visual gap between the category and mechanic panes while retaining the expanded scrollbar gutters from v3.0.6.

## 3.0.6
- Rebuilt the potion and harp textures with genuine full-canvas alpha instead of a partially transparent image-generation checkerboard, so all four Roles icons now render without square backgrounds in Ashita.
- Increased the minimum scrollbar gutter from roughly 14 pixels at 1080p to 42 pixels and applied it consistently to the current-encounter panel, manual results, encounter browser, rule list, and dashboard content layers.

## 3.0.5
- Replaced the small procedural role glyphs with sharp, dedicated shield, rounded potion, bow, and harp texture assets for Tank, Primary Healer, Damage Dealer, and Support.
- Reworked the healer icon around a classic rounded potion silhouette: a preserved ivory stopper, rounded shoulders and base, dark indigo upper glass, and a clearly visible two-thirds-full ivory-gold potion.
- Increased the minimum on-screen role-icon size for 1080p while retaining scale-aware sizing at 1440p and custom UI scales.
- Made the icon itself a clickable extension of its role checkbox and retained lightweight line-art fallbacks if a theme omits an asset.
- Added theme-level role-icon overrides under `themes/<theme>/roles/` so future themes can replace the four icons without changing Warn's Lua code.

## 3.0.4
- Hid the redundant native ImGui title bar and its red stock-theme strip; Warn now relies on its custom tactical header and close button.
- Centered the Warn title/subtitle block and centered each tab description within the space beside the main tab buttons.
- Removed the unnecessary outer dashboard scrollbar and added scaled right-side gutters between the Encounters view's nested scrolling panes.

## 3.0.3
- Fixed the LuaJIT `main function has more than 200 local variables` load failure introduced in v3.0.2.
- Extracted native WAV discovery, Windows playback, and process-session detection into `data/sound_runtime.lua` without changing the sound settings or alert behavior.
- Consolidated GUI-only helpers behind one internal namespace, reducing Warn's top-level local declarations from approximately 220 to 189 and leaving room for future development.
- Added a full-main-chunk compilation regression so syntax-only parsing and isolated module tests can no longer miss Lua's function-local limit.
- All **61 Lua files parse cleanly** and all **22 test suites pass**, including complete `warn.lua` compilation.

## 3.0.2
- Added an optional first-GUI-open cue under **Options → Sound**, defaulting to `firstopen.wav`. The selected cue is consumed once per FFXI process, so closing/reopening Warn or reloading the addon cannot replay it during the same game launch.
- Added an independent first-open sound selector and manual test button. Missing custom filenames remain visible in the selector instead of being silently replaced.
- Bundled `firstopen.wav` and `healme.wav`, and added all newly supplied WAV files to the compatibility fallback scan.
- Routed 22 verified player-healing mechanics to `healme.wav`, including HP-to-1/10%, major HP cuts, critical drains, and explicit healer/recovery calls.
- Preserved semantic exclusions: enemy self-heals, Zombie/stop-healing mechanics, and commands where “heal” means entering the `/heal` stance retain their original alert sounds.
- Added regression coverage for the session sound gate and the healing-rule classification.
- All **59 Lua files parse cleanly** and all **21 test suites pass**.

## 3.0.1
- Added centralized notification burst protection for AoE-heavy events. Rapid repeats of the same rule share one card and one sound, while distinct events enter a small priority-aware queue instead of repeatedly overwriting the live alert.
- Capped the pending notification queue at four by default, capped recent deduplication history, and expire queued alerts after six seconds so bursts cannot create unbounded memory growth or a long procession of stale instructions.
- Critical alerts preempt Important/Danger cards. Equal- or lower-priority events wait without playing sound until actually shown; excess routine events are discarded safely.
- Added independent deduplication and a 64-event hard cap to the global debuff prewarning/loss batches. The existing action parser continues to reject implausible packets over 64 targets or 16 results per target.
- Added configurable **Repeat Suppression** and **Maximum Queued Alerts** controls plus live suppression/drop telemetry under **Options → Alerts**.
- Added screen-aware warning-card layout presets under **Options → Appearance**: all nine screen regions, **Center Horizontally**, and **Center Vertically**. Presets remain aligned across scale/resolution changes, while dragging or exact X/Y entry switches to Custom placement.
- Critical cards now respect the selected layout instead of being forced over the upper center, while retaining their full screen-edge awareness effect.
- Added burst-manager regression coverage. All **56 Lua files parse cleanly** and all **19 test suites pass**.

## 3.0.0
- Added the automatic **Active Encounter** system. Warn now activates a curated profile from verified hostile entity names, upgrades it to confirmed when a matching action is observed, and never treats catalog-only or unknown data as an alert source.
- Added a GUI-first **Current Encounter** card with confidence/evidence labels, the most urgent verified mechanics, role- and capability-aware available responses, one-click browser focus, manual selection, and an explicit indexed-only state.
- Expanded the compact tactical HUD to show the active encounter and only its highest-priority verified mechanics and currently available assigned actions, alongside existing timers and encounter objectives.
- Added encounter lifecycle handling: zone changes reset the profile immediately, automatic encounters end after a configurable absence grace period, switching encounters clears stale specialized runtime state, and manual profiles remain stable until cleared or zoning.
- Scoped duplicate action names and state rules to the active encounter. Ambiguous evidence is surfaced for manual selection instead of using the first database match, reducing cross-content false alerts.
- Linked unknown hostile actions to the current encounter in local Learning data and added a session-only unverified-observation view. These observations remain backstage and cannot generate automatic warnings.
- Reused Warn's existing entity-map pass for detection rather than adding another continuous scan. Automatic detection, HUD visibility, and encounter-end grace are configurable under **Options → Alerts**.
- Added a pure detector/lifecycle module and real-database regression coverage. All **54 Lua files parse cleanly** and all **18 test suites pass**. The bundled rule database remains **490 ability/spell rules, 29 encounter-state rules, and 512 indexed encounter entries**.

## 2.12.0
- Added 39 major Abyssea encounters across all nine zones, with 26 verified alerts for 11 high-value bosses. Coverage includes absorption modes, Charm, Doom/Zombie, HP-to-1 and enmity resets, Petrification gazes, lethal conal attacks, and dispel/cleanse responses.
- Added a 42-entry Missions & BCNMs index spanning nation missions, every expansion story, add-on scenarios, and classic orb battlefields. New direct rules cover Ancient Vows, Darkness Named, Flames for the Dead, original Alexander, and Up in Arms; existing actor-based high-tier rules continue to recognize shared mission bosses at runtime without duplicate alerts.
- Expanded Alluvion Skirmish from six to 20 action rules and from two to four state rules. All four Rala Mistmaws, Balamor's Adumbration, Windrender objectives, and Living Cairn continuation guidance now have verified coverage.
- Corrected Balamor's Adumbration from the Yorcia defense group to the Rala/Cirdas bonus-floor group.
- Changed fresh-install sound defaults to enabled with `msg.wav`. Existing saved sound preferences are preserved, all WAV files in `sounds` remain selectable, and the expanded fallback scan now includes the newly bundled voice/effect files.
- Added Abyssea, Missions/BCNMs, and expanded Alluvion regression coverage. The bundled database now contains **490 ability/spell rules, 29 encounter-state rules, and 512 indexed encounter entries**.

## 2.11.0
- Added a reusable, evidence-gated objective tracker for encounter mechanics with configurable evidence type, element, threshold, cycle, progress, and explicit completion certainty.
- Added Ongo's Crashing Thunder objective: Warn tracks the first-cycle two and later-cycle three Earth Magic Bursts from completed action packets, keeps Fetters / Shock active until the blue proc is confirmed, and provides a manual confirmation fallback.
- Migrated Aminon's six elemental modes to the reusable tracker. Completed matching elemental damage advances a visible five-hit sequence; a damaging wrong-element spell resets it, and the existing mode-age / accumulated-DT estimate remains available.
- Added an Escha - Ru'Aun-scoped Kirin pre-transition warning at 52% HP plus a Kouryu-presence fallback that reports the full enmity reset, initial popper target, and Terror preparation.
- Reworked Dynamis - Divergence proximity into pulse-aware evidence. Warn shows distance and a critical edge/card cue only after an Elemental Circle actually completes a pulse within the documented danger radius; it does not run a permanent GPS-style overlay.
- Kept Bumba's mode handling specialized and manually authoritative until stable retail packet evidence exists.
- Added objective, Ongo, Aminon, Circle-pulse, and Kirin/Kouryu regression coverage. The bundled database now contains **445 ability/spell rules, 26 encounter-state rules, and 430 indexed encounter entries**.

## 2.10.0
- Replaced the first-target-only `0x028` reader with a complete variable-length parser that retains every target, every action result, and optional additional/spikes effects while preserving the original compatibility fields.
- Added a read-only `0x029` status-observation parser as the foundation for per-party-member encounter triage.
- Added Shinryu wing-state intelligence. Meteor confirms wings spread and the dangerous action-absorption stance; Comet confirms wings down and the damage window. Repeated spells do not spam duplicate stance alerts.
- Added Supernova party Doom triage. Warn captures every exposed target from the completed TP-move packet, labels unconfirmed members **CHECK DOOM**, confirms Doom from status evidence, records clears, and displays the observed ten-count window in the tactical HUD.
- Kept wing-cycle timing honest: the documented three-minute cycle is shown as encounter context, but no hard countdown begins from a later Meteor/Comet cast because that does not prove the exact model-transition time.
- Added parser and Shinryu runtime regressions. The bundled database now contains **445 ability/spell rules, 24 encounter-state rules, and 430 indexed encounter entries**.

## 2.9.0
- Added target-aware contextual alerts. Ou's 30% Target mechanic now names the affected player when packet target identity is available, and Ou's missing 65% Chainspell warning has been added.
- Added a data-driven verified timer runtime distinct from uncertain learned readiness windows. Aminon's observed Bane of Tartarus now starts a four-minute countdown with a 15-second prewarning.
- Added live Aminon elemental-mode tracking with the required counter-element, mode age, and a clearly scoped estimate of damage reduction accumulated during the current unprocced mode.
- Added Bumba V0-V15, V20, and V25 fetter timers, a manual absorbed-element selector, a 60-second element-check cue, and an opt-in in-memory packet signature recorder for validating future automatic dust-color recognition.
- Added an optional compact tactical HUD with independent position and opacity settings.
- Added a live Dynamis - Divergence Elemental Circle checklist. Clear counts and estimated Disjoined-boss damage reduction appear only after all eight Circles have been observed; partial visibility remains explicitly uncertain.
- Added pure regression coverage for verified timers, Aminon state, Bumba state, Circle certainty, and packet-signature deduplication. The bundled database now contains **443 ability/spell rules, 24 encounter-state rules, and 430 indexed encounter entries**.

## 2.8.0
- Added a 21-entry original and Alluvion Skirmish index with six verified action alerts and two encounter-state warnings. Sparsely documented Mistmaws remain safely indexed-only.
- Added the complete 56-NM Unity Wanted roster, grouped by content level and Wanted category, plus 29 high-impact alerts and a live Goblin Mine proximity warning.
- Added all five Vagary mega bosses with 28 verified alerts and one Putraxia preparation warning. Perfidien and Plouton now surface their documented elemental-response modes without presenting them as timers.
- Extended `/warn coverage` to report Skirmish, Unity Wanted, and Vagary independently.
- Added dedicated regression coverage for the three new modules. The bundled database now contains **442 ability/spell rules, 24 encounter-state rules, and 430 indexed encounter entries**.

## 2.7.0
- Added a 26-entry classic Dynamis progression-boss catalog covering all ten zones and their principal/Arch encounters, with 11 verified high-impact alerts.
- Added all twelve Wave 1-3 Dynamis - Divergence bosses plus Aurix. Five action alerts cover the four Wave 2 bosses, and four state alerts explain the elemental-circle requirement when a Disjoined Wave 3 boss appears.
- Added the complete nine-encounter Sinister Reign roster and 18 verified alerts spanning its three waves, including scripted follow-ups and Arciela's Naakual mechanics.
- Expanded Geas Fete from 24 to 34 verified alerts with Zi'Tah HELMs, the four Ru'Aun Heavenly Beasts, and Kirin/Kouryu.
- Added alternate actor-name matching so one verified rule can safely cover named forms of the same encounter, such as the eight Dynamis-Tavnazia Diabolos variants and the Zi'Tah Pixie trio.
- Split `/warn coverage` across readable lines as the encounter database grows. The bundled database now contains **379 ability/spell rules, 20 encounter-state rules, and 348 indexed encounter entries**.

## 2.6.2
- Fixed an Ashita/SugarMath compatibility crash in the responsive encounter-pane sizing code. Numeric and named ImGui vector layouts are now probed independently inside protected calls, so unsupported `.x` lookup behavior cannot escape into `d3d_present`.

## 2.6.1
- Rebuilt the encounter-category pane with persistent per-content collapse controls plus **Collapse All** and **Expand All** actions.
- Added verified-alert counts to content and group labels so populated sections can be identified at a glance.
- Hidden catalog-only research groups by default. **Show Indexed-Only Groups** reveals them with an explicit label and a clear research-only empty state rather than an apparently broken results panel.
- Made the category pane width responsive, widened it substantially at normal window sizes, and separated the search label from its input so neither is clipped.
- Wrapped long encounter titles, metadata, messages, and rule IDs in the detail pane; severity now occupies its own row to preserve the full prediction and target information.
- Updated controller category traversal to follow the visible verified-group filter and automatically expand the selected content family.
- Added a pure encounter-browser metadata helper and regression coverage for alert counts, indexed-only filtering, labels, and empty-state wording.

## 2.6.0
- Added the complete **Sortie NM and boss index**: eight sector NMs, four ground-floor bosses, four basement bosses, and Aminon.
- Added 44 verified Sortie action alerts and two encounter-state warnings. Coverage includes elemental response changes, water absorption, Taint escalation, Setting the Stage, Vivisection, Cesspool, and Aminon's lethal/dispelling mechanics.
- Added a complete named **Odyssey** catalog: 16 Sheol A NMs, 27 Sheol B NMs, 7 Sheol C NMs, the shared Mimic hazard, and all 17 Sheol Gaol bosses.
- Added 24 verified Odyssey alerts for Mimics and every Atonement 3–4 boss: Xevioso, Ngai, Kalunga, Ongo, Mboze, Arebati, and Bumba.
- Audited Omen and retained its existing complete 9-boss, 27-rule module. Floor-objective progress remains outside the alert database until it can be derived reliably without noisy inference.
- Extended `/warn rules` and `/warn coverage` summaries to report Sortie and Odyssey counts.
- Added dedicated Sortie and Odyssey regression suites. The bundled database now contains **335 ability/spell rules, 16 encounter-state rules, and 300 indexed encounter entries**.

## 2.5.0
- Expanded historical **Ambuscade Volume 2** from 23 to **54 actionable encounter families**. The new history module adds 27 verified ability alerts and 5 state alerts across 31 previously catalog-only encounters.
- Kept 13 sparsely documented historical Volume 2 encounters indexed but non-actionable rather than inventing mechanics or responses.
- Completed direct **High-Tier Mission Battlefield** coverage with Head Wind and Legacy of the Lost. All 30 indexed HTMB categories now have direct rules or, for Divine Might, inherited Ark Angel actor rules.
- Added the complete **Geas Fete Aeonic route** as 85 indexed encounters: 25 in Escha - Zi'Tah, 32 in Escha - Ru'Aun, and 28 in Reisenjima.
- Added 24 verified high-impact Geas Fete alerts for Warder of Courage and the seven Reisenjima HELMs: Albumen, Erinys, Onychophora, Schah, Teles, Vinipata, and Zerde.
- Added regression checks for historical Ambuscade coverage, Geas Fete catalog completeness, verification metadata, role-aware HTMB counters, and database-wide unique IDs.
- The bundled database now contains **267 ability/spell rules, 14 encounter-state rules, and 215 indexed encounter entries**.

## 2.4.0
- Added the first complete **Omen** content module: Glassy Craver, Glassy Gorger, Glassy Thinker, Fu, Kyou, Kei, Gin, Kin, and Ou.
- Added 27 verified Omen alerts covering documented reactive mechanics and fixed HP-gated sequences, including Pain Sync, Dancing Fullers, Unfaltering Bravado, Target / Eleventh Dimension, and Prophylaxis.
- Expanded **The Shadow Lord Battle** from two rules to six: Damning Edict, Swath of Silence, Giga Slash, Bowels of Agony, Implosion, and Firaja.
- Moved Shadow Lord's immunity-switch alerts to the earlier packet-visible ready event and added packet-level coverage for Implosion, whose name is not printed in the normal battle log.
- Added four verified **Puppet in Peril** alerts for Lancelord Gaheel Ja: Burning Memories, Blazing Angon, Granite Skin, and Batterhorn.
- Kept Burning Memories' Stun instruction assignment-aware: the critical mechanic warning reaches everyone, while the action prompt appears only for an assigned, currently capable interrupter.
- Added database-wide unique-ID and minimum-coverage checks. The bundled database now contains **211 ability/spell rules, 9 encounter-state rules, and 130 indexed encounter entries**.

## 2.3.2
- Finalized the approved Roles icon set as sharp native vector glyphs: shield for Tank, potion for Primary Healer, single bow and arrow for Damage Dealer, and harp for Support.
- Simplified the Damage Dealer silhouette to one curved bow, taut string, and one arrow so it remains legible at the addon's normal 24-pixel icon size.
- Unified all four glyphs with Warn's brass outlines, indigo structure, and restrained blue highlights while preserving existing saved role profiles.

## 2.3.1
- Reworked the Roles glyphs from the supplied visual references as native Warn vector art rather than importing their source pixels.
- Tank now uses a sculpted shield; Primary Healer uses a diagonal syringe; Damage Dealer uses a crossed sword and magical staff; Support uses overlapping dice.
- Reduced the medical cross on Support to a small rear-die mark and added five unmistakable pips to the foreground die.
- Renamed the visible **Damage** role to **Damage Dealer** without changing its saved profile identifier.

## 2.3.0
- Rebuilt live warning cards around an ornate Vana'diel frame with a stepped silhouette, twin brass rails, engraved corner strokes, and center/side diamond details.
- Added a compact Warn crest, stronger title hierarchy, and balanced severity/prediction labels to distinguish alerts from stock ImGui panels.
- Added a restrained severity-colored lifetime rail so each notification communicates its remaining screen time without becoming a conventional generic progress card.
- Preserved warning opacity, scale, position, Reduced Motion, critical edge illumination, and full-card preview dragging.
- Kept the new decoration texture-free and draw-list based so warning rendering remains lightweight during combat.

## 2.2.0
- Added automatic dual-layout parsing for incoming action packet `0x028`: retail / XiPackets and the legacy target-count header commonly used by SimpleLog and DSP-based servers.
- Added an **Action Packet Layout** override under **Options → Alerts**, plus the detected layout in packet diagnostics.
- Fixed Odin Prime's Dread Spikes rule to alert at packet-visible cast start instead of depending on the completed-cast text line.
- Promoted Dread Spikes to Critical with an immediate stop-attacking warning; Dispel instructions remain role- and capability-aware.
- Expanded verified **A Stygian Pact** coverage for Ofnir, Gagnrath, Geirrothr, Sanngetall, Yggr, Kaustra, and Silencega.
- Renamed **Responsibilities** to **Roles** and separated the four party roles—Tank, Primary Healer, Damage, and Support—from Cleanse, Interrupt, and Crowd Control assignments.
- Added lightweight brass vector icons for Tank, Primary Healer, Damage, and Support without introducing extra texture files.

## 2.1.3
- Changed the Appearance warning-card preview from an automatic persistent element to an explicit **Show / Hide Warning Preview** control.
- The preview now closes automatically when leaving Appearance or closing the dashboard, so it cannot masquerade as a stuck live warning.
- Added a one-click **Reset Warning Position** control.
- Reworked preview repositioning with full-card mouse capture so fast dragging does not lose the preview.

## 2.1.2
- Reworked the W launcher as a full-surface interactive control so it retains mouse capture during fast movement instead of depending on continuous image hover.
- Removed the Ctrl-drag requirement: drag normally to reposition, or click without dragging to open or close Warn.
- Added a small movement threshold so ordinary clicks do not accidentally reposition the launcher.

## 2.1.1
- Fixed the dashboard failing during `d3d_present` on Ashita v4 builds that do not expose the optional `imgui.SetWindowFontScale` helper.
- Font scaling is now capability-checked and gracefully falls back to the user's normal ImGui font while preserving panel, launcher, alert-card, and resolution scaling.

## 2.1.0
- Replaced the stock configuration shell with a custom Vana'diel tactical dashboard using deep indigo panels, brass detailing, engraved corner accents, and two primary **Encounters / Options** controls.
- Added a cleaned transparent brass-and-indigo **W** medallion as a clickable, draggable, and hideable launcher.
- Added automatic display scaling plus explicit 1440p, 1080p, and custom interface-scale presets.
- Rebuilt live alerts as severity-aware cards for **Important**, **Danger**, and **Critical** mechanics.
- Added independently configurable warning-card opacity so message backgrounds can be reduced without dimming text or critical edge cues.
- Added an optional critical screen-edge illumination effect with a separate intensity control.
- Added Reduced Motion, warning-card scale, and draggable live-preview controls.
- Added scoped controller navigation for the dashboard: shoulder buttons change the primary area, D-pad navigation browses the current area, and the layout-specific back button closes Warn.
- Added a data-only community theme override path for palette and launcher customization without executing third-party Lua.
- Added an inactive portrait-provider seam for a future encounter-art update; no empty portrait space or runtime downloading is introduced now.

## 2.0.0
- Redesigned the GUI around two top-level areas: **Encounters** and **Options**.
- Added a metadata-driven encounter browser whose categories come from content/group/encounter data rather than Lua filenames.
- Moved the manual ability list into a collapsed **Custom Watches (Advanced)** section.
- Populates Custom Watches from Ashita's local monster-ability resources, with `data/abilities.txt` retained only as a compatibility fallback.
- Added remembered responsibility profiles for each character and main job/subjob combination.
- Separates party responsibility from mechanical capability: action prompts require both an enabled responsibility and a currently usable action.
- Critical factual mechanic warnings remain visible even when a role-specific action prompt is suppressed.
- Added passive incoming action-packet `0x028` recognition for monster-skill and spell starts, without packet modification or combat automation.
- Unknown abilities feed local Learning evidence but never create automatic alerts; explicit Custom Watches remain the only manual exception.
- Reframed learned TP repetition as uncertain readiness windows using observed minimum/maximum intervals rather than countdown timers.
- Added optional rule metadata for prediction model, target shape, audience, group, and counter responsibility.
- Added offline policy and packet-parser tests.

## 1.9.0
- Added a GUI-first **Database** tab for checking and installing community encounter-data updates.
- Added once-per-day automatic update checks when the Warn GUI opens; installation always requires explicit approval.
- Added a non-executable JSON community database format with strict field, type, size, URL and rule-count validation.
- Added SHA-256 verification for downloaded database bytes before installation.
- Uses Windows' native HTTPS stack so certificate validation follows the operating-system trust store.
- Restricted manifest database URLs to the official `SigmanS13/Warn` raw GitHub repository.
- Added automatic backup before installation and a GUI rollback button.
- Added stable-ID merging so reviewed community rules can add to or correct bundled rules without changing addon code.
- Kept personal settings, sound overrides and learned timer evidence separate from community updates.
- Added updater security and merge tests, including known SHA-256 vectors and malicious-data rejection cases.

## 1.8.0
- Added automatic local encounter-timer learning for repeated hostile actor + ability pairs.
- Added duplicate suppression so a `readies`/`uses` or `starts casting`/`casts` pair counts as one observation.
- Added confidence scoring based on repeat consistency and sample count; the default review threshold is three uses.
- Added a GUI-first **Learning** review queue with Approve, Keep Observing, Ignore, Restore and Forget actions.
- Learned candidates remain inactive until explicitly approved; Warn never turns unreviewed observations into live timers.
- Added approved personal-timer countdowns that start on the next observed use and become uncertain when overdue.
- Stored learned evidence separately from curated encounter rules and normal settings so database updates cannot overwrite it.
- Kept all learning data local; no observations are submitted automatically.

## 1.7.0
- Added estimated timers to the Global Debuff Engine.
- Tracked debuffs now show remaining time in the Debuffs tab and `/warn debuffs` output.
- Estimated expiry no longer removes tracked state; expired estimates become uncertain (`?`) until a real loss/removal signal arrives.
- Added pre-expire warnings for crowd-control effects before their estimated timer ends.
- Added global Debuffs options: `Show Estimated Durations`, `Warn Before Crowd Control Expires`, and a seconds-before-expiry slider.
- Added per-status Advanced options for estimated duration and pre-expire warnings.
- Added `/warn debuffs soon <status> [mob]` to test the pre-expire warning path.
- Updated `data/debuffs.lua` with baseline estimated durations for all shipped status definitions.

## 1.6.2
- Fixed live debuff-loss detection by parsing FFXI incoming packet 0x029 directly.
- Sleep/Petrify no longer depend on combat-log text wording or chat-filter visibility to alert when the client is sent the wear-off event.
- Packet detection uses exact target index/server id and the status-effect icon id, then routes through the existing center-screen popup + debuff sound system.
- Added packet resource-name resolution via Ashita's `buffs.names` resource table with verified numeric fallbacks for common enfeebles.
- Text-based debuff tracking remains as a fallback and for gain-state discovery.
- Added debug logging for recognized/unhandled 0x029 status-loss packets.


## 1.6.1
- Fixed global debuff gain/loss messages being silently discarded when the hostile entity-name cache was not ready or could not match formatted combat-log text.
- Sleep and Petrify loss now use a dedicated large center-screen critical alert overlay.
- Sleep/Petrify default to `alarm.wav`; per-status sound overrides, including explicit `None`, are still respected.
- Added a separate `Play Debuff Alert Sounds` setting so debuff-loss alarms do not depend on the manual ability-warning sound toggle.
- Added `Center Critical Crowd-Control Alerts` setting (enabled by default).
- Increased the default configuration-window size, made it resizable, and widened the Abilities detail pane to prevent clipped UI text.
- Kept hostile entity scanning for same-name mob counting, but combat-log status transitions can now fall back to the visible actor name while filtering player/party names.

## 1.6.0 - Unified Global Debuff Engine

- Replaced the separate Sleep and Petrify trackers with one data-driven global Debuff Engine.
- Added `data/debuffs.lua` so new statuses can be added/refined without another core subsystem.
- Recommended zero-setup tracking now covers Sleep, Petrify, Bind, Gravity, Silence, Paralyze, Slow, Addle and Blind.
- Added optional advanced definitions for Poison, Dia, Bio, Elegy, Distract and Frazzle.
- Added Smart Reapply Alerts: maintenance debuff loss can wait until the current character has an actually usable counter.
- Smart checks reuse Warn's verified spell/BLU capability logic, including learned spell, job/subjob level, MP, recast and set Blue Magic.
- Added deferred maintenance alerts that cancel automatically if another player reapplies the effect first.
- Added one combined Debuffs tab with Recommended / Crowd Control / All Supported / Off quick presets.
- Added per-status enable, smart-alert policy, custom sound, test and clear controls behind an Advanced toggle.
- Added `/warn debuffs` list/clear/preset/test/lose/reload commands.
- Preserved `/warn sleep` and `/warn petrify` commands as compatibility aliases.
- Migrates existing v1.5.x Sleep/Petrify enable and sound preferences into the unified status settings.
- Global debuff losses are batched to reduce AoE crowd-control sound/overlay spam.
- Dead/despawned targets are removed silently and all global debuff state clears on zoning.

## 1.5.3
- Added a global hostile Petrify/Petrification tracker alongside the Sleep tracker.
- Tracks player-applied Petrification such as Break and Entomb from confirmed combat-log status messages.
- Alerts when a tracked monster is no longer Petrified, regardless of current target.
- Added batching for simultaneous AoE Petrify losses.
- Added a dedicated Petrify tab, independent alert sound selection, tracker list, clear button, and test alert.
- Added `/warn petrify` list/clear/test/recover commands.
- Petrify state clears on zoning and silently removes dead/despawned hostile mobs.


## 1.5.2 - Global Sleep checker

- Added a global hostile-monster Sleep tracker independent of encounter rules and current target.
- Tracks successful Sleep state messages from any source and warns when a previously tracked monster wakes / loses Sleep.
- Added a **Sleep** GUI tab with live tracked-monster list, enable toggle, wake-alert sound override, test alert and clear button.
- Added dedicated wake-alert sound selection supporting the global sound, `None`, or any custom WAV in `sounds\`.
- Groups near-simultaneous wake-ups into a single warning to avoid AoE wake alert spam.
- Bounds same-name Sleep counts by the number of loaded hostile entities to reduce duplicate tracking from Sleep overwrites.
- Silently removes stale Sleep state on death/despawn and clears all Sleep state on zoning.
- Added `/warn sleep [list|clear|test <mob>|wake <mob>]` commands.

## 1.5.1 - Breadwinner Silence maintenance

- Added reusable maintained-debuff encounter state tracking.
- Bozzetto Breadwinner now warns when Silence is missing and re-alerts when the encounter reports that Silence has worn off.
- Silence alerts only fire when the current character has an immediately usable Silence counter.
- Added BLU set-spell capability checks for Silent Storm and Chaotic Eye using the Ashita v4 BLU spell-set memory layout.
- Added `/warn teststate <rule id> <gained|lost>` for state-rule testing.
- Preserved `ambu_meeble_breadwinner_silence` so existing rule sound overrides remain intact.


## 1.5.0
- Changed addon attribution to **Sigman** for public release preparation.
- Expanded Ambuscade Volume 2 with verified actionable rules for Durga, Sowl Devourer, Kauri, Yartsa Gunbu, Gwas-y-neidr, Alluttu, All-Watcher, Natsilane, Chelone, Thillloab, Mnyiri, Sombra Dragon, Bomb family, Jody/Julika/Vivian, and Pamola.
- Expanded HTMB coverage for all five Ark Angels, Return to Delkfutt, Shadow Lord, The Savage, Celestial Nexus, prime avatars, Fenrir and Diabolos.
- Preserved stable rule IDs and per-alert sound overrides.
- Added contributor guidance for future GitHub/community rule submissions.

## 1.4.0
- Added full historical Ambuscade V1/V2 encounter catalog.
- Added full 30-category HTMB catalog.
- Expanded actionable Ambuscade V1 contextual rules across the rotation.
- Began Ambuscade V2 actionable coverage.
- Expanded HTMB rules for Lilith, Odin, Alexander, Cait Sith, Shinryu, Ultima, Promathia and Tenzen.
- Added spell-cast parsing (`starts casting` and `casts`) for contextual rules.
- Added `/warn coverage` and GUI indexed-encounter counts.
- Preserved per-rule sound overrides and custom sound-folder support.

## 1.3.0
- Added per-rule encounter sound overrides and modular rule database.
