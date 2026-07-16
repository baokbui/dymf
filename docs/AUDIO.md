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
| `AudioController` (client) | SoundGroups, BGM / boss crossfade, ambient, mute API |
| `AudioController/SfxPlayer` | One-shot SFX templates, preload, play/stop |
| Other controllers | Call `AudioController.play(key)` — never create Sounds |

SoundGroups under `SoundService.BVM`: `Music`, `Sfx`, `Ambient` (+ `Preload` folder
for template Sounds).

**Server authority:** combat outcomes, placement, and economy stay on the server.
Audio is display-only feedback.

---

## Catalog (`AudioConfig`)

### Music / ambient

| Key / track | Trigger |
| ----------- | ------- |
| `Default` music | Join / non-boss gameplay |
| `Boss` music | Big-wave warning or boss monster on local plot |
| `Plot` ambient | Soft loop while playing |

### SFX

| Key | Trigger |
| --- | ------- |
| `UiClick` / `UiSelect` | Shovel enable, cancel, shop select |
| `LevelStart` | Start / Restart Level button |
| `CountdownTick` | Countdown second ticks |
| `BigWave` | First frame of big-wave warning |
| `Victory` / `Defeat` | Level phase change |
| `CoinCollect` | Successful ground-coin pickup (not on spawn) |
| `PlaceBrainrot` / `RemoveBrainrot` | Place / shovel remove intent |
| `Hit` | Generic `CombatVisual` Hit (when no `soundKey`) |
| `ThrowKnifeHit` | Cappuccino knife impact (`CombatVisual.soundKey`) |
| `Death` | Generic monster death |
| `Death_<MonsterId>` | Per-monster death (e.g. `Death_Zombie`) |
| `MonsterAttack` | Local Brainrot `Health` decreases (chew feedback) |
| `MeleeBat` | Tung Tung hit via `BrainrotAction` (every connecting hit) |
| `FreezeTime` | Lirili Larila freeze when ≥1 enemy is hit |
| `BubbleTrap` | Tralalero bubble impact via `CombatVisual.soundKey` |
| `LineBomb` | Bombardino place / bombing run (`BrainrotAction`) |
| Other ability keys | `BrainrotAction.action` when the ability calls `playSound` |

Optional per-SFX fields in `AudioConfig.SoundDef`:

| Field | Meaning |
| ----- | ------- |
| `MaxDuration` | Hard-stop playback after N seconds (long asset tails) |
| `StartOffset` | Skip leading silence (`TimePosition` on Play) |

`AudioConfig.PRELOAD_SFX` lists keys preloaded on join via `ContentProvider` so
first combat hits are not delayed by asset download.

Replace `SoundId` strings with final catalog assets when ready. Empty / missing
ids stay silent.

---

## Combat audio wiring

| Event | Path |
| ----- | ---- |
| Melee bat hit (incl. kill) | `MeleeBat` ability → `BrainrotAction` → `AudioController.play("MeleeBat")` + client pulse |
| Knife impact | `CombatVisual` Hit with `soundKey = "ThrowKnifeHit"` |
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
- Tuning lives in `AudioConfig` — never hardcode asset ids in controllers.
- Mute API: `AudioController.setMuted` / volume scales / Brainrot SFX toggle (Settings UI, M13).
