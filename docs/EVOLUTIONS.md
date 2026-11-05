# BVM Brainrot Evolutions

Each **roster Brainrot** (registry id — Ballerina, Tung Tung, …) has its own
**Brainrot level**, independent of campaign **days**. That meter climbs as the
player uses that unit (XP rules below). At fixed Brainrot
levels they unlock a **five-tier rarity ladder**. Tiers are **cumulative**:
later unlocks add their aura and bonus on top of earlier ones. The base unit
(shop id, core ability) does not change.

This is **not** campaign day 10 / 20 / … (`LevelService` / `highestUnlocked`).
Sheet labels “Level 10” mean **Brainrot level 10**.

Status: ✅ Milestone 19 (ladder + GOD ultimates live)

The live catalog is `Shared.Evolutions`; XP, gates, colors, and claim costs live
in `EvolutionConfig`. Descriptions below summarize implemented behavior.
“Gold” in older design sheets means **coins**. Nine units have full tracks;
Blueberrinni, Girafa, Patapim, and Bombardino have no authored tiers yet.

---

## Brainrot levels

- One level + XP pool **per owned Brainrot id**, shared by every planted copy
  of that unit. Not per tile, not per match. Four Tung Tungs on the lawn share
  one meter.
- Persist via `SaveService` (`SaveData.brainrotXp`, introduced in **v5**, current schema **v13**). Server owns
  XP; the client never sets it. XP from a day is **committed on victory** only.
  Defeat / Rewind / leave mid-day restore the Start Day snapshot. **Epic** stat
  overrides and **Legendary** extras are applied at place / restore / claim
  (`Evolutions.applyStats` / `claimedExtras`). **Mythic** and **Immortal**
  passives compose the same way (params merge or extra ability ids). GOD
  ultimates: Tung Tung **Sahur's Wrath** ✅; Ballerina **Jackpot** ✅;
  Chimpanzini **Primal Retaliation** ✅; Lirili **Glacial Dominion** ✅
  (on plant); Cappuccino **Shadow Requiem** ✅; Tralalero **Abyssal Torrent** ✅;
  Boneca **Last Laugh** ✅ (on her last headbutt); Orangutini **Pineapple Express** ✅;
  La Vacca **Black Hole** ✅ (on plant).
- **How XP is earned** (`EvolutionConfig`):
  - **Normal monster** — `KILL_XP` goes to the **species that landed the last hit**.
    If one Cappuccino kills a Zombie, every Cappuccino (the shared pool) gains
    that XP. Poison / status ticks keep the previous last hit; silent deaths
    (house breach, plot clear) grant nothing. `BubbleTrap`, `BubbleBarrage`, `MeleeBat`, and
    `TileTrap` do **not** claim last-hit (they use landed-hit jobs instead).
  - **Boss** — `BOSS_XP` is split **evenly across every living plant** on the
    lawn (integer remainder on the first plants). Four Tungs + one Ballerina
    → Tung pool gets four shares, Ballerina one. Empty lawn → no XP.
  - **Support jobs** (ability id, not unit name; `grantBrainrotXp` broadcasts
    so inspect bars update; broadcasts are coalesced):
    - `GenerateCoins` — `COIN_XP` per coin actually spat onto the lawn.
    - `Wall` — `SOAK_XP` each time the plant takes a damage tick (chew / arrow).
    - `FreezeTime` — `FREEZE_XP` (20) per monster frozen on that cast (Lirili is one-shot and has no last-hit).
    - `BubbleTrap` — `BUBBLE_XP` every `BUBBLE_XP_HITS` (2) bubbles that land
      (**instead of** last-hit).
    - `MeleeBat` — `MELEE_XP` every `MELEE_XP_HITS` (3) connecting hits
      (**instead of** last-hit), including Ranged Rampage bats.
    - `TileTrap` — `8` XP every **2** landed headbutts (**instead of** last-hit).
      Lightning bolts, Rolling Thunder currents, and Last Laugh add no extra XP.
- Campaign days stay the PvZ loop. A player can be on Day 3 with a level-20
  Tung Tung, or Day 40 with a level-8 Ballerina.
- Inventory + field inspect show `EvolutionConfig.formatProgress` (level and
  XP into the current level). The **XP to next level** grows every step
  (`floor(XP_BASE * XP_GROWTH^(n-1))`, always at least +1 over the previous
  cap). Kill / boss grants stay flat, so later levels take more kills. Examples
  (current `XP_BASE` 70, `XP_GROWTH` 1.14, `KILL_XP` 14):

  | Brainrot level | XP to next | Last-hit kills (approx.) |
  | -------------- | ---------- | ------------------------ |
  | 1 → 2 | 70 | 5 |
  | 9 → 10 (Epic) | 199 | 15 |
  | 19 → 20 (Legendary) | 740 | 53 |
  | 29 → 30 (Mythic) | 2,744 | 196 |
  | 39 → 40 (Immortal) | 10,173 | 727 |
  | 49 → 50 (GOD) | 37,716 | 2,694 |

---

## Tiers

Claim costs: **Epic 25**, **Legendary 50**, **Mythic 100**, **Immortal 200**,
**GOD 400** brains (`EvolutionConfig.TIER_BRAINS`). The previous tier must be
claimed first; reaching the level alone does not grant stats or abilities.

Unlock gate is **Brainrot level** (the unit’s own meter).

| Rarity | Brainrot level | Aura | Type |
| ------ | -------------- | ---- | ---- |
| **Common** | 1 | White | Base ability |
| **Epic** | 10 | Purple | Stat boost |
| **Legendary** | 20 | Gold | Active |
| **Mythic** | 30 | Red-orange | Passive |
| **Immortal** | 40 | Dark red | Passive |
| **GOD** | 50 | Rainbow | Ultimate |

Visual: aura color tracks the **highest** owned (claimed) tier for that Brainrot.
Planted units with Epic+ claimed get a Super Saiyan column (stretched flame
spikes, thin silhouette outline) tinted by
`EvolutionConfig.worldAura` — purple at Epic, gold at Legendary, red-orange
at Mythic, dark red at Immortal, rainbow at GOD (`BrainrotFeedback.applyAura`). Mesh is not filled. Stacked FX and later-tier
colors land with those tiers. Prefer tint / particle auras over a full mesh
swap unless a prestige `modelId` is authored later.

Spend (brains) to **claim** a tier after the Brainrot level gate. Reaching
the level lights the inspect row (light rarity fill, shiny rarity title);
the bonus is not owned until the player spends `EvolutionConfig.TIER_BRAINS`
via `EvolveBrainrot`. Server owns unlocks; client UI is display + intent.

---

## Types (how bonuses compose)

| Type | Runtime shape |
| ---- | ------------- |
| **Stat boost** | Overrides on the common Brainrot definition (HP, damage, interval, plant cooldown, …). Keep core `ability` id. **Epic ✅** |
| **Active** | Extra ability on a cooldown (player-facing “active”). **Legendary ✅** |
| **Passive** | Always-on extra ability / proc (no press). **Mythic ✅** |
| **Ultimate** | Extra ability, long cooldown. |

Resolve extras from **ability ids** on the evolution rows — never
`if name == "Tung Tung"`. Multi-ability tick stays on `BrainrotBehavior` /
Abilities. Combat math stays in `CombatService`.

---

## Authoring (live catalog)

Live base stats today (for Epic deltas): Ballerina interval **18s**; Chimpanzini
**2000** HP; Tung Tung **1200** HP / **55** dmg; Tralalero interval **5s**;
Cappuccino interval **2s**; Lirili plant cooldown **20s**, freeze **5s** / 2
tiles. Mythic Permafrost overlays freeze duration to **7s**. Boneca **5**
headbutts (`charges`) / **150** dmg / **1s** stun. Orangutini **40** dmg / **2s**
interval / **700** HP. La Vacca plant recharge **18s**, pull from neighboring rows, 1-tile monsters only.

**Girafa Celestre**, **Brr Brr Patapim**, **Blueberrinni Octopusini**, and
**Bombardino Crocodilo** have no evolution rows yet.

### Ballerina Cappucina

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Wallet Ballet | Coin interval **12s** (from 18s). |
| Legendary | Golden Waltz | Every **30s**, produce coins **2×** faster for **6s**. |
| Mythic | Encore | Each coin produced: **30%** chance to produce one extra. |
| Immortal | Golden Discount | Next plant of **any** Brainrot costs **50%**. **20s** cooldown shared by every planted Ballerina. |
| GOD | Jackpot | Produce coins **3×** faster for **10s**; each coin during the ultimate **33%** extra coin (independent of Encore). **30s** CD. |

### Chimpanzini Bananini

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Goliath | **4000** HP (from 2000). **Immovable**: cannot be stolen or moved off its tile. |
| Legendary | Banana Bastion | Shield **500** HP every **10s**. The rightmost 500 of the current HP bar paints blue (green returns when the shield drops); translucent blue bubble VFX on the plant. |
| Mythic | Jungle Vitality | Heal **5%** max HP every **5s**. |
| Immortal | Stoneheart | Once per plant: below **10%** HP, stone / invulnerable **10s**. Can't act while stone. |
| GOD | Primal Retaliation | **15s**: reflect **25%** of chew damage to that monster. **30s** CD. |

### Tung Tung Sahur

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Tung Tung Training | **1500** HP / **100** dmg (from 1200 / 55). |
| Legendary | Ranged Rampage | Throw a spinning bat down the **whole row** for **10s**. Lawn hits knock back a **quarter tile**. **20s** CD. |
| Mythic | Desperate Fury | Once per plant: below **50%** HP, **+50%** attack speed. |
| Immortal | Tenfold Guard | Every **10** attacks: shield **30%** max HP for **5s**. Stun-immune while shielded. |
| GOD | Sahur's Wrath | Giant bat slams from him to the plot edge for **1000%** damage, plus **500%** on the adjacent rows. Monsters that have already walked past his tile are left alone. Needs **3+** enemies still in front **or a boss** still in front. **30s** CD. |

### Tralalero Tralala

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Ocean's Rhythm | Attack interval **3s** (from 5s), **+10** damage (**65**, from 55), and **+0.25s** trap (**0.75s**, from 0.5s). |
| Legendary | Bubble Barrage | Shoot **one** bubble from the mouth; it splits into **5** (one per lawn row). Empty rows still get a bubble. Only fires when a monster **in his own row** is on the lawn and still in front. **15s** CD. |
| Mythic | Double Bubble | Each bubble **33%** chance to spawn an extra trap bubble. |
| Immortal | Wound of the Shark | Monsters leaving a bubble are slowed **40%** for **3s**. |
| GOD | Abyssal Torrent | Water jet from the mouth to the end of the row for **15s**. Pierces every monster in that stretch. Monsters that have already walked past him are left alone. Each second in the jet deals catalog base damage (**55**), plus **20%** more for every tile closer to his plant than the east edge of the row. Needs **3+** enemies still in front **or a boss** still in front. Easternmost ready Tralalero fires first. **45s** CD. Bubbles pause while it fires. |

Tralalero crowd control (trap, knockback, stun, and the bubble-exit slow) is weaker on bigger monsters: **25%** less at **2** rows, **50%** at **3**, **75%** at **4**, and **immune** at **5**. Damage is not reduced (`CombatConfig.TRALALERO_CC_RESIST_PER_EXTRA_ROW`).

### Cappuccino Assassino

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Espresso Rush | **+50%** attack speed and **+25** damage (**75**, from 50). |
| Legendary | Piercing Brew | For **6s**, knives pierce the first monster and the one behind (flies through graves). **10s** CD. |
| Mythic | Fifth Strike | Every **5th** attack deals **200%** dmg. |
| Immortal | Assassin's Verdict | Execute on hit if target is below **7.5%** HP (**2%** for bosses). |
| GOD | Shadow Requiem | A sword wave flies down the row, growing as it goes. **2000%** at the first tile away, plus **100%** per additional tile, then a last-tile pillar for **+1000%**. Monsters that have already walked past him are left alone. Needs **3+** enemies still in front **or a boss** still in front. Easternmost ready Cappuccino fires first. **45s** CD. |

### Lirili Larila

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Cryocycle | Plant recharge **15s** (from 20s). |
| Legendary | Winter's Grasp | Freeze a **whole lane**. |
| Mythic | Permafrost | Freeze duration **7s**. |
| Immortal | Frostbound Neighbor | Also freeze **one adjacent** lawn row (more monsters; ties go **lower**). |
| GOD | Glacial Dominion | Freeze the **whole lawn**, including monsters that have already walked past her (existing freeze duration, **7s** with Permafrost) and apply **25%** Slow that lasts through the freeze plus **3s** after thaw. |

### La Vacca Saturno Saturnita

One-shot on plant. She still vanishes. **Black Hole** replaces the neighbor pull. Wider Well and Hard Landing stay on the normal pull.

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Shorter Year | Plant recharge **12s** (from 18s). |
| Legendary | Wider Well | Pulls from **two rows out**. A middle tile can pull four monsters. An edge tile pulls two. Still one per row. |
| Mythic | Hard Landing | Each pulled monster is stunned **1.5s** when it lands. |
| Immortal | Heavier Bodies | She can pull monsters **2 tiles** wide. Anything **3 or wider** stays put. |
| GOD | Black Hole | She becomes a black hole and swallows the **3** closest legal monsters on the lawn, including ones that have already walked past her. Each shrinks as it is pulled in and is removed with no death pose. The kill still counts as hers. The hole stays for **3s**, then collapses. Bosses are left alone. Heavier Bodies still decides who else can be swallowed. The hole floats and bobs above the tile while streaks fly straight in, fade, and new ones appear. High: black sphere, hot inner disc, orange outer disc, bright photon ring, more streaks. Low: sphere, one disc, ring, fewer streaks. Off: no hole (she still folds away, and the monsters still shrink out). |

### Orangutini Ananassini

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Heavy Fruit | **60** damage (from 40) and attack interval **1.5s** (from 2s). |
| Legendary | Second Serving | Every **4s**, that throw also sends a pineapple at the next monster behind the usual target. With one or two monsters in the row, the extra fruit hits the furthest one. Params-only (`secondServingCooldown`); it rides the normal throw. |
| Mythic | Juice Splash | Each pineapple also damages the monster it jumped over for **50%**. A shot at the front monster (nothing to jump) has no splash. |
| Immortal | Overripe | A pineapple that kills its target deals **80%** of that shot's damage to every other monster on that tile. |
| GOD | Pineapple Express | A giant pineapple arcs to the **furthest** monster in the row for **1200%** of his current damage and stuns it for **1.5s**. Any monster in the row is enough. Holds the normal throw for the clip. **30s** CD. |

### Boneca Ambalabu

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Thick Skull | **200** damage (from 150). Headbutt count stays **5**. |
| Legendary | God of Thunder | **Every headbutt** also calls down a blue lightning bolt on that monster: **+200** damage on top of the headbutt, and its stun becomes **1.5s**. No cooldown; params-only (`lightningDamage` / `lightningStunDuration`). VFX: High glowing bolt + forks + flash + sparks, Low thin bolt + flash, Off none. |
| Mythic | Rattled | When a headbutt stun ends, that monster is slowed **30%** for **3s**. |
| Immortal | Rolling Thunder | Each lightning strike sends electric currents from the struck monster into **3–4** other monsters within **2 tiles** (any row, closest first; fewer if fewer are nearby): **50** damage each, no stun. Params-only (`chainDamage` / `chainMinTargets` / `chainMaxTargets` / `chainRangeTiles`). VFX: jagged blue arcs from the struck monster to each one (High glowing + spark pop, Low thin, Off none). |
| GOD | Last Laugh | Her last headbutt ends in a mushroom cloud blast: **450** damage on her tile and **one tile east**, then she's gone. The tile behind her is not blasted. |

Her finale (`TileTrapFinale`): Last Laugh if claimed, otherwise a plain poof.

---

## Mutations (Milestone 25)

A separate **mutation** layer (replace or add an unrelated ability, independent
of this ladder) is **post-launch** (`ROADMAP.md` Milestone 25). It is not
authored on this sheet. The ladder already adds actives, passives, and ultimates.

---

## Architecture ✅

- Data-driven catalog keyed by `brainrotId` + rarity (config / registry — not
  hardcoded in combat).
- Persist **Brainrot XP** per id via `SaveData.brainrotXp` (save v5). Claimed
  evolution tiers via `SaveData.evolutions` (save **v6**). Do not reuse
  campaign `currentLevel` / `highestLevel`. **Epic** stats compose onto
  placements via `Evolutions.applyStats` + `BrainrotService.applyEvolutionStats`.
  **Legendary** extras tick via `Evolutions.claimedExtras` +
  `BrainrotBehavior.tickExtras` (ability ids, never unit names). Exclusive
  extras (Piercing Brew, Shadow Requiem, Sahur's Wrath, Bubble Barrage) never
  overlap each other or the core attack; GOD wins the slot if two are ready.
  Ballerina **Golden Waltz** / **Jackpot** set `exclusive = false` so they can
  stack with coin spit (and each other). Silent passives (shields, regen,
  stone, Tenfold, fury, Primal Retaliation, Ranged Rampage) also overlay. A
  regen pulse that actually raises HP shows green "+" marks around the
  Brainrot. **Mythic**
  passives use the same path (`RegenPulse`, `DesperateFury`, `Stoneheart`,
  `TenfoldGuard` with `orbitShield` for the authored Shield clone; params-only
  overlays: Golden Discount, Wound of the Shark, Assassin's Verdict,
  Frostbound Neighbor, Rattled, Rolling Thunder, Second Serving, Juice Splash,
  Overripe, Wider Well, Hard Landing, Heavier Bodies). **GOD** ultimates use the
  same extras path (`SahurWrath`, `Jackpot`, `PrimalRetaliation`,
  `ShadowRequiem`, `AbyssalTorrent`, `PineappleExpress` ✅; Lirili `freezeEntireLawn` and Boneca
  `lastLaughDamage`, and La Vacca `blackHole` params overlays ✅). Boneca **God of Thunder** is a
  params-only Legendary overlay her headbutt reads.
- XP grants (`ProgressService.grantKillXp` / `grantBrainrotXp`): last-hit
  species for normal monsters (`SKIP_LAST_HIT` / `HIT_JOB` abilities
  `BubbleTrap`, `MeleeBat`, and `TileTrap` are excluded); boss XP split evenly
  across living plants; support jobs on `GenerateCoins` / `Wall` / `FreezeTime`
  / landed-hit jobs (`BubbleTrap` every 2, `MeleeBat` every 3, `TileTrap`
  every 2). Never trust the client.
- Eligibility requires that unit’s level, previous claimed tier, and brains spend; never trust
  the client, never gate on campaign day unless a later pass adds it.
- Grants / composition on the server (`ProgressService` or a dedicated API).
- Inventory / field inspect: portrait header (name, HP bar, level, XP bar) plus
  **Stats** (`BrainrotInfo.statRows`: cost, damage, atk. speed, range, …) and
  **Current Evolution** (white Common base ability, then Epic→God gray
  until the Brainrot level gate; at the gate the row uses a light rarity fill
  and a shiny rarity title, with a lock until brains claim and a confirm
  prompt on click). **Epic** stats apply once claimed;   **Legendary** extras and **Mythic** / **Immortal** passives tick /
  overlay in combat. **GOD** ultimates tick the same extras path
  (`SahurWrath`, `Jackpot`, `PrimalRetaliation`, `ShadowRequiem`, `AbyssalTorrent` ✅; Lirili Glacial Dominion
  on plant ✅; Boneca Last Laugh on her last headbutt ✅; Orangutini Pineapple Express ✅; La Vacca Black Hole on plant ✅).
-   Aura VFX: Super Saiyan-style column on planted units (`BrainrotFeedback`);
  Epic purple, Legendary gold, Mythic red-orange, Immortal dark red, GOD rainbow (`EvolutionConfig.worldAura`).
  The server authors a dense flame column (core + extra layer). **High** shows both,
  **Low** keeps a thin core (`BRAINROT_AURA_SPIKES_RATE_LOW`), and **Off** clears the
  flames on that client. The rarity **Highlight outline** stays on every setting.
  Size/speed stay fixed so the column does not grow. Combat and
  unlocks server-authoritative.

See `ROADMAP.md` Milestone 19 for ship criteria.
