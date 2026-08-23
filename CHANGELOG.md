# Changelog

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
