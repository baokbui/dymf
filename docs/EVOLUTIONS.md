# BVM Brainrot Evolutions

Each **roster Brainrot** (registry id — Ballerina, Tung Tung, …) has its own
**Brainrot level**, independent of campaign **days**. That meter climbs as the
player uses / progresses that unit (XP rules at impl). At fixed Brainrot
levels they unlock a **five-tier rarity ladder**. Tiers are **cumulative**:
later unlocks add their aura and bonus on top of earlier ones. The base unit
(shop id, core ability) does not change.

This is **not** campaign day 10 / 20 / … (`LevelService` / `highestUnlocked`).
Sheet labels “Level 10” mean **Brainrot level 10**.

Status: ✅ Milestone 19 (ladder + GOD ultimates live)

Authoring source: design sheet (Epic → God). Numbers below are targets,
not live code. “Gold” on the sheet is **coins**.

---

## Brainrot levels

- One level + XP pool **per owned Brainrot id**, shared by every planted copy
  of that unit. Not per tile, not per match. Four Tung Tungs on the lawn share
  one meter.
- Persist via `SaveService` (`SaveData.brainrotXp`, schema **v5**). Server owns
  XP; the client never sets it. XP from a day is **committed on victory** only.
  Defeat / Rewind / leave mid-day restore the Start Day snapshot. **Epic** stat
  overrides and **Legendary** extras are applied at place / restore / claim
  (`Evolutions.applyStats` / `claimedExtras`). **Mythic** and **Immortal**
  passives compose the same way (params merge or extra ability ids). GOD
  ultimates: Tung Tung **Sahur's Wrath** ✅; Ballerina **Jackpot** ✅;
  Chimpanzini **Primal Retaliation** ✅; Lirili **Glacial Dominion** ✅
  (on plant); Cappuccino **Shadow Requiem** ✅; Tralalero **Abyssal Torrent** ✅.
- **How XP is earned** (`EvolutionConfig`):
  - **Normal monster** — `KILL_XP` goes to the **species that landed the last hit**.
    If one Cappuccino kills a Zombie, every Cappuccino (the shared pool) gains
    that XP. Poison / status ticks keep the previous last hit; silent deaths
    (house breach, plot clear) grant nothing. `BubbleTrap` and `MeleeBat` do
    **not** claim last-hit (they use landed-hit jobs instead).
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
  | 19 → 20 (Legendary) | 843 | 61 |
  | 29 → 30 (Mythic) | 3,128 | 224 |
  | 39 → 40 (Immortal) | 11,598 | 829 |
  | 49 → 50 (GOD) | 37,716 | 2,694 |

---

## Tiers

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

## Authoring (sheet)

Live base stats today (for Epic deltas): Ballerina interval **18s**; Chimpanzini
**2000** HP; Tung Tung **1200** HP / **55** dmg; Tralalero interval **5s**;
Cappuccino interval **2s**; Lirili plant cooldown **20s**, freeze **5s** / 2
tiles. Mythic Permafrost overlays freeze duration to **7s**.

**Girafa Celestre**, **Brr Brr Patapim**, and **Bombardino Crocodilo** are not
on the sheet (TBD).

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
| GOD | Sahur's Wrath | Giant bat slams the **whole row** to the plot edge for **1000%** damage, plus **500%** on the adjacent rows. Needs **3+** enemies **or a boss**. **30s** CD. |

### Tralalero Tralala

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Ocean's Rhythm | Attack interval **3s** (from 5s), **+10** damage (**65**, from 55), and **+0.25s** trap (**0.75s**, from 0.5s). |
| Legendary | Bubble Barrage | Shoot **one** bubble from the mouth; it splits into **5** (one per lawn row). Empty rows still get a bubble. Does **not** fire (or start CD) if the plot has **no monsters**. **15s** CD. |
| Mythic | Double Bubble | Each bubble **33%** chance to spawn an extra trap bubble. |
| Immortal | Wound of the Shark | Monsters leaving a bubble are slowed **40%** for **3s**. |
| GOD | Abyssal Torrent | Water jet from the mouth to the end of the row for **15s**. Pierces every monster in that stretch. Each second in the jet deals catalog base damage (**55**) and knocks back **0.25** tiles. Needs **3+** enemies **or a boss**. Easternmost ready Tralalero fires first. **45s** CD. Bubbles pause while it fires. |

Tralalero crowd control (trap, knockback, stun, and the bubble-exit slow) is weaker on bigger monsters: **25%** less at **2** rows, **50%** at **3**, **75%** at **4**, and **immune** at **5**. Damage is not reduced (`CombatConfig.TRALALERO_CC_RESIST_PER_EXTRA_ROW`).

### Cappuccino Assassino

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Espresso Rush | **+50%** attack speed and **+25** damage (**75**, from 50). |
| Legendary | Piercing Brew | For **6s**, knives pierce the first monster and the one behind (flies through graves). **10s** CD. |
| Mythic | Fifth Strike | Every **5th** attack deals **200%** dmg. |
| Immortal | Assassin's Verdict | Execute on hit if target is below **7.5%** HP (**2%** for bosses). |
| GOD | Shadow Requiem | A sword wave flies down the row, growing as it goes. **2000%** plus **100%** per tile, then a last-tile pillar for **+1000%**. Needs **3+** enemies **or a boss**. Easternmost ready Cappuccino fires first. **45s** CD. |

### Lirili Larila

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Cryocycle | Plant recharge **15s** (from 20s). |
| Legendary | Winter's Grasp | Freeze a **whole lane**. |
| Mythic | Permafrost | Freeze duration **7s**. |
| Immortal | Frostbound Neighbor | Also freeze **one adjacent** lawn row (more monsters; ties go **lower**). |
| GOD | Glacial Dominion | Freeze the **whole lawn** (existing freeze duration, **7s** with Permafrost) and apply **25%** Slow that lasts through the freeze plus **3s** after thaw. |

---

## Mutations (not on this sheet)

A separate **mutation** layer (replace or add an unrelated ability, independent
of this ladder) is still named on Milestone 19 but **not authored here**. The
ladder already adds actives / passives / ultimates. Decide at impl whether
mutations stay in M19 or slip to a later pass.

---

## Architecture (when building)

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
  stone, Tenfold, fury, Primal Retaliation, Ranged Rampage) also overlay. **Mythic**
  passives use the same path (`RegenPulse`, `DesperateFury`, `Stoneheart`,
  `TenfoldGuard` with `orbitShield` for the authored Shield clone; params-only
  overlays: Golden Discount, Wound of the Shark, Assassin's Verdict,
  Frostbound Neighbor). **GOD** ultimates use the
  same extras path (`SahurWrath`, `Jackpot`, `PrimalRetaliation`,
  (`SahurWrath`, `Jackpot`, `PrimalRetaliation`, `ShadowRequiem`, `AbyssalTorrent` ✅; Lirili `freezeEntireLawn` params overlay ✅).
- XP grants (`ProgressService.grantKillXp` / `grantBrainrotXp`): last-hit
  species for normal monsters (`SKIP_LAST_HIT` / `HIT_JOB` abilities
  `BubbleTrap` and `MeleeBat` are excluded); boss XP split evenly across living
  plants; support jobs on `GenerateCoins` / `Wall` / `FreezeTime` / landed-hit
  jobs (`BubbleTrap` every 2, `MeleeBat` every 3). Never trust the client.
- Eligibility from that unit’s Brainrot level (+ optional spend); never trust
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
  on plant ✅).
-   Aura VFX: Super Saiyan-style column on planted units (`BrainrotFeedback`);
  Epic purple, Legendary gold, Mythic red-orange, Immortal dark red, GOD rainbow (`EvolutionConfig.worldAura`).
  The server authors a dense flame column (core + extra layer). **High** shows both,
  **Low** keeps a thin core (`BRAINROT_AURA_SPIKES_RATE_LOW`), and **Off** clears the
  flames on that client. The rarity **Highlight outline** stays on every setting.
  Size/speed stay fixed so the column does not grow. Combat and
  unlocks server-authoritative.

See `ROADMAP.md` Milestone 19 for ship criteria.
