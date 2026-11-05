# Current implementation notes

Documentation audit: **2026-11-02**. These notes distinguish implemented
behavior from design intent and unfinished work. They do not change gameplay.
`AGENTS.md` is the canonical project rules file; `.cursorrules` points to it.

## Audit scope and limits

All 18 existing documents in `docs/`, README, and both rules files were reviewed
against the registries, configs, service paths, and client presentation modules.
Normalized source checksums matched **all 174 Luau scripts** between the local
`src/` tree and the connected Studio place, **Defend the Brainrots! [Beta]**
(place 102816403053242). This verifies source sync, not asset completeness,
animation permissions, visual correctness, or a multiplayer/performance playtest.
No gameplay source or developer cheat settings were changed by this audit.

## Shutdown save overlap — corrected 2026-11-05

PlayerRemoving captured the final progression snapshot, but BindToClose could
queue another snapshot after gameplay services cleared their state. That later
snapshot could replace the saved day with the runtime's Day 1 default.
SaveService now rejects ordinary shutdown/autosave requests once the player's
leave handler begins, preserving its final snapshot until the writer finishes.
The in-memory SaveRetention fixture reproduces Day 2 → Day 1 without this guard
and verifies Day 2 survives shutdown/rejoin with it. The full fixture and Rojo
build passed. No existing player save was modified or restored by this check.

## Daily wheel and first-time reset carryover — 2026-11-05

DailySpinPanel now reveals the committed result using a four-second wheel
rotation, with proportional reward sectors. The initial radial-strip layout
incorrectly treated AnchorPoint as a rotation pivot, bunching colors to one
side. Strips now use centered anchors and radial center positions, with scale
coordinates to retain subpixel precision. The old layout fails the new hub
alignment regression. All 191 isolated GUI checks pass, covering all 180 strip
endpoints, sector proportions, stopping angles, reconnect display, eligibility,
stale-state rejection and UTC rollover. A full visual/input playtest remains pending.
The SaveRetention in-memory integration fixture verifies first-time claim
completion, earned upgrade levels and unused tickets survive Reset Progress,
while purchased levels and brains reset. Repeated resets do not duplicate
levels/tickets or refund redeemed tickets. Forty-nine LoginRewards checks pass,
including actual-grant provenance, max-level brain fallback and legacy carryover.
Eight affected runtime modules compile in Studio; Rojo build passes. These
checks use fixtures and do not reset or modify any real player profile.

## Spawn scheduling — corrected in Milestone 20 Step 0

Previously the last unit of a numbered-day group could use the next group's
species/row after the scheduler advanced groupIndex. LevelRun now returns the
original spawnGroup on every spawn; LevelService consumes that group directly.
The obsolete Hidden Day-only exactSpawns field was removed from the definition
type and registry. All days now use the same exact group scheduling.

Species and row settings are captured before the transition. Big-wave spawns
still wait for their authored group delay plus the warning duration. EnemyService
retains its duplicate-boss guard; Hidden Day explicitly permits its four Elites.
A rejected spawn attempt now emits a warning with unit, row, plot, and attempt
counts. Progress counts scheduled attempts, including refused ones; victory
still waits for no living monsters and no pending grave spawns.

Verification on 2026-11-02: the pre-fix Day 13 mismatch was reproduced. Updated
filesystem source passed 54 isolated Luau scheduler scenarios inside Studio
(50 numbered days, Hidden Day, three boundary/timing fixtures): 768 spawn events
and 53 big-wave warnings. Checks covered species, group identity/row settings,
counts, delays/intervals, warning-end flags, and no spawning after completion.
An extracted LevelService tick with stubbed dependencies verified rejection
logging and live-enemy victory gating. Extracted Continue/Start handlers verified
Hidden Day remains manually started. No saved gameplay session was started.
These checks are not a full multiplayer or visual playtest.

## Hidden Day lifecycle

- Clearing Day 40 sets numbered progression to 41 and marks Hidden Day pending.
  The displayed environment changes immediately to `Night`, not Desert.
- Continue returns to Preparation; Start Day manually begins Hidden Day and
  the usual 3…0 countdown. No fog, blocked columns, or graves are authored.
- Goblins/Elites gain 20% max HP after campaign scaling; attack interval and
  seconds per tile are divided by 1.2. King does not receive this modifier.
  Monster level/scaling uses numbered progression (41), not Hidden Day's 0.
- Kills accrue 1/10/25 brains for Goblin/Elite/King. All 40 kills pay 100 brains;
  leftover pocket coins convert separately at 100:1, uncapped. No ordinary
  numbered-day completion reward is added to Hidden Day.
- Both outcomes use the persistent reward screen. A clear commits lawn/XP;
  a loss restores the Day 40 checkpoint/XP and refills hearts. Continue goes
  to Day 41 Preparation. The environment switches to Desert at Hidden finish.
- Unfinished Hidden Day saves only the pending flag, not kills or run time.
  Rejoin requires another manual start. Day Select/Studio FORCE_DAY clears it.
- The transition is keyed to clearing Day 40, not a persistent once-ever
  completion flag; replaying Day 40 through the server API can offer it again.

## Current tuning and incomplete content

Milestone 20 Step 1 adds reward catalogs, pure UTC helpers, and proposed typed
contracts (`RETENTION.md`). The foundation passed 133 isolated Luau checks for
budgets, immutable catalogs, UTC boundaries, missed days, rollback rejection,
and countdown display. Step 2 implements RetentionService daily quests, QuestController UI, v8
persistence, and durable SaveService/SessionStore claims. Isolated regressions
cover retries, lost responses, queued saves/purchases, disconnects, ownership,
expiry, and migration. Full battle/multiplayer and live analytics QA remain
pending. Step 3 now implements finite first-time mixed rewards and weekly quests
(schema v11), replacing the historical welcome-to-weekly login cycle. Rewards
include permanent upgrades, brains and one final free store ticket; ticket
consumption and unlock are one durable transaction. Isolated tests cover the
new rules and migrations; full cloud/device/battle QA remains open.
Step 4 implements permanent achievements and a next-goal hint inside the quest
window, using the restored UI style. Its 32 pure rule assertions and isolated
save/service/UI checks cover ownership/Epic catch-up, new boss/perfect events,
duplicate claims, failure/rejoin, midnight and concurrent saves. Schema v10
preserves existing quest/login claims. Full battle/device/multiplayer and cloud
fault testing remain pending. Steps 5 and 6 added Forest Rush and the free daily spin in save schemas v12 and v13.

- There are **13 Brainrots**, **14 monsters**, and **nine** complete evolution
  tracks in the registries. Blueberrinni, Girafa, Patapim, and Bombardino have
  no evolution rows. Necromancer is not placed in authored days; his lane-change
  handler is an empty prototype.
- The campaign has **50 numbered days**. Day 50 remains selectable after its
  victory; there is no further numbered encounter or endless mode. On load,
  LevelService clamps saved current/highest days to the current registry limit.
- Duke's current last stand is once at <=20% HP: 1s fall, 3s grounded, 0.7s rise
  to **25%** max HP, invulnerable through the sequence. Terrify has a 10s cooldown,
  **4s** stun and 15% outgoing-damage reduction over his row +/-1 and up to two
  columns toward the house. Earlier 50% heal/2s stun descriptions are obsolete.
- Goblin King's buff grants himself/living Goblins +10% chew damage on spawn;
  Goblins arriving while he lives inherit it. Existing boosts remain after his
  death. Elites are excluded; this is not a speed buff or an expiring aura.
- Queen Spider currently has no special `deathStyle` in her definition, so
  the runtime uses the default tip-over. A custom leg-collapse death is not
  currently implemented: MonsterDeath.play ignores its deathStyle argument.
- The house shell, owner sign, and authored pedestal locations exist.
  HouseService, trophy collection, and passive house brains income are planned
  (M21). Daily/weekly quests, first-time rewards and achievements/next goal are implemented
  (M20), along with Campaign quests, Forest Rush, and the free daily spin. Day Select has a
  server remote but no shipped player-facing UI.

## Health, damage, and feedback ownership

CombatService routes damage, projectiles, status, and Brainrot heals to runtime
owners. Monster self-heals use `abilityState.pendingHeal` consumed by
MonsterBehavior, capped at max HP and followed by owner-only Heal VFX. There
is no public CombatService monster-heal API. Do not claim every self-heal
currently traverses one.

Brainrots use hit units internally (`health`) and an HP display pool
(`maxHealth`). Monster damage is converted to whole hit units, so displayed
damage can be rounded by the runtime; status ticks also use this conversion.
The monster damage meter records incoming HP-equivalent damage before shield
absorption/remaining-HP clamping. Brainrot damage to monsters is capped to actual
remaining HP for its meter. These are not identical accounting semantics.

VFX High stays Full regardless of concurrent ult count. Low/Off are player
choices. Other plots Off hides supported replicated Brainrot effects/auras;
owner-only remote bursts and SFX already stay on the owning client. It does
not reduce server combat work, spawning, or animation replication.

## Studio and saved progress

The shared Menu hosts Inventory, Index, Upgrades, Settings, Statistics, Quests and Achievements. First-time Rewards has its
own temporary gift HUD entry/window that disappears on server-confirmed completion.
The Menu uses a slide-out strip of seven bare icons. MenuRouter reuses existing panels, switches narrow detail
cards into the content area with Back, and scrolls long content instead of
shrinking it to the screen height. The physical Brainrot shop remains separate.
`tests/MenuIntegration.spec.luau` passes 207 mocked client checks, including
navigation, badges, detail cleanup, physical-store detach/remount and results.
Actual device interaction and complete battle regression remain open.

DevConfig currently has `ENABLED = true`: 10,000 coins/brains, all playable units
unlocked, zero planting cooldowns, Brainrot level 50 with available tiers claimed,
and FORCE_DAY set for local testing. Read DevConfig for the current target day;
do not keep copying that frequently edited value into rules/docs. FORCE_DAY is
clamped to `Levels.count()` and runs after save hydration on a fresh join.

These overrides never activate on published live servers, but normal saves can
persist the Studio-granted progression when API access is enabled. Studio uses
the same DataStore name as the game. Disable cheats before release; do not reset
or overwrite a developer's testing preferences during documentation edits.

Rojo sync is separate from the Studio MCP connection. Run `rojo serve` from the
repository and connect Studio's Rojo plugin (normally 127.0.0.1:34872). Restart
the playtest after config edits so cached modules and join overrides reload.
Studio-authored assets under `$ignoreUnknownInstances` survive sync, but that
does not export them into Git. A fresh Rojo build can use missing-asset fallbacks
unless the required Studio models are also available.

Desktop UI scaling has 17 isolated viewport checks; planting cards and damage
rows have larger baseline geometry. First-time Rewards collapses unused bottom
space when the claim button/feedback are hidden. See `UI.md`; this does not
replace real-device or four-player visual QA.

The shovel cursor is excluded from desktop position scaling and corrects the
GUI inset once. Both shovel views now use texture 123683019299968, replacing the procedural
handle/grip/blade. Ten isolated shovel checks pass, alongside
the Menu and viewport fixtures; full device input QA remains open.

QuestTracker sits between Damage and the day UI, refitting on HUD geometry
changes. Full quest claims still use the existing Menu panel and server writer.
The Menu integration fixture covers tracker progress and expanded Damage spacing;
real device and complete battle QA remain open.

The tracker no longer has a View Quests link. Its single heading and cycle icon switch tracks;
newly completed objectives animate out locally. Completed rewards still require
the full Menu claim flow. UI fixtures verify animation completion without replay.

The large Menu grid is removed. Seven icons slide beside the HUD Menu/X toggle;
feature panels still use the existing shared host. UI checks cover morph/reset,
rapid toggles, navigation, standalone rewards and physical-store reuse.

The latest compact pass reduces desktop enlargement, keeps menu captions white,
and uses one Daily/Weekly tracker heading. ScrollPolicy hides chrome for fitting
content and balances gutters; 207 UI, 17 viewport, 15 reserved-HUD layout and 7 scrollbar checks pass.
These isolated tests do not establish full device or four-player visual QA.
