# BVM Balance (Milestone 14+)

Gameplay tuning lives in **Config modules** and **data registries** — never
hardcoded in services (`AGENTS.md`). This doc explains the design targets;
numbers are authoritative in code.

Status: ✅ Milestone 14 (retuned after plant cooldowns)

---

## Design targets

| Phase | Days | Goal |
| ----- | ------ | ---- |
| Opening | 1–4 | Learn plant → earn → defend; **Zombie** only; Day 1 empty board, then carry-over |
| Campaign | 5–9 | **Zombie** + **Goblin** mix; economy opens mid-tier units |
| Boss intro | 10 | **Goblin Elite** big wave; row clear + sustained DPS, not one bomb |
| Ramp | 11–12 | **Zombie** + **Goblin** only; counts/pacing recover from the L10 dip |
| Elite recurs | 13–14, 17–19 | **Goblin Elite** mixed in as a recurring miniboss (not always the finale) |
| New species | 15 | **Vampire** intro — fast, high-HP grunt; gentle counts/pacing like Goblin's L5 debut |
| Campaign | 16–19 | **Vampire** count/pacing ramps alongside Zombie/Goblin/Goblin Elite |
| Boss #2 | 20 | **Duke Vampire** big wave; nerfed HP/speed/damage vs. later M10 bosses since it's the very next boss after Goblin Elite |

Difficulty ramps through **spawn counts**, **pacing** (`startDelay` /
`spawnInterval`), **monster species**, and **campaign aging**: each species
keeps its authored base HP, then HP grows **+30% per 10 days** since its intro
day (`MonsterConfig.STAT_SCALE_*`, applied at spawn via `Monsters.scaledForDay`).
A monster’s **level** is that same campaign day (`Monsters.levelForDay`): Zombie
starts at Lv. 1, Goblin Elite at Lv. 10, Queen Spider at Lv. 30. Day 11 Zombies
are Lv. 11. **Bosses (`isBoss`) do not scale.** Outside Hidden Day and Goblin King’s damage buff, damage, speed, and attack
interval stay at the intro values. Day 40 Zombies (debut Day 1) are **+120% HP** (2.2×). Goblins
(debut Day 5) are one step behind at Day 40 (+90% HP). Intro popups still show
base stats.

**Starter roster:** Day 1 begins with only Ballerina, Tung Tung, and
Chimpanzini unlocked (economy + melee + wall) — the other four launch
Brainrots unlock at Days 3/5/7/9 as the board grows and Goblin/Elite pressure
ramps up (see `BRAINROTS.md`). This keeps the early game (and the monsters!)
fair: no day-one full roster against a Zombie-only opener.

**House hearts:** 5 (one lost per breach). **Match coins:** Day 1 opens with
`STARTING_COINS` (125); after later days end the purse resets to **0** (earn
in-match via producers / passive). **Rewind** after Game Over grants
`REWIND_COINS` (200). **Planted Brainrots** carry across
**victories** and **rejoin** (DataStore); defeat restores that checkpoint on the
same day (Rewind); the lawn is wiped on day select / Reset Progress.
Brainrots only act while the day is **Active**.
Campaign spawn counts assume that growing board — see `Shared.Levels` /
`LEVELS.md`.

---

## Economy (`EconomyConfig` + Ballerina registry)

| Knob | Value | Rationale |
| ---- | ----- | --------- |
| `STARTING_COINS` | 125 | Day 1 purse only (Ballerina 50 + Tung Tung 75) |
| `REWIND_COINS` | 200 | Game Over → Rewind retry purse (any day) |
| `PASSIVE_DROP_INTERVAL` | 25s | Backup income cadence during Active levels |
| `PASSIVE_DROP_AMOUNT` | 25 | Matches producer coin size |
| Ballerina `coinGeneration` | 25 / 18s | Primary mid-level income (slower snowball) |
| Ballerina `maxOnPlot` | 10 | Caps producer snowball on one lawn |
| Leftover coins → brains | 100 coins = 1 brain | Day-end pocket leftover only. Steep so a couple Ballerina cycles are not a brain. Uncollected ground coins are wasted. |

---

## Plant recharge (`BrainrotConfig`)

After planting, that Brainrot id must recharge before another of the same type
can be planted. Lower **cost** → shorter cooldown (linear map):

| Knob | Value |
| ---- | ----- |
| `PLANT_COOLDOWN_MIN` | 7.5s at cost 50 |
| `PLANT_COOLDOWN_MAX` | 30s at cost 325 (Bombardino also sets `plantCooldown = 30`) |
| `Override` | optional `definition.plantCooldown` |

Resets on **Start Day**. Not saved.

---

## Brainrot baseline (`Shared.Brainrots`)

Hit-based **defender** HP: `maxHealth / health` = HP lost per monster chew hit
(~100 HP per hit on most units).

| Unit | Cost | Hits | Combat role |
| ---- | ---- | ---- | ----------- |
| Ballerina | 50 | 5 | Economy (25 / 18s; max 10 on the plot) |
| Chimpanzini | 50 | 20 | Wall (~30s vs one Zombie) |
| Tung Tung | 75 | 12 | Melee (55 / 1.5s ≈ 37 DPS; ~5 hits vs 250 HP Zombie) |
| Lirili | 75 | — | One-shot freeze 2 tiles ahead + behind (5s; Mythic 7s); uneatable; plant cooldown 20s |
| Cappuccino | 100 | 5 | Row sniper (50 / 2.0s = 25 DPS; 5 hits vs Zombie) |
| Tralalero | 175 | 5 | Bubble (55 / 5.0s) + 0.5s trap |
| Bombardino | 325 | 1 | Row nuke (1000) — 4 base Zombies or ~17% of base Elite HP |
| Girafa Celestre | 50 | — | One-shot plot fog clear 7s (reach Day 25 or buy early for 50 brains) |
| Brr Brr Patapim | 50 | — | Immune; two hits per swing (1s apart); 6 collapse the grave (unlock: Day 31) |
| Orangutini | 100 | 7 | Pineapple lob (40 / 2s), skips front target when another is behind |
| La Vacca | 75 | — | One-shot neighboring-row pull; base 1-tile targets, evolved exceptions |
| Blueberrinni | 50 | 6 | Ink every 10s; random empty non-grave tile in own row; 50% slow while standing in 7s puddle |
| Boneca | 125 | — | Immune; 5 headbutts, 150 damage + 1s stun each |

Intent: Cappuccino is reliable lane DPS; Tung Tung rewards the front line;
Lirili is a panic freeze (Bombardino-style one-shot); Tralalero is bubble
support; Bombardino is panic clear, not a boss delete.

---

## Monster profiles (`Shared.Monsters`)

Campaign difficulty still ramps via **counts / pacing / species**. Grunt stats
were raised so early boards need real DPS:

| Id | Role | HP | Sec/tile | Chew |
| -- | ---- | -- | -------- | ---- |
| `Zombie` | Grunt (L1+) | 250 | 3.5 | 80 / 1.5s |
| `Goblin` | Fast grunt (L5+) | 350 | 2.7 | 100 / 1.0s |
| `GoblinElite` | Boss (L10, recurs L13/14/17-19) | 6000 | 6.2 | 8000 + one-shot; **laneSpan 3** |
| `Vampire` | Fast grunt (L15+) | 900 | 2.5 | 70 / 1.1s |
| `DukeVampire` | Boss (L20; recurs L24/28/38; Day 40 wave with Queen) | 8000 | 4.8 | 100 / 1.1s; last stand + Terrify |
| `Spider` | Jump grunt (L25+) | 550 | 1.8 | 90 / 1.4s; glass-cannon jumper |
| `QueenSpider` | Boss (L30; recurs L32/37; Day 40 wave with Duke) | 13000 | 6.3 | 120 / 1.5s; laneSpan 3; stun every bite; poison 3%/4s every 2nd bite; no jump |
| `Werewolf` | Fast heavy grunt (L35+) | 1400 | 2.0 | 60 / 1.5s; lifesteal 5% max HP / chew; authored walk/attack clips |
| `GoblinKing` | Boss (Hidden Day finale, after Day 40) | 13000 | 4.0 | 130 / 1.5s; laneSpan 2; +5% max HP / 10s; on spawn, +10% attack for himself and living Goblins; later Goblins inherit while he lives; existing boosts persist; authored walk/attack clips |
| `Skeleton` | Ranged grunt (L31+) | 200 | 4.0 | 90 / 1.5s; stops 3 tiles east and shoots arrows; does not chew |
| `SmallMummy` | Fast grunt (L41+) | 1000 | 2.0 | 100 / 1.5s |
| `Scorpion` | Burrow grunt (L45+) | 500 | 1.8 | 100 / 1.2s; Venom DoT every 3rd bite (3%/4s); digs on plot entry only if the lane has a Brainrot |
| `PharaohMummy` | Boss (L50) | 15000 | 5.0 | 200 / 1.0s; summon SmallMummy ×5 lanes / 20s; steal 1 plant from 3 random lanes / 15s |

Hidden Day Goblins and Goblin Elites (not Goblin King) spawn at **+20%** max HP,
attack speed, and movement speed on top of the figures above. Goblin HP still
ages with the campaign day first; the elite is a boss, so only the +20% applies.

Forest march setup ≈ `SPAWN_COLUMN_OFFSET` × `secondsPerGrid` (~21s Zombie,
~16s Goblin, ~15s Vampire, ~12s Werewolf, ~24s Skeleton).

Chew standoff: monsters stop `MELEE_CLOSE_REACH` (0.42 columns ≈ 7.5 studs)
east of the plant center so models don't overlap.

---

## Day pacing (`Shared.Levels` + `LevelConfig`)

Counts describe authored tuning. The scheduler preserves each spawn’s original
group across transitions. Duplicate-boss guards can still reject an invalid
spawn attempt; that refusal logs a warning. Hidden Day permits its four Elites.

- First spawn group uses a short delay; **≥16–21s** plant time comes from the
  forest march (`SPAWN_COLUMN_OFFSET` × `secondsPerGrid`).
- Adjacent levels change **counts/pacing/species** alongside documented
  non-boss HP aging; Hidden Day adds its explicit Goblin/Elite bonus.
- Big-wave groups use `isBigWave`; warning lead = `BIG_WAVE_WARNING_TIME` (5s).
- Level 10 Goblin Elite wave: `startDelay` 18s before the boss spawns. Level 20
  Duke Vampire wave uses the same 18s lead-in.
- Levels 13/14/17-19 mix a single `GoblinElite` in as a recurring miniboss
  (only sometimes the `isBigWave` finale) rather than a one-off boss.
- **Carry-over retune:** Day 1 total **5** zombies (empty board). Later days
  scale ~8 → 21 enemies (dipping at Levels 10/13/15/17/20 where a new/boss
  species eats a full group slot) so a kept defense still feels challenged.
- **Days 21–24 (Night):** moonlit night, full lawn plantable — same roster mix,
  quieter/harder alternation.
- **Days 25–34 (NightFog):** easternmost **3** lawn columns are unplantable, so
  effective depth shrinks — keep totals in the ~12–16 range through Day 30;
  Days 31–40 are one step lighter (~8–11) because graves add extra spawns.
  Level 31 introduces `Skeleton` + fog **graves**; Queen / Duke recur mid-day
  on 32–33 after the L30 Queen finale.
- **Days 35–40 (NightFogReceded):** fog bank loses **one** column (only 2
  blocked) so players regain a plantable tile; Level 35 introduces `Werewolf`.
- **Days 41–50 (Desert):** sand lawn, no fog; forest replaced by pyramids;
  authored waves: `SmallMummy` from 41, `Scorpion` from 45, `PharaohMummy` on 50.
  Full lawn is plantable so totals sit higher (~16–23, Day 50 dips to 12
  around the boss). No graves.

---

## Player movement (`PlayerConfig` + Speed shop)

Unupgraded walk speed is Roblox default **16** so the HUD Speed upgrade
is worth buying. Twenty levels add **+1 WalkSpeed** each (noticeable over a
couple of ranks). Max is **36**. Brains costs: **6 / 10 / 14 / 19 / 25 / 32 /
41 / 52 / 65 / 80 / 98 / 118 / 142 / 170 / 204 / 245 / 294 / 353 / 424 / 509**.

Magnet starts at **level 1** (everyone has it). Four paid ranks (**30 / 55 /
90 / 150** brains) cut cooldown **90s → 20s** at max and grow pull range by
**1/5 tile** per level (**1.2 → 2.0 tiles** world Chebyshev from the player).
Duration stays **5s**.
Cooldown remaining when a day ends is frozen until the next Start Day.

---

## Where to tune

Daily quests grant 6/12/18 brains per UTC day; weekly quests grant 13/26/39
per Monday-based week. The finite first-time catalog grants 12 base brains,
two Speed levels, one Magnet level, and one free store Brainrot ticket. Maxed
upgrade claims substitute 10 brains. There is no recurring weekly login payout.
Permanent achievements add 75 brains and Campaign milestones add 95. Forest
Rush and the free spin contribute to recurring income after their respective
unlocks. See the configured budget in `ECONOMY.md`. Live completion rates and
spend patterns remain unmeasured.

| What | Where |
| ---- | ----- |
| Unit costs/stats | `Shared.Brainrots`, `Shared.Monsters` |
| Wave content | `Shared.Levels` |
| Weather / fog | `WeatherConfig`, `WeatherUtil` (see `WEATHER.md`) |
| Coins / drops | `EconomyConfig` |
| Leftover coins → brains | `EconomyConfig.COINS_PER_LEFTOVER_BRAIN` |
| Level UX pacing | `LevelConfig` |
| Combat globals | `CombatConfig`, `BrainrotConfig`, `MonsterConfig` |
| GOD ult percents | `Shared.Evolutions` `abilityParams` (`damagePercent`, `travelPercent`, `finisherPercent`, `splashPercent`, `minEnemies`, …) |
| Golden Discount | `EvolutionConfig.PLANT_DISCOUNT_COOLDOWN` + `abilityParams.plantDiscountCooldown` (plot-wide, all Ballerinas) |
| Tralalero CC vs size | `CombatConfig.TRALALERO_CC_RESIST_PER_EXTRA_ROW` (25% per extra row; 5 rows immune) |
| Sword-wave / pillar look | `VfxConfig.SWORD_WAVE_*`; timing in `CombatConfig.SWORD_WAVE_*` |
| Heavy ult VFX | Settings **VFX** High / Low / Off, **Other plots** On / Off. Server always authors the full ult |
| Damage meter ranks | `CombatConfig.DAMAGE_METER_TOP` / `DAMAGE_METER_VISIBLE_ROWS` / `DAMAGE_METER_BROADCAST_INTERVAL` |
| Monster campaign HP scale | `MonsterConfig.STAT_SCALE_*` (non-boss HP only; intro day from `MONSTER_INTRO_SCHEDULE`) |
| Player walk speed / Speed shop | `PlayerConfig.WALK_SPEED`, `ProgressConfig.UPGRADE_CATALOG` |
| Magnet cooldown / duration / range | `MagnetConfig`, Magnet row in `UPGRADE_CATALOG` |
| Brainrot XP grants | `EvolutionConfig` (`KILL_XP`, `FREEZE_XP`, …) |
