# BVM Audio

Client-owned audio feedback for major gameplay events. The server never plays
sounds for the local player — it may push intents (`BrainrotAction`,
`CombatVisual`, `LevelStateChanged`); `AudioController` decides what to play.

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Ownership ✅ (Milestone 12)

| Module | Role |
| ------ | ---- |
| `Shared.Config.AudioConfig` | Sound ids, volumes, music/ambient defs, preload list |
| `AudioController` (client) | SoundGroups, weather / boss BGM crossfade, mute API |
| `AudioController/SfxPlayer` | One-shot SFX templates, preload, play/stop |
| Other controllers | Call `AudioController.play(key)` — never create Sounds |

SoundGroups under `SoundService.BVM`: `Music`, `Sfx`, `Ambient` (+ `Preload` folder
for template Sounds).

**Server authority:** combat outcomes, placement, and economy stay on the server.
Audio is display-only feedback.

### Plot-local SFX (spectate-safe) ✅

Gameplay SFX on a plot are heard **only by that plot’s owner**:

| Layer | Rule |
| ----- | ---- |
| Server remotes | `CombatVisual` / `BrainrotAction` / level audio use `FireClient(owner)` — never `FireAllClients` |
| Client playback | `AudioController` / `SfxPlayer` parent Sounds under local `SoundService` (2D, non-replicating) |
| Placement | Plant / shovel SFX run only on the acting client’s `PlacementController` |
| Chew feedback | `CombatVisual` kind `MonsterAttack` (plot owner only); goblins use club overrides |
| Asset hygiene | `ModelUtil` strips embedded `Sound` / audio instances from cloned Brainrot & Monster templates so Toolbox audio cannot leak to spectators |
| Safety net | Client destroys any `Sound` under a plot model (Toolbox music on spawn, etc.) |

UI clicks and weather/boss BGM are local to each client (not plot-scoped).

---

## Catalog (`AudioConfig`)

### Music / ambient

| Key / track | Trigger |
| ----------- | ------- |
| `Default` music | Days 1–20 (no weather) — Relaxed Scene, chill daytime |
| `Night` music | Days 21–40 (`Night` / `NightFog` / `NightFogReceded`) — chill, slightly spooky |
| `Desert` music | Days 41–50 (`Desert`) — chill sand / oasis |
| `Boss` music | Big-wave warning (`LevelStateChanged.bigWaveWarning`) — overrides theme; restores weather track after victory / defeat / prep |
| `Plot` ambient | Disabled (empty id) — no extra loop besides weather / boss |

Theme BGM follows **weather**, not day numbers (`WeatherUtil` + `LevelStateChanged`). Tune ids in `AudioConfig.MUSIC`. Boss music does **not** start when a monster model spawns.

### SFX

| Key | Trigger |
| --- | ------- |
| `UiClick` / `UiSelect` | Shovel enable, cancel, shop select |
| `LevelStart` | Start / Restart Level button |
| `CountdownTick` | Start Day overlay ticks (3…0) |
| `BigWave` | First frame of big-wave warning |
| `Victory` / `Defeat` | Level phase change |
| `CoinCollect` | Successful ground-coin pickup (not on spawn) |
| `PurchaseKaching` | Store purchase succeeded (cash register) |
| `PurchaseError` | Store purchase failed (not enough brains) — `132281440773764` |
| `PlaceBrainrot` / `RemoveBrainrot` | Place / shovel remove intent |
| `PlaceBrainrot_<BrainrotId>` | Per-unit plant SFX for every roster Brainrot |
| `PlaceBrainrot_BrrBrrPatapim` | Patapim plant / spawn |
| `PlaceBrainrot_GiraffaCeleste` | Giraffa plant / spawn |
| `WindGust` | Giraffa gust after her place animation (`BrainrotAction`) |
| `GraveShake` | Grave takes a Patapim smash (`BrainrotAction`) |
| `GraveCollapse` | Grave destroyed by the last Patapim smash |
| `Hit` | Generic `CombatVisual` Hit (when no `soundKey`) |
| `ThrowKnifeHit` | Cappuccino knife impact (`CombatVisual.soundKey`) |
| `PlaceBrainrot_OrangutiniAnanassini` | Orangutini plant / spawn — `92163425392945` |
| `PlaceBrainrot_BlueberrinniOctopusini` | Blueberrinni plant / spawn — `91691159755945` |
| `PineappleHit` | Orangutini pineapple impact (`CombatVisual.soundKey`) |
| `PlaceBrainrot_LaVaccaSaturnoSaturnita` | La Vacca plant / spawn — `90484863638361` |
| `SwordWave` | Shadow Requiem crescent whoosh, **1s** before the wave launches (stops early if the last-tile pillar starts first) |
| `SwordWavePillar` | Shadow Requiem last-tile light-pillar detonation |
| `InkLand` | Blueberrinni ink splat when the droplet reaches the tile |
| `TileTrap` | Boneca headbutt landing (every hit, including kills) |
| `LightningStrike` | Boneca God of Thunder bolt (Legendary) |
| `LastLaughExplosion` | Boneca GOD Last Laugh mushroom cloud |
| `Death` | Generic monster death |
| `Death_<MonsterId>` | Per-monster death (e.g. `Death_Zombie`, `Death_SmallMummy`, `Death_PharaohMummy`) |
| `MonsterAttack` | Generic monster chew (`CombatVisual` kind `MonsterAttack`) |
| `MonsterAttack_Goblin` / `_GoblinElite` / `_GoblinKing` | Goblin club swing |
| `MonsterAttack_Scorpion` | Scorpion chew landing on a Brainrot |
| `MonsterAttack_SmallMummy` / `_PharaohMummy` | Mummy chew landing on a Brainrot |
| `MonsterAttack_Vampire` / `_DukeVampire` | Vampire and Duke Vampire life-drain tick |
| `SandTornado` | Pharaoh steal tornado (`CombatVisual` kind `SandTornado`) |
| `Terrify` | Duke Vampire Terrify scream (`CombatVisual` kind `Terrify`) |
| `MeleeBat` | Tung Tung bat hit via `BrainrotAction` (every connecting hit) |
| `SahurWrath` | Tung Tung GOD: bat stretch/grow at the start of Sahur's Wrath |
| `FreezeTime` | Lirili Larila cast on place (with attack anim) |
| `FreezeTimeEnd` | Lirili Larila thaw when freeze duration ends |
| `BubbleTrap` | Tralalero bubble impact via `CombatVisual.soundKey` |
| `LineBomb` | Bombardino place / bombing run (`BrainrotAction`) |
| Other ability keys | `BrainrotAction.action` when the ability calls `playSound` |

Optional per-SFX fields in `AudioConfig.SoundDef`:

| Field | Meaning |
| ----- | ------- |
| `MaxDuration` | Hard-stop playback after N seconds (long asset tails) |
| `StartOffset` | Skip leading silence (`TimePosition` on Play) |
| `KeepUntilStopped` | Skip the oldest-instance cap until `AudioController.stopSfx` |

`AudioConfig.PRELOAD_SFX` lists keys preloaded on join via `ContentProvider` so
first combat hits are not delayed by asset download.

Replace `SoundId` strings with final catalog assets when ready. Empty / missing
ids stay silent.

---

## Combat audio wiring

| Event | Path |
| ----- | ---- |
| Melee bat hit (incl. kill) | `MeleeBat` ability → (optional `attackHitDelay`) → `BrainrotAction` → `AudioController.play("MeleeBat")`; client ScaleTo pulse skipped when `animated` |
| Sahur’s Wrath stretch | `SahurWrath` extra → `BrainrotAction` `SahurWrath` as the bat grows |
| Sahur’s Wrath land | `BrainrotAction` `MeleeBat` + `CombatVisual` `BatSlam` → `AudioController.play("Explosion")` (ground boom, once) |
| Jackpot | `Jackpot` extra → `CombatVisual` `Jackpot` gold burst (no kaching SFX) |
| Knife impact | `CombatVisual` Hit with `soundKey = "ThrowKnifeHit"` |
| Shadow Requiem crescent | `ShadowRequiem` → `BrainrotAction` `SwordWave` **1s** before launch |
| Shadow Requiem pillar | Watcher stops `SwordWave`, then `AudioController.play("SwordWavePillar")` |
| Ink lands | `InkPuddle` → `CombatVisual` `InkDrop` → `InkLand` after `INK_FLIGHT_SECONDS` |
| Boneca headbutt | `TileTrap` → `BrainrotAction` `TileTrap` at `attackHitDelay` (0.8s) |
| Boneca lightning | `TileTrap` → `CombatVisual` `LightningStrike` → `LightningStrike` |
| Boneca Last Laugh | `TileTrapFinale` → `CombatVisual` `MushroomExplosion` → `LastLaughExplosion` |
| Bubble projectile impact | `CombatVisual` Hit with `soundKey = "BubbleTrap"` (after travel) |
| Generic hit particles | `CombatVisual` Hit (`muteSound` skips SFX when bat already played) |
| Monster death | `CombatVisual` Death with `monsterId` → `Death_<id>` or `Death` |
| Hit flash (red) | **Server** `MonsterFeedback.flashHit` (client Color is overwritten by replication) |

**Important:** `CombatController` must never block the `CombatVisual` handler on
`WaitForChild` (e.g. Projectiles). Plots always include a `Projectiles` folder;
the client watcher is non-blocking so death/hit SFX stay in sync.

---

## Rules

- Playback is client-only; never trust the client for rewards or combat.
- Prefer `AudioController.play` over ad-hoc `Instance.new("Sound")`.
- Plot gameplay SFX are **owner-only** (see Plot-local SFX above) so spectating
  other plots does not flood the server with shared noise.
- Tuning lives in `AudioConfig` — never hardcode asset ids in controllers.
- Mute API: `AudioController.setMuted` / volume scales / Brainrot SFX toggle (Settings UI, M13).
