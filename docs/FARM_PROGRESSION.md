# Farm progression — Milestone 21B

Status: 🛠 Core implementation verified with isolated fixtures and Studio UI
previews. Live campaign playthrough, real save/rejoin and device QA remain open.

## Day stars

Every numbered campaign clear earns 1–3 stars. The server records breaches and
elapsed active time from the start of that attempt. The highest satisfied tier
wins. Best stars per day persist under `dayStars.Level1` through `Level50`.
Players can inspect the requirements with the Day tab's Star goals button.

Goals rotate deterministically every four days, keeping replays predictable.

| Day pattern | Two stars | Three stars |
| --- | --- | --- |
| 1, 5, 9, … | Finish with 3+ hearts | Zero breaches this attempt |
| 2, 6, 10, … | At most 2 breaches | Zero breaches and finish within the time goal |
| 3, 7, 11, … | At most 1 breach | Zero breaches |
| 4, 8, 12, … | Finish with 2+ hearts | At most 1 breach and finish within the time goal |

An earlier day's heart loss does not prevent earning a zero-breach rating.
The time goal is the larger of 180 + 8 × day number and the authored spawn
schedule duration plus 120 seconds. The Day goals panel shows the exact limit.
Elapsed time begins with Active, after the countdown.

Day brains use 1×, 1.25× or 1.5× the existing day reward, rounded down, with a
minimum bonus of zero, one or two brains so each extra star increases rewards
on early days. Leftover-coin conversion follows the existing rules. Every
clear, including a replay, rolls 2, 4 or 6 individual shards for 1, 2 or 3 stars.
The victory popup shows stars, brains and awarded species/counts. Daily
Challenge and Hidden Day retain their existing reward paths.

## Regional shards

FarmProgression derives pools from the campaign's authored spawn groups.

| Days | Reward region |
| --- | --- |
| 1–20 | Daytime Forest |
| 21–40 | Night Forest, including Goblin King |
| 41–50 | Desert |

Each roll awards one species-specific shard. A pool may award species appearing
later within the same region. Common species have weights of 60–100. Boss
weights are 1–2. Pharaoh Mummy has weight 0.2. These are relative weights, with
actual probability equal to the species weight divided by its pool's total.

Shards appear in Inventory → Items. Combine spends that species' required
shards and creates an individual farm monster of a randomly selected size tier. Players
can combine more shards to form additional monsters of the same species. Existing
collected monsters migrate to one Medium individual per owned species. New numbered clears award
shards rather than automatic collection, and campaign-frontier backfill has
been removed. Reset Progress clears shards, star records and farm monsters.

## Species and income

Initial tuning lives in Shared.Config.FarmProgressionConfig. Income is accrued
as fractional brains and paid in whole brains by the server's farm update.
Resident nameplates display the rate in brains per second. The outside farm
sign displays only the owner's farm name.

| Species | Shards to combine | Income interval per brain |
| --- | ---: | --- |
| Zombie | 15 | 1,800 seconds |
| Goblin | 20 | 1,200 seconds |
| Vampire | 25 | 900 seconds |
| Spider | 25 | 750 seconds |
| Werewolf / Skeleton | 30 | 600 seconds |
| Small Mummy | 35 | 450 seconds |
| Scorpion | 40 | 360 seconds |
| Goblin Elite | 15 | 180 seconds |
| Duke Vampire | 15 | 120 seconds |
| Necromancer | 15 | 100 seconds |
| Queen Spider | 15 | 90 seconds |
| Goblin King | 20 | 60 seconds |
| Pharaoh Mummy | 25 | 30 seconds |

The farm displays player-selected individual monsters up to purchased capacity.
Inventory → Pets places/removes owned instances. Removed pets remain in storage
and earn no income. New combine/fusion outputs begin off-farm; old saves retain
their previous resident selection until edited. See HOUSE.md.
Income remains online-only. Fractional accrued brains reset with the session.
Whole credited brains persist through ordinary progression saves.

## Rare sky drops

During an active numbered day, the server rolls every 60 seconds. There is a
2% chance of a regional boss shard and a mutually exclusive 0.1% chance of a Pharaoh Mummy
shard. At most one sky shard spawns per attempt. The major-boss tier is available
across campaign regions. Regional boss selection is uniform among eligible
non-major bosses. These odds and limits are initial tuning values.

A luminous shard falls onto a random tile over 1.5 seconds. The player can
collect it using a proximity prompt within 10 studs. The owner and distance are
validated by the server, and collection is enabled after landing. Pickups
expire 30 seconds after spawning (including the fall) and are cleaned up when their attempt ends. A collected
sky shard survives a later defeat through ordinary progression saving.

## Authority and persistence

FarmProgressionService owns attempt measurements, reward rolls, sky drops and
combination requests. LevelService starts and resolves numbered attempts and
issues the corresponding brains/shard rewards. ProgressService owns live
monsterShards, dayStars and collectedMonsters. SaveService alone writes them.

Save schema v15 adds monsterShards and dayStars maps. Missing maps become empty.
Combining uses the existing serialized retention writer with the internal
Monster transaction kind. The shard spend and monster unlock save together
before live success. Its grant merges with shard gains and queued snapshots
that arrive while the write yields. Repeated species are allowed. Insufficient shards, invalid species, concurrent
writes and unavailable saves are rejected. Schema v16 adds individual outputs
and operation receipts; see the transaction rules below.

Day ratings and ordinary clear/pickup grants use normal progression/autosave
durability, matching existing campaign rewards. Drop instances, timers and
partial farm income are session state.

## Verification

FarmProgression.spec covers all 50 day pools/reward counts, early-day brain
bonuses, varied goals, inherited heart loss, map sanitization and combining.
FarmService.spec covers attempt ratings, a forced rare major drop, the drop cap,
stale attempt pickups and request limiting. SaveRetention.spec verifies durable
spend/output, retry idempotency and a concurrent shard gain/save during a
combine, alongside the existing retention and session writer regressions.
HouseService.spec covers species income, capacity and resident cleanup.

## Individual monsters, size tiers and fusion

Save schema v16 adds farmMonsters, an array of unique uid/monsterId/tier records,
and farmReceipts for recent durable operation outcomes. Level, visual scale and
income multiplier are derived from the authoritative tier config. Existing
species-only saves become one Medium instance per species with stable legacy
ids. An explicitly empty instance inventory remains empty. Reset clears the
instance inventory and receipts.

Resident nameplates display Size, Monster name, Level, then Brains/second. The
four-line billboard is anchored above the head on every model size.

| Tier | Level | Model scale | Income multiplier | Shard combine chance |
| --- | ---: | ---: | ---: | ---: |
| Tiny | 1 | 0.45× | 0.25× | 45% |
| Small | 2 | 0.7× | 0.5× | 30% |
| Medium | 3 | 1× | 1× | 18% |
| Big | 5 | 1.35× | 1.75× | 5% |
| Gigantic | 8 | 1.7× | 3× | 1.7% |
| Titanic | 12 | 2.1× | 5× | 0.3% |

These initial values live in MonsterFusionConfig. Tier levels are fixed size
ratings. The current feature has no separate monster XP track or additional
level income multiplier. Size multiplies each species' baseline rather than
replacing it: a Titanic Zombie earns 5/1800 ≈ 0.002778 brains/s, less than
a Big Goblin Elite at 1.75/180 ≈ 0.009722 brains/s.

The dedicated Fusion page lists each individual monster with its tier, level
and income. Its drawer icon sits immediately after Inventory. Players select 3–5 owned instances of one species, inspect the displayed
large-tier odds, and press Fuse. All selected inputs are consumed for one new
individual of the same species.

| Inputs | Tiny | Small | Medium | Big | Gigantic | Titanic |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 3 | 35% | 28% | 22% | 10% | 4% | 1% |
| 4 | 28% | 25% | 24% | 15% | 6% | 2% |
| 5 | 20% | 22% | 25% | 20% | 9% | 4% |

The input count determines the outcome weights. Input size does not change the
weights in this version. Every recipe can produce any size, including a size
below its ingredients. The farm accrues the sum of species rate × tier income
multiplier for its displayed residents.

Fusion and shard combining share SaveService's serialized writer. The server
validates exact input ids, distinctness, ownership, species and count. It rolls
one output before the write, then saves the consumed ids/shards and output in
one revision-guarded record. Queued saves and concurrent gains merge the same
grant. Network requests include an operation id, and the latest 24 operation
receipts survive reconnects so retrying those requests returns the stored outcome
without a second spend or reroll. Initial weights await balance playtesting.

MonsterFusion.spec verifies all six tiers, legacy migration, ownership/count/
species validation, increasing fusion odds, duplicate species, grant idempotency
and receipts. SaveRetention.spec covers durable combination and fusion,
concurrent gain/save merging and receipt retries after a simulated rejoin.

MonsterCollection.spec also exercises the actual UI callbacks with isolated
controls: exact 3–5 input selection, mixed-species exclusion, request operation
ids, pending-save locking and committed-result refresh.

## Shard artwork and pickups

`Shared.Utilities.ShardModel` creates the collectible as an eight-face crystal
(16 native wedge faces plus one invisible prompt root), with a soft point light
and an occluded outline. Translucent facets enclose a static miniature of the
matching monster when its authored model is available; the miniature has no
Humanoid/animation controller or gameplay physics. Facets move together during the existing sky-fall tween.
All parts are anchored, non-colliding, non-touchable and non-queryable. Pickup
ownership, landing, distance, attempt and save-lock checks remain server-owned.
The model, tween driver and movement connection are disposed on collection,
expiry or attempt cleanup; collection is enabled only after landing.

`ShardAppearance` supplies one palette to both the model and
`Client.Utilities.ShardIcon`: all species have explicit thematic colors
(green Zombie/Goblin, burgundy Vampire, bone Skeleton, amber desert units, etc.).
The inventory icon combines native faceted UI art with a translucent, static
monster head portrait, mounted only when a tile is first shown. No uploaded
image or mesh is required. Missing model templates retain the crystal art.
Boss icons have glow pulses and two sparkle accents; major bosses have four.
World boss shards emit sparkles, and major bosses add a golden rune halo.
`ShardController` reduces world particle rates to 40% on Low and zero on Off.
Icon glow tweens run only when visible on High. Portraits follow the existing
MonsterPreview quality policy (Off uses a swatch).
`Shared.Config.ShardVisualConfig` owns cosmetic dimensions, colors and light
settings. This artwork changes no shard quantities, reward weights or recipes.

Items uses a wrapping grid of compact 76 × 76 logical-pixel shard tiles.
Each tile shows a smaller shard icon, monster name and owned/needed count. Hover, keyboard/controller focus
or a tap opens a shared short-description tooltip with owned/needed shards.
Combine appears in that tooltip when enough shards are available; merely
inspecting the tile never spends anything. Tooltips close on scrolling, resize
or hiding the inventory.
`tests/ShardVisuals.spec.luau` checks real facet geometry, model movement,
world/icon color agreement, landing-gated prompts and idempotent cleanup.
ShardTiles.spec checks names/icons, focus tooltips, live quantities, combine
eligibility, visible quantity captions, responsive grid wrapping and empty inventory.
ShardQuality.spec covers boss/major particle rates and watcher cleanup. Studio edit previews
checked the tile grid and tooltip. Full touch/gameplay QA remains open.
