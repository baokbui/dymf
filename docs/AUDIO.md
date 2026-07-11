# BVM Audio

Client-owned audio feedback for major gameplay events. The server never plays
sounds for the local player — it may push intents (`BrainrotAction`,
`CombatVisual`, `LevelStateChanged`); `AudioController` decides what to play.

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Ownership ✅ (Milestone 12)

| Module | Role |
| ------ | ---- |
| `Shared.Config.AudioConfig` | Sound ids, volumes, music/ambient defs |
| `AudioController` (client) | SoundGroups, one-shots, BGM / boss crossfade, ambient |
| Other controllers | Call `AudioController.play(key)` on events — never create Sounds |

SoundGroups under `SoundService.BVM`: `Music`, `Sfx`, `Ambient`.

---

## Catalog (`AudioConfig.SFX` / `MUSIC` / `AMBIENT`)

| Key / track | Trigger |
| ----------- | ------- |
| `Default` music | Join / non-boss gameplay |
| `Boss` music | Big-wave warning or boss monster on local plot |
| `Plot` ambient | Soft loop while playing |
| `UiClick` / `UiSelect` | Shovel, cancel, shop select |
| `LevelStart` | Start / Restart Level button |
| `CountdownTick` | Countdown second ticks |
| `BigWave` | First frame of big-wave warning |
| `Victory` / `Defeat` | Level phase change |
| `CoinCollect` | Successful ground-coin pickup |
| `PlaceBrainrot` / `RemoveBrainrot` | Place / shovel remove intent |
| `Hit` / `Death` / `Explosion` | `CombatVisual` kinds |
| `ThrowKnifeHit` | Cappuccino knife projectile impact (`CombatVisual.soundKey`) |
| `Death_<MonsterId>` | Per-monster death override (e.g. `Death_Zombie`) |
| `MonsterSpawn` | Monster tagged on local plot |
| `MonsterAttack` | Local Brainrot `Health` decreases |
| Ability keys (`MeleeBat`, …) | `BrainrotAction` from server |

Replace `SoundId` strings in `AudioConfig` with final catalog assets when ready.
Empty / missing ids stay silent.

---

## Rules

- Playback is client-only; never trust the client for rewards or combat.
- Prefer `AudioController.play` over ad-hoc `Instance.new("Sound")`.
- Mute API: `AudioController.setMuted` (Settings UI can wire this in M13).
