# Monster Sanctuary (Milestone 21)

Status: 🛠 Core online collection and income implemented. Offline income,
cosmetic skins and additional habitat upgrades remain planned.
Player-selected residents are implemented through Inventory → Pets.
Farm capacity upgrades and size tiers/fusion are implemented.

## Habitat

`HouseBuilder` retains its existing API and `PlotN.House` location, building an
open sanctuary through `SanctuaryBuilder`. It occupies the original house slot,
using asset **1911880871**, stored as Assets.Houses.Farm1911880871, scaled
to the house footprint with its entrance facing the lawn. The farm retains its
large owner-name sign outside the fence. Monsters roam inside the fitted enclosure bounds
and stand on the imported grass surface. If the template is unavailable, the
procedural farm provides a fallback. Authored templates are stored in Studio
and must be saved with the place. The physical Brainrot shop
continues to attach beside it using the same house bounds. The Cottage asset
and old procedural cottage modules are retained but are no longer selected.
All habitat scenery and residents are anchored, non-colliding and non-queryable.

## Collection and income

Milestone 21B adds species-specific monster shards and 1–3 star campaign
rewards. Players combine shards in Inventory → Items to form a farm monster.
Existing owned species persist. Players place or remove individual pets through
Inventory → Pets, up to purchased capacity from five slots to ten. Removed pets
stay owned and earn no income. Farm Capacity costs
30, 55, 85, 125 and 175 brains for successive additional slots.

HouseService supplies roaming cosmetic residents and accrues the sum of their
species rate × size-tier income multiplier. Each nameplate shows Size,
Monster name, Level, then Brains/second, while the outside sign shows only the owner’s farm name. Stronger
species earn faster. Whole brains persist normally. Partial income is
session-only and accrual pauses during save/progression locks.

See docs/FARM_PROGRESSION.md for exact star goals, shard pools, combining rules,
income rates and sky drops. Current schema v16 persists individual monsters,
operation receipts, shard balances and best day stars. Reset Progress clears this farm progression.

## Validation

The isolated HouseService fixture covers resident reuse, species income,
income timing, save locks, the resident cap, reset and cleanup. Studio edit-mode
checks verified authored residents move and their movement resources clean up.
Live save/rejoin, four-player performance and income balance playtesting remain
open.

Individual residents now use Tiny, Small, Medium, Big, Gigantic and Titanic
tiers. Size determines level, visual scale and income multiplier. The separate Fusion page
allows exact selection of 3–5 same-species instances for fusion. See
FARM_PROGRESSION.md for weights, migration and transaction guarantees.

Players can hide other farms’ residents through Settings → Graphics.
FarmController applies local visibility changes to the Residents folder models
and restores their original appearance on toggle or ownership changes.
This reduces local rendering work; it does not stop server roaming, income,
or replication and does not change farm ownership.

## Resident selection ✅

HouseService validates `SetFarmPet(uid, equipped)` against the hydrated owned
inventory and purchased capacity. Save/progression locks and paused/resuming
days reject changes. `FarmResidents` shares selection rules with the UI; only
selected residents roam and contribute income. Selection refreshes residents
immediately without awarding an extra income tick. Requests are rate-limited.

Optional `onFarm` flags are preserved in v16 farm monster records through ordinary
SaveService equipment saves and rejoin. A missing flag preserves the previous
newest-resident default until the first equipment edit materializes all flags.
Newly combined/fused pets start off-farm. Fusion removes consumed residents;
players can place the new output from Pets. Capacity upgrades add slots without
automatically placing stored pets after explicit selection.

FarmResidents.spec and FarmPetsService.spec cover migration, capacity, ownership,
selection/removal, fusion, pause/save locks and no extra income on toggles.
SaveRetention.spec verifies flags through the actual in-memory save/rejoin path.
