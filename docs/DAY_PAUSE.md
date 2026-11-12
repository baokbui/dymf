# Day pause ✅

LevelService owns each player's `Active → Paused → Resuming → Active` lifecycle.
Pause Day replaces Start Day during combat. Resume Day starts a centered,
three-second countdown (`LevelConfig.PAUSE_RESUME_SECONDS`); combat remains frozen
until it finishes. Repeated resume requests cannot restart the countdown.

The pause is scoped to the player's plot. Monsters, Brainrots, attack windups,
status effects, spawn scheduling, ground-coin motion/lifetimes and sky-shard
motion/lifetimes stop. PauseScene holds unit animation speeds and anchors the
player's character. Resume restores those speeds, including held attack poses.
Other players' battles and farm income continue.

Projectiles already in flight disappear without an impact. CombatService removes
its registered projectiles; LineBomb separately removes dropped Bombardino bombs
and checks cancellation before applying damage. The flying Brainrot itself stays
frozen and can finish its run after resume. Owner-local InkDrop visuals are cleared.

Server handlers reject modifying gameplay requests while Paused or Resuming,
including planting/removing units, loadout changes, purchases, claims, combining,
fusion, magnet use, reset and day transitions. Sky-shard pickup is also blocked.
Read-only UI and camera access can continue. Pause is refused while an existing
durable progression operation holds its lock.

`Shared.Utilities.BattleClock` supplies per-owner simulation timestamps, delayed
callbacks and tracked tweens. Combat code must use this clock for deadlines.
Resume shifts legacy real-time plant and magnet deadlines by the full pause
duration. Day elapsed time and timed star goals exclude pause and resume countdown.
UTC rewards, save leases, autosave and request throttles keep their real clocks.

Pause state is session-only. Leaving discards the unfinished attempt. Rejoining
restores Preparation on the same saved day, the committed lawn and XP checkpoint,
and pre-attempt hearts for a paused campaign attempt. Coins follow the existing
day-purse rule. Daily Challenge restores its separate campaign snapshot.

## Verification

Isolated Studio fixtures cover owner-clock isolation, held animation speeds,
timer cancellation, pause/resume countdown, paused leave/rejoin, mutation rejection,
client controls and local idle freezing. Projectile removal was checked with two
isolated plots: clearing one leaves the other intact and causes no later impact.
These checks do not replace a populated multiplayer/device playtest.
