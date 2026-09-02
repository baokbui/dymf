# BVM Brainrot Evolutions

Each **roster Brainrot** (registry id — Ballerina, Tung Tung, …) has its own
**Brainrot level**, independent of campaign **days**. That meter climbs as the
player uses / progresses that unit (XP rules at impl). At fixed Brainrot
levels they unlock a **five-tier rarity ladder**. Tiers are **cumulative**:
later unlocks add their aura and bonus on top of earlier ones. The base unit
(shop id, core ability) does not change.

This is **not** campaign day 10 / 20 / … (`LevelService` / `highestUnlocked`).
Sheet labels “Level 10” mean **Brainrot level 10**.

Status: 🔜 Milestone 19

Authoring source: design sheet (Epic → Immortal). Numbers below are targets,
not live code. “Gold” on the sheet is **coins**.

---

## Brainrot levels

- One level + XP pool **per owned Brainrot id**, shared by every planted copy
  of that unit. Not per tile, not per match. Four Tung Tungs on the lawn share
  one meter.
- Persist via `SaveService` (`SaveData.brainrotXp`, schema **v5**). Server owns
  XP; the client never sets it. Combat bonuses from tiers are **not** applied
  yet (still M19).
- **How XP is earned** (`EvolutionConfig`):
  - **Normal monster** — `KILL_XP` goes to the **species that landed the last hit**.
    If one Tung kills a Zombie, every Tung (the shared pool) gains that XP.
    Poison / status ticks keep the previous last hit; silent deaths (house
    breach, plot clear) grant nothing.
  - **Boss** — `BOSS_XP` is split **evenly across every living plant** on the
    lawn (integer remainder on the first plants). Four Tungs + one Ballerina
    → Tung pool gets four shares, Ballerina one. Empty lawn → no XP.
  - **Support jobs** (ability id, not unit name; `grantBrainrotXp` broadcasts
    so inspect bars update):
    - `GenerateCoins` — `COIN_XP` per coin actually spat onto the lawn.
    - `Wall` — `SOAK_XP` each time the plant takes a damage tick (chew / arrow).
    - `FreezeTime` — `FREEZE_XP` per monster frozen on that cast.
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
  | 39 → 40 (Celestial) | 11,598 | 829 |
  | 49 → 50 (Immortal) | 37,716 | 2,694 |

---

## Tiers

Unlock gate is **Brainrot level** (the unit’s own meter).

| Rarity | Brainrot level | Aura | Type |
| ------ | -------------- | ---- | ---- |
| **Common** | 1 | White | Base ability |
| **Epic** | 10 | Purple | Stat boost |
| **Legendary** | 20 | Gold | Active |
| **Mythic** | 30 | Red-orange | Passive |
| **Celestial** | 40 | Dark green | Passive |
| **Immortal** | 50 | Dark red | Ultimate |

Visual: aura color tracks the **highest** owned tier for that Brainrot (stacked
FX optional). Prefer tint / attachment auras over a full mesh swap unless a
prestige `modelId` is authored later.

Spend (brains) to **claim** a tier after the Brainrot level gate. Reaching
the level lights the inspect row (light rarity fill, shiny rarity title);
the bonus is not owned until the player spends `EvolutionConfig.TIER_BRAINS`
via `EvolveBrainrot`. Server owns unlocks; client UI is display + intent.

---

## Types (how bonuses compose)

| Type | Runtime shape |
| ---- | ------------- |
| **Stat boost** | Overrides on the common Brainrot definition (HP, damage, interval, plant cooldown, …). Keep core `ability` id. |
| **Active** | Extra ability on a cooldown (player-facing “active”). |
| **Passive** | Always-on extra ability / proc (no press). |
| **Ultimate** | Extra ability, long cooldown. |

Resolve extras from **ability ids** on the evolution rows — never
`if name == "Tung Tung"`. Multi-ability tick stays on `BrainrotBehavior` /
Abilities. Combat math stays in `CombatService`.

---

## Authoring (sheet)

Live base stats today (for Epic deltas): Ballerina interval **18s**; Chimpanzini
**2000** HP; Tung Tung **1200** HP / **55** dmg; Tralalero interval **5s**;
Cappuccino interval **2s**; Lirili plant cooldown **20s**, freeze **7s** / 2
tiles. Lirili Mythic “freeze 7s” already matches live freeze duration — retune
the base or the row at impl.

**Girafa Celestre**, **Brr Brr Patapim**, and **Bombardino Crocodilo** are not
on the sheet (TBD).

### Ballerina Cappucina

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Wallet Ballet | Coin interval **12s** (from 18s). |
| Legendary | Golden Waltz | Every **30s**, generate 1 coin, then produce coins **2×** faster for **6s**. |
| Mythic | Encore | Each coin produced: **30%** chance to produce one extra. |
| Celestial | Golden Discount | When producing a coin, the next Brainrot plant costs **50%** (which plant / stacking — impl). |
| Immortal | Jackpot | Produce coins **3×** faster; each coin during the ultimate **33%** extra coin. **30s** CD. |

### Chimpanzini Bananini

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Goliath | **4000** HP (from 2000). |
| Legendary | Banana Bastion | Shield **500** HP every **10s**. |
| Mythic | Jungle Vitality | Heal **5%** max HP every **5s**. |
| Celestial | Stoneheart | Once per plant: below **10%** HP, stone / invulnerable **10s**. Cannot use active or ultimate while stone. |
| Immortal | Primal Retaliation | **15s**: reflect **25%** of chew/attack damage to that monster. **30s** CD. |

### Tung Tung Sahur

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Tung Tung Training | **1500** HP / **100** dmg (from 1200 / 55). |
| Legendary | Ranged Rampage | Ranged attacker for **10s**. |
| Mythic | Desperate Fury | Once per plant: below **50%** HP, **+50%** attack speed. |
| Celestial | Tenfold Guard | Every **10** attacks: shield **30%** max HP for **5s**; stun-immune while shielded. |
| Immortal | Sahur's Wrath | Hit the **entire lane** once for **1000%** of original damage. **30s** CD. |

### Tralalero Tralala

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Ocean's Rhythm | Attack interval **3s** (from 5s). |
| Legendary | Bubble Barrage | Fire **5** bubbles at once, **one per lawn row**; each traps. **15s** CD. |
| Mythic | Double Bubble | Each bubble **33%** chance to spawn an extra trap bubble. |
| Celestial | Wound of the Shark | Monsters leaving a bubble are slowed **40%** for **3s**. |
| Immortal | Tidal Cataclysm | Lane tsunami: knockback + stun, then slow **30%** for **3s**. |

### Cappuccino Assassino

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Espresso Rush | **+50%** attack speed. |
| Legendary | Piercing Brew | Attack pierces the first monster: **100%** dmg to it and the one behind. **10s** CD. |
| Mythic | Fifth Strike | Every **5th** attack deals **200%** dmg. |
| Celestial | Assassin's Verdict | Execute on hit if target is below **7.5%** HP (**2%** for bosses). |
| Immortal | Shadow Requiem | Vanish to the east end of the lane, run back, stab every monster in the path for **2000%** dmg. **45s** CD. |

### Lirili Larila

| Tier | Name | Effect |
| ---- | ---- | ------ |
| Epic | Cryocycle | Plant recharge **15s** (from 20s). |
| Legendary | Winter's Grasp | Freeze a **whole lane**. |
| Mythic | Permafrost | Freeze duration **7s**. |
| Celestial | Frostbound Neighbor | Also freeze **one adjacent** lane. |
| Immortal | Glacial Dominion | Freeze the **whole lawn** and apply **25%** slow for **3s**. |

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
  campaign `currentLevel` / `highestLevel`. Combat bonuses 🔜.
- XP grants (`ProgressService.grantKillXp` / `grantBrainrotXp`): last-hit
  species for normal monsters; boss XP split evenly across living plants;
  support jobs on `GenerateCoins` / `Wall` / `FreezeTime`. Never trust the
  client.
- Eligibility from that unit’s Brainrot level (+ optional spend); never trust
  the client, never gate on campaign day unless a later pass adds it.
- Grants / composition on the server (`ProgressService` or a dedicated API).
- Inventory / field inspect: portrait header (name, HP bar, level, XP bar) plus
  **Current Evolution** (white Common base ability, then Epic→Immortal gray
  until the Brainrot level gate; at the gate the row uses a light rarity fill
  and a shiny rarity title, with a lock until brains claim and a confirm
  prompt on click). Combat
  bonuses still 🔜.
- Aura VFX client-side; combat and unlocks server-authoritative.

See `ROADMAP.md` Milestone 19 for ship criteria.
