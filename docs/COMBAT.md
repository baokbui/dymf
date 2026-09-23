# BVM Combat

Combat is handled **exclusively** by `CombatService` on the server. Brainrots and
monsters never modify each other's health directly — they send intents through
this service (`.cursorrules`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Ownership

| System | Role |
| ------ | ---- |
| `CombatService` | Damage, healing, death routing, target acquisition, projectiles, status effects |
| `DamageMeterService` | Per-day HP ranks (Brainrot vs Monster tabs); reset on Start Day |
| `EnemyService` | Monster runtime state, movement, status fields, death cleanup. Spawn copies HP from `Monsters.scaledForDay` (non-boss campaign aging) and sets `MonsterLevel` to the current day. |
| `BrainrotService` | Brainrot runtime state, status on planted units |
| `CombatController` (client) | Hit/death/explosion VFX, projectile trails (`CombatVisual` + plot watcher) |

**Damage meter** ✅ — `DamageMeterService` totals HP per Brainrot / monster
registry id on the plot owner's lawn. Broadcasts `DamageMeterUpdated` (coalesced).
Resets when the day goes **Active**. Every Brainrot hit that goes through
`CombatService.damageMonster` with a `sourceBrainrotId` ranks: knives (incl.
Piercing Brew / fifth strike / execute leftover HP), Shadow Requiem waves and
last-tile pillar, melee bat, Ranged Rampage bats, Tralalero bubbles / barrage /
Abyssal Torrent,
Bombardino column bombs.
Status DoT without a source species is not ranked. Client HUD is display-only.

---

## Target acquisition ✅ (Milestone 7)

Monsters use **fractional grid columns** (west toward the house = decreasing
column). When a Brainrot attacks a row:

| Mode | API | Behavior |
| ---- | --- | -------- |
| First in row | `attackFirstInRow` / `launchProjectile` | Damages the monster with the **lowest column** in range (closest to the house — PvZ peashooter style). Used by Cappuccino knives and Tralalero bubbles. |
| All in range | `attackInRow` | Damages every monster in range (instant splash) |
| Entire row | `dealEntireRowDamage` | Damages **every** monster on the row (Bombardino line bomb) |
| Entire row status | `applyEntireRowStatus` | Status on **every** monster on the row. Returns how many received it. |
| Column-band status | `applyStatusAroundColumn` | Status on the caster's tile plus N tiles ahead and behind (Lirili freeze = 2). Returns how many monsters received the status. |

Range uses `GridUtil.isColumnInRange` with `BrainrotConfig.FULL_LINE_RANGE` (-1)
for full-row-from-tile attacks. Tile-based `rangeTiles` covers whole cells ahead.
**Melee bat** uses tile-based `rangeTiles` (Tung Tung = 1): hits monsters on the
Brainrot's own tile **or** one tile ahead. Friendly Brainrots do **not** block —
a bat behind Ballerina, Lirili, Chimpanzini, etc. can still hit a monster chewing
that unit. (Legacy fractional `MELEE_BAT_REACH` is unused.) Optional
`attackHitDelay` starts the swing anim first, then re-acquires the target before
damage — if nothing is still in range, the swing misses (cooldown already spent).
**Ranged Rampage** (`rangedUntil`) throws a spinning `Bat` projectile (`Assets.Projectiles["Tung Bat"]`) from the left hand down the full lane instead of the close-range hit. Connecting hits on the lawn apply **quarter-tile** knockback (`CombatConfig.BAT_KNOCKBACK_TILES`). A bat that still lands after the monster has left the plot (forest / east of the last tile) deals damage only — no knockback.

Monsters still east of the lawn (`column > GridConfig.COLUMNS`, forest march)
are **not** valid targets — Brainrots wait until the monster enters the plot.

**Fog graves** sit on a lawn column and **block** Brainrot damage, projectiles,
and status aimed at monsters **strictly east** of the stone (`fromColumn <
grave < targetColumn`). Combat does not apply HP or status to those monsters
(shurikens stop at the stone). **Piercing Brew** (`pierceCount`) and Cappuccino
GOD **Shadow Requiem** (`pierceAll` sword waves) are the exceptions: those
shots never treat the grave as a target (no HP, no shake), keep flying through
the stone, and still damage monsters behind it. Piercing Brew also hits the
monster behind the first at the knife’s normal damage. Graves have no combat HP except **Patapim**
smashes (`hitFromPatapim`), which also **shake** the mesh. Other hits do not
shake. **Bombardino** `dealColumnDamage` / entire-row bombs still hit monsters
on and behind the grave tile. Monsters on the grave tile or west of it remain
valid targets for lane shots. Graves do not block westbound Skeleton arrows.

Monsters with `laneSpan` > 1 (e.g. Pharaoh Mummy = 2, Goblin Elite and Queen Spider = 3) occupy rows
`[row, row + laneSpan − 1]` — `row` is the unit's lowest/anchor row, not a
center — and are valid targets from **any** row in that range
(`GridUtil.occupiesLaneRow`). Uniform scale also makes them ~`laneSpan` tiles
wide in X; freeze / row splash treat that footprint as on-plot once it overlaps
the lawn (`isOnPlotColumn(column, laneSpan)`), so planting Lirili on the visual
middle of Queen Spider still hits even if her pivot is a tile east. Melee,
projectiles, and row splash all use the row rule via `EnemyService` queries.
Visual placement centers the model on the midpoint of its occupied span
(`GridUtil.laneCenterRow`) so even spans still render centered between their
lanes instead of snapped to one edge.

The reverse direction also respects the span: when a multi-lane unit attacks,
it hits every Brainrot standing on its current tile across **all** occupied
rows (`MonsterBehavior.brainrotsAtColumn`), not just its anchor row. This is
what lets Goblin Elite's one-shot club (`GoblinEliteClubOneShot`) down
Brainrots in all three of its lanes in the same swing.

---

## Projectiles ✅ (Milestone 7)

`CombatService.launchProjectile` spawns a server-replicated part in
`plot.Projectiles` and moves it along the row. Brainrot shots travel **+X**;
Skeleton arrows use `launchTowardBrainrot` (`columnDirection = −1`).

| Ability | `kind` | On impact |
| ------- | ------ | --------- |
| Cappuccino (`ThrowKnife`) | `Shuriken` — clones `Assets.Projectiles.Shuriken` when present (procedural star fallback). **Every** knife stands upright in the lane plane: **sharp rim** leads toward monsters, face looks across the row, cartwheel about **+Z**. | Damage + `ThrowKnifeHit`. **Piercing Brew** (**6s** window, **10s** CD): gold aura/trail/sparks, flies through graves (no grave HP), and hits the first monster and the one behind at the knife’s normal damage. Does not throw (or start its interval) while an exclusive extra such as **Shadow Requiem** is playing. |
| Cappuccino GOD (`ShadowRequiem`) | `SwordWave` — one **vertical** **backwards-C** (`")"`) crescent from the midpoint of Cappuccino’s swords (same Z span as the old dual slash). **White fill**, **black outline**, **black** flame/trail streaks. **Height** grows with travel. Stop on the **last lawn tile**, then explode into a **tall white light pillar**. Damage as the column passes each monster (`pierceAll`). Graves never block. Crescent **2000%** at **1 tile**, plus **100%** per extra tile, plus a flat **1000%** last-tile pillar. | `SwordWave` **1s** before the crescent launches (cut if the pillar starts first) + `SwordWavePillar` on detonation + `Hit` sparks per monster. Needs **3+** enemies in the row **or a boss**. Multiple ready Cappuccinos: easternmost fires first. **45s** CD. |
| Tung Tung (`MeleeBat` during Ranged Rampage) | `Bat` — clones `Assets.Projectiles["Tung Bat"]` when present (procedural club fallback); spawns from the left hand / arm; tumbles end-over-end along +X | Full-lane damage + `MeleeBat` SFX + quarter-tile Knockback **on the lawn only** (off-plot: damage, no knockback) |
| Tung Tung GOD (`SahurWrath`) | Same `Tung Bat` clone, not a flying projectile: grows **vertically above** the plant to the remaining lane length, then Tung’s **melee swing** arcs it down so it lies on the **row** from him to the east edge | `dealEntireRowDamage` at **1000%** of current bat damage (graves do not block) on that row, plus **500%** on the adjacent rows, if the row has **3+** enemies **or a boss**. Multiple ready Tungs: easternmost slams first. `SahurWrath` SFX as the bat stretches; `MeleeBat` SFX + `CombatVisual` kind `BatSlam` (yellow ring **at each monster on the slam row only**; adjacent rows take damage with no shockwave) on impact |
| Ballerina GOD (`Jackpot`) | Extra ability; no projectile | **10s**: coin interval **3×** faster (max with Golden Waltz); each spit **33%** extra coin (independent of Encore). `CombatVisual` `Jackpot` gold burst. **30s** CD |
| Chimpanzini GOD (`PrimalRetaliation`) | Extra ability; no projectile | **15s**: **25%** of incoming chew/arrow HP is dealt back to **that monster instance** through `CombatService.damageMonster`. A small `Assets.Projectiles.Mirror` orbits Chimpanzini. **30s** CD |
| Lirili GOD (Glacial Dominion) | On plant (`freezeEntireLawn` params overlay; Lirili does not persist to tick extras) | Freeze **every lawn row** at the current freeze duration, then **25%** Slow (`slowFactor` 0.75) lasting freeze + **3s** so it is felt after thaw |
| Skeleton (`SkeletonArrow`) | `Arrow` — clones `Assets.Projectiles.Arrow` (**Model or Part**); spawns from bow `Middle` attachment / `LArm`; flies **−X** toward the house | Brainrot hits (chew-equivalent) |
| Tralalero (`BubbleTrap` / `BubbleBarrage`) | `Bubble` — soap sphere from the mouth. **BubbleTrap** is a cyan bubble with no trail. **Bubble Barrage** fires one gold seed that splits into 5 lane bubbles, each with a gold light-streak (`BubbleBarrage`). Only when at least one monster is on the plot. | Damage + Freeze/`Bubble` shell + `BubbleTrap`. Crowd control (trap, knockback, slow, stun) shrinks with `laneSpan`: **2** rows **25%**, **3** **50%**, **4** **75%**, **5+** immune. Damage is unchanged. |

Tuning: `CombatConfig` (`SHURIKEN_MODEL_ID`, `SHURIKEN_TARGET_EXTENT`,
`SHURIKEN_MODEL_ORIENTATION_DEGREES`, `BAT_MODEL_ID`, `BAT_TARGET_EXTENT`,
`BAT_MODEL_ORIENTATION_DEGREES`, `BAT_KNOCKBACK_TILES`, `WRATH_*` slam timing,
`SWORD_WAVE_*` grow / last-tile stop / pillar expand+fade / speed, bubble size) +
`VfxConfig` bubble colors (cyan trap / gold barrage) and sword-wave white fill / black outline / corkscrew pillar.
Crescent / pillar percents: `Evolutions` `abilityParams` (`damagePercent`,
`travelPercent`, `finisherPercent`).

**Heavy VFX** ✅ — `VfxLoad` quality is a **Settings** choice (**VFX: High / Low /
Off**), not an automatic cap. **High** = **Full** (full combat effects, dense
Brainrot aura, moving evolution shine, 3D portraits). **Low** = **Reduced**
(fewer client bursts; thin Brainrot aura; shine stays still; portraits stay 3D).
**Off** = **Minimal** (geometry + light; no flame particles / corkscrew trails
locally, and no Brainrot aura flames — the rarity outline stays). Off also turns shop, inventory,
and index portraits into color swatches. **Inspect portraits stay 3D** on every
setting. Server still
authors Full sword-wave / pillar models so combat looks the same for every
plot; Performance mode strips particles and trails on the local client. Magnet
rings also skip when Off. Combat math is unchanged.

Client trail/glow branches on the `ProjectileKind`
attribute (`VfxUtil`); normal bubbles, thrown bats, and `SwordWave` skip extra
client trails (waves already carry a black trail). Bubble Barrage adds a gold light-streak.

### Studio: Cappuccino shuriken model

1. Rojo-sync so `ReplicatedStorage.Assets.Projectiles` exists.
2. Move your shuriken **Model** from Workspace into that folder.
3. Rename it to **`Shuriken`** (or set `CombatConfig.SHURIKEN_MODEL_ID`).
4. Set a `PrimaryPart` if possible; strip Tools/Scripts.
5. **Every** shuriken (not only Piercing Brew) is stood **upright** in the
   lane plane so the **sharp rim** leads toward monsters (face looks across
   the row) and cartwheels about +Z. Tune
   `SHURIKEN_MODEL_ORIENTATION_DEGREES` only if a specific asset still faces
   wrong after that bake.

### Studio: Tung Tung thrown bat

1. Rojo-sync so `ReplicatedStorage.Assets.Projectiles` exists.
2. Move your bat **Model** (or Part) into that folder.
3. Rename it to **`Tung Bat`** (or set `CombatConfig.BAT_MODEL_ID`).
4. Set a `PrimaryPart` if possible; strip Tools/Scripts.
5. If it tumbles on the wrong axis, tweak `BAT_MODEL_ORIENTATION_DEGREES`.

---

## Status effects ✅ (Milestone 7)

Applied only through `CombatService.applyStatusToMonster` or
`applyStatusToBrainrot`.

| Effect | Monsters | Brainrots |
| ------ | -------- | --------- |
| Freeze / Stun | Pauses movement (`frozenUntil`) **and** chew / shoot / ability `onTick` for **every** monster, including bosses (Lirili Ice freeze cannot be cast through). Visual style via optional `visual`: `"Ice"` (Lirili — Ice material + color, textures/SurfaceAppearance disabled, ice Highlight + flakes) or `"Bubble"` (Tralalero — float in shell, pop on release). Duke last-stand stays on its downed timers if Freeze is still ticking. | Pauses attacks (`frozenUntil`); client **dizzy ★ stars** + yellow rising **"Stunned"** floater (`CombatVisual` `Dizzy`). Multiple floaters on one Brainrot **queue** (lead word faster, then the next) so they never cover each other. **Tenfold Guard** skips Stun while `shieldStunImmune` and shield HP remain. **Stoneheart** ignores Stun / Freeze while stone. |
| Slow | Reduces movement speed. Bubble freeze ending can apply Slow via Immortal `bubbleExitSlowPercent` (`CombatService.applyBubbleExitSlow`). That bubble slow (duration and slow amount) uses the same `laneSpan` resist as the trap. Lirili GOD Glacial Dominion applies Slow **25%** (`magnitude` 0.75) on every lawn row for freeze duration + **3s**. | — |
| Poison / Burn | DoT via `MonsterStatus` tick | DoT via `BrainrotBehavior` tick; **Poison** tints the Brainrot slightly purple (`BrainrotFeedback.setPoisoned`) for the duration and pops a rising **"Poisoned"** floater. Floaters share the same per-Brainrot queue as Stun. |
| Knockback | Pushes column east (+X) **only while the monster is on the lawn** (`GridUtil.isOnPlotColumn`). Magnitude is tiles (`CombatConfig.KNOCKBACK_TILES` default; Ranged Rampage uses `BAT_KNOCKBACK_TILES` = 0.25). Instant; graves block it like other statuses. Off-plot / forest: skipped. | — |
| Weaken | — | Scales the Brainrot's own outgoing `damage` down by `magnitude`% for `duration` (non-mutating `__index` override on the ability context's `definition` — see `BrainrotBehavior.effectiveDefinition`); every existing ability respects it automatically |

**Queen Spider** ✅ — **laneSpan 3** (random valid placement among anchors that
fit a 3-row footprint on the 5-row lawn). Does **not** jump. Each chew applies
`"Stun"` for `stunDuration` (2s) and `"Poison"` for `poisonDuration` (4s) at
`poisonPercent` (3% of the Brainrot's max HP per 1s tick). Cleaves all three
occupied lanes. Stun/poison visuals: dizzy stars + yellow "Stunned" floater;
slight purple model tint + purple "Poisoned" floater (queued so they don't overlap).
Uses the default tip-over death like other monsters.

**GOD ultimates** ✅ — extras path or params overlay:
- **Sahur's Wrath** — `SahurWrath` extra; **3+** enemies or a boss; **1000%** on the slam row and **500%** on adjacent rows; easternmost ready Tung.
- **Jackpot** — `Jackpot` extra; `jackpotUntil` / `jackpotFactor` / `jackpotExtraChance` (does not overwrite Golden Waltz; `effectiveDefinition` takes the higher coin haste).
- **Primal Retaliation** — `PrimalRetaliation` extra; chew/arrow `damageBrainrot` passes the monster **instance** id; `applyBrainrotDamage` reflects chew HP to that instance (`CombatService.damageMonster`) and ranks the meter by registry id. A small `Assets.Projectiles.Mirror` orbits Chimpanzini for the window.
- **Glacial Dominion** — Lirili `freezeEntireLawn` + `lawnSlowPercent` / `lawnSlowDuration` on plant (she despawns; no extra tick).
- **Shadow Requiem** — `ShadowRequiem` extra. Exclusive with Piercing Brew and Cappuccino’s knife throw (core attack pauses for the clip). Needs **3+** enemies in the row **or a boss**; easternmost ready Cappuccino fires first. Plays `abilityAnimationIds.ShadowRequiem`, then at clip end launches one `SwordWave` projectile from the midpoint of Cappuccino’s swords (**white fill**, **black outline** and streaks). The wave grows, stops on the last lawn tile, and explodes into a **white light pillar**. Launch SFX (`SwordWave`) starts **1s** before the crescent (`CombatConfig.SWORD_WAVE_SOUND_LEAD`) and cuts if the pillar starts first; pillar SFX is `SwordWavePillar`. The pillar expands to **one tile wide**, then fades over **~3s**. Black flames **corkscrew** around it as it rises. Pierce every on-plot monster in the row and every grave. Crescent damage is **2000%** at 1 tile, plus **100%** per extra tile of travel (from column 1 the last tile is 8 away → **2700%**). Last-tile pillar bonus is a flat extra **1000%** (not ramped). **45s** CD.
- **Abyssal Torrent** — `AbyssalTorrent` extra. A water stream from Tralalero’s snout to the east edge of his row (same height and lane offset as the mouth, straight along +X). Pierces every monster in that stretch (graves do not stop it). Each full second a monster spends in the jet deals his **catalog base damage** (55; Epic’s damage buff does not raise this), plus **20%** of that base for every tile the monster is closer to his plant than the easternmost lawn tile (`TORRENT_CLOSE_PERCENT`). A monster on that far tile takes 55. One tile toward him takes 66. On his own tile the bonus is 20% × (9 − his column). Knockback is **0.25** tiles east per second (`CombatConfig.TORRENT_KNOCKBACK_TILES`), which moves them toward the lower bonus. **15s** on the far tile is **825**. Needs **3+** enemies in the row **or a boss**; easternmost ready Tralalero fires first (one still on cooldown is skipped). Bubbles pause while the jet is out. **45s** CD. The stream is a dim purple beam: pale violet core, vivid purple body, dark outer glow, rings rushing down the row, and spiral streaks. Small soap bubbles orbit the beam on **High** VFX only (`VfxLayer = "High"`); **Low** and **Off** hide them. Off VFX keeps the neon core and drops the beams.

**Immortal passives** ✅ — data-driven (`abilityParams` / extra ability ids, never unit names):
- **Assassin's Verdict** — `EnemyService.damageMonster` executes if remaining HP% is ≤ `executeHealthPercent` (bosses use `executeBossPercent`) before the hit.
- **Wound of the Shark** — when a `"Bubble"` freeze ends, `CombatService.applyBubbleExitSlow`.
- **Frostbound Neighbor** — `FreezeTime` also freezes one adjacent row (`freezeAdjacentLane`).
- **Stoneheart** — invulnerable + skip extras / attacks while `stoneUntil`. Model reads as **granite** (`BrainrotFeedback.setStoned`): the aura Highlight fill becomes a cool gray wash (Roblox only draws one Highlight per model; aura outline would otherwise hide a second one), aura flames pause, and mesh Color / `Rock` apply after stripping SurfaceAppearance / textures. Restored when the 10s ends.
- **Tenfold Guard** — timed shield every N attacks; stun-immune while that shield lasts. `abilityParams.orbitShield` clones a small `Assets.Projectiles.Shield` in orbit (Tung); Banana Bastion stays a ForceField bubble.

**Scorpion** ✅ — `spawnStyle = RiseFromGround` in the forest (same mummy
entrance). `ScorpionBurrow` only on first **plot** column: sinks, travels
underground (invulnerable / untargetable), and rises just east of the first
Brainrot in its lane, then chews. Empty lanes do not burrow. Walk uses the same `proceduralWalk` crawl as Spider (no uploaded clips). Tunables:
`burrowDuration` / `burrowDepth` / `emergeOffset` (`MonsterConfig.BURROW_*`).

**Spider** ✅ — `SpiderJump` vaults the **first** Brainrot in its lane with a
visible parabola (`MonsterBehavior` jump state: column lerps west of the plant
while `floatY` peaks). The plant takes no damage; later Brainrots are chewed
normally. Tunables: `jumpDuration` / `jumpPeakHeight` / `jumpLandOffset` /
`jumpTriggerReach` on `abilityParams` (defaults in `MonsterConfig.JUMP_*`).

**Werewolf** ✅ — `WerewolfLifesteal`: each chew against a Brainrot
(`onBrainrotAttacked`) queues a heal of `lifestealPercent` (default **5**) of
its max HP via `abilityState.pendingHeal` (applied next `MonsterBehavior`
tick, capped at max HP). Fast march (`secondsPerGrid` 2.0).

**Lirili / Bombardino** — Lirili freeze (`applyStatusAroundColumn`, 2 tiles
ahead and behind) and Bombardino entire-row damage only target monsters **on
the lawn** (`isOnPlotColumn`, multi-lane footprint included). Both column
bombs and freeze match by **tile index / footprint overlap** so chewing units
at melee standoff — and a 3-lane boss standing on the plant tile — still take
the hit. Legendary Winter's Grasp (`applyEntireRowStatus`) uses the **caster
tile** for grave LOS (not column 0), so a fog grave west of Lirili does not
eat a freeze planted on Queen Spider. GOD Glacial Dominion freezes **every**
lawn row (`freezeEntireLawn`) plus Slow 25% for freeze duration + **3s**.
Graves still block monsters strictly
east of the stone from the caster. Freeze/Stun are rejected while a monster is
**downed**, and starting a tip-over (last stand) clears any active freeze.

**Duke Vampire** ✅ — `DukeVampireFreeze` is a **once-only** last stand: at
≤20% HP he falls over (`MonsterDeath.playDowned`, rig intact —
`MonsterBehavior` suspends movement/attack/sync via `runtime.downedUntil`)
for 1.4s while invulnerable (`MonsterRuntime.invulnerableUntil`, checked in
`EnemyService.damageMonster`), then rises (`MonsterDeath.riseUp`) already
healed to 25% max HP. `DukeVampireTerrify`
deals **no damage**; on a 10s cooldown it applies `Weaken` + `Stun` to his row
± 1 (independent of `laneSpan`, which stays 1). His regular chew is a plain
stat-driven attack (no ability) at Vampire pace with more damage. Goblin
King's speed-buff stub still awaits a follow-up milestone.

---

## Client visuals ✅ (Milestone 11)

`CombatController` + `VfxUtil` (client) render feedback on the **local plot only**:

| Effect | Trigger |
| ------ | ------- |
| Hit spark | `CombatVisual` kind `Hit` (client particles) |
| Hit flash (monsters) | `MonsterFeedback.flashHit` on server (replicated body color) |
| Hit flash (Brainrots) | `BrainrotFeedback.flashHit` on server (replicated BasePart colors) |
| Hit / death / explosion SFX | `AudioController` via `CombatVisual` (M12) |
| Melee bat SFX | `BrainrotAction` (`MeleeBat`) after `attackHitDelay` — sound only for animated units; ScaleTo pulse only if not `animated` |
| Melee bat swing | Server `BrainrotAnimation.playAttack` at windup start (`pulseAttack`) |
| Death tip-over + linger + fade | Server `MonsterDeath` (default 3 tip styles); client burst + Thanos ash on fade |
| Line-bomb explosion | `CombatVisual` kind `Explosion` — Bombardino drops a bomb on each tile (staggered); on land the bomb despawns and a per-tile blast plays |
| Bat slam impact | `CombatVisual` kind `BatSlam` — Sahur’s Wrath landing: yellow ring **at each monster on the slam row** (`VfxUtil.playBatSlam`). Adjacent-row splash has no shockwave. |
| Jackpot burst | `CombatVisual` kind `Jackpot` — gold particle burst at Ballerina (`VfxUtil.playJackpotBurst`) |
| Primal Retaliation | Server `BrainrotFeedback.setRetaliation` — small `Assets.Projectiles.Mirror` orbits Chimpanzini for the 15s window (Banana Bastion bubble stays) |
| Projectile trail/glow | Watches `plot.Projectiles` (non-blocking; never delays hit/death SFX). Piercing Brew shurikens use a gold trail/glow; server adds gold outline, a gold spark cloud around the star, and a `PierceTrail` ribbon (attachments perpendicular to +X so the trail has area). Tralalero **BubbleTrap** skips trails; **Bubble Barrage** uses a gold light-streak (`BarrageStreak`). Thrown **Bat** projectiles skip trails and glow (the spinning mesh is the read). |
| Terrify scream | `CombatVisual` kind `Terrify` → `VfxUtil.playTerrifySoundwave` |
| Pharaoh steal sand tornado | `CombatVisual` kind `SandTornado` — level funnel from the boss toward the stolen plants (sized for his 2-row body) + grit from those plants |

Tuning lives in `Shared.Config.VfxConfig` (particles, colors, durations). Gameplay
values remain in `CombatConfig`.

---

## Death ✅ (Milestone 7 / M12 audio)

1. `CombatService.damageMonster` / `damageBrainrot` / `healBrainrot` routes to the owning service.
   Brainrot hits pass a `sourceBrainrotId` so the monster records last-hit
   species (and `DamageMeterService` ranks HP). Knives also pass
   `sourceInstanceId`. Status DoT omits that source.
   `BubbleTrap` / `BubbleBarrage` still pass a source for the damage meter;
   last-hit kill XP stays skipped via `SKIP_LAST_HIT` (landed-hit `HIT_JOB`
   instead).
2. On monster death, `CombatService.notifyMonsterDeath` pushes `CombatVisual`
   `{ kind = "Death", instanceId, monsterId, row, column }` to the plot owner,
   grants Brainrot XP (`ProgressService.grantKillXp` — last-hit species for
   normal kills, skipping `SKIP_LAST_HIT` abilities; boss XP split across living
   plants), then increments `STAT_MONSTERS_DEFEATED`. Silent destroys (house
   breach, `clearPlot`) skip this and grant no XP. Support jobs (`COIN_XP` /
   `SOAK_XP` / `FREEZE_XP` / landed-hit `HIT_JOB`) grant separately via
   `grantBrainrotXp` — coin spit, wall damage ticks, freeze casts, every N
   landed hits (`BubbleTrap` every 2, `MeleeBat` every 3) **instead of** last-hit.
3. Client plays `Death_<monsterId>` when configured (else `Death`), then a death
   particle burst. After tip-over + linger, a Thanos-style ash disintegrate
   (`VfxUtil.playDeathDisintegrate`) plays as the corpse fades.
4. Server `MonsterDeath` bakes the live pose into welds (keeps overlay meshes
   glued; does not teleport named arms), then plays the definition's
   `deathStyle` (default: tip onto the ground — randomized faceplant / side
   flop / backfall), leaves the corpse for
   `CombatConfig.DEATH_CORPSE_LINGER` (2s), fades it out, then destroys the model.
5. Brainrot death destroys the placement and frees the tile (unchanged from M5).

Hit flash on damage uses server-side `MonsterFeedback.flashHit` /
`BrainrotFeedback.flashHit` so the red tint replicates reliably.

---

## Config

`Shared.Config.CombatConfig` — projectile speed, DoT intervals, monster death
fall / linger / fade timings. **Never hardcode** combat tuning in services.

---

## Remotes

| Name | Direction | Purpose |
| ---- | --------- | ------- |
| `CombatVisual` | server → client | `Hit` (`instanceId`, optional `soundKey` / `muteSound`), `Death` (`monsterId`, …), `Explosion` (`row`, optional `column` / `entireRow`), `BatSlam` (`hits` = `{ x, y, z }` per monster hit) |

See `NETWORKING.md` for the full catalog.

---

## Ability routing

```
BrainrotBehavior.tryAct
       → Abilities/<id>
       → CombatService (attack / projectile / status / healBrainrot)

MonsterBehavior.attackBrainrot
       → CombatService.damageBrainrot
       → Abilities.onBrainrotAttacked (boss effects)
```

**Pharaoh Mummy** ✅ — `PharaohSummon` spawns a `SmallMummy` in every row (20s).
`PharaohSteal` removes one living Brainrot from each of 3 random occupied lanes
(15s) via `BrainrotService.stealPlacement` (tile freed, model yanked toward the
boss) with a client sand-tornado suck (`CombatVisual` `SandTornado`). Plants with `definition.immovable` (Chimpanzini **Goliath**) are skipped, and `stealPlacement` refuses them if called later. Steal is not Combat damage. Pharaoh occupies **2 rows** (`laneSpan`). Pharaoh and Small Mummy both use
`spawnStyle = "RiseFromGround"` (buried, then tween up; invulnerable while rising).
Pharaoh's entrance adds `spawnVfx = "Sandstorm"`: the steal sand tornado stood
upright, sized to cover his whole body, for `SPAWN_SANDSTORM_LEAD` (0.55s)
before the rise. He climbs out inside it, and it fades on the tick he takes
his first step. **High** is dense enough that he cannot be seen inside.
**Low** thins the shell so he is only partly visible. **Off** spawns no tornado.
Small Mummy and Scorpion still rise with no sandstorm.
Pharaoh walk / chew / summon / steal clips live on the definition
(`abilityAnimationIds` for summon + steal; chew uses the Small Mummy attack id).
Summon/steal wait `summonHitDelay` / `stealHitDelay` after the clip starts.
Pharaoh **stops walking** for the clip length (`beginChannel`), then resumes walk.
