# Brainrots vs. Monsters (BVM)

A 3D Roblox tower defense game inspired by Plants vs. Zombies. Each player
defends their own lawn by planting **Brainrots** on a grid while **monsters**
march in from a dark forest to the east.

## The game

You get an isolated plot: a **5×9** lawn, a monster farm behind it, and a matching
enemy lane in the trees. Press **Start Day**, wait out a short 3…0 countdown,
then plant while the first monsters are still walking in from the forest.

Survive the day’s spawn groups and the big final wave. A monster that reaches
the house costs a heart; lose all five and it’s Game Over — rewind and try the
same day again with your last victory lawn.

**Coins** pay for plants during a match (Day 1 starts with 125; later days you
earn them on the lawn). **Brains** are the meta currency: win a day, then spend
them at the Brainrot stall beside your house or the HUD Upgrades shop — unlock units like Girafa Celestre,
or buy Speed so you can scoop coins faster.

Progress carries across sessions: day, hearts, brains, unlocks, loadout, and
the lawn from your last victory. You can walk over to other players’ plots to
spectate; you cannot plant or collect on theirs.

The campaign runs through fifty authored days, ramping from zombies and goblins
into vampires, spiders, werewolves, and desert mummies, with weather (night fog,
desert) on later stretches. A manually started **Hidden Day** after Day 40
rewards goblin kills with brains, even on a loss.

Brainrots share XP by species and claim Epic→GOD evolutions with brains
at levels 10/20/30/40/50. Nine units currently have authored evolution tracks.
Daily quests reward collecting coins, defeating monsters, and clearing a day,
with a bonus for completing all three. They reset at UTC midnight.
Weekly quests share the Quests menu with daily quests and reset Mondays at
00:00 UTC. A separate First-time Rewards button offers seven one-time claims: brains, Speed/Magnet
levels, and a free Brainrot-store ticket on Day 7. Claim once per real-world UTC
date; missed dates preserve progress. Its button disappears after all seven
rewards are collected. There is no repeating weekly login reward.
Quests also offers one-time Campaign milestones every five days through Day 50.
Achievements cover bosses, perfect defenses, evolutions, collection, kills, and
placements. Forest Rush unlocks at Day 10, and the Daily Spinner unlocks at
after clearing Day 2. Both offer a daily UTC reward. Milestone 20 features are implemented and
release verification is still in progress.

Campaign clears also earn 1–3 stars and regional monster shards. Combine shards
into individual farm monsters, then fuse 3–5 of one species to roll a new size.
Tiny through Titanic residents roam and earn online brains; farm capacity
upgrades increase active slots from five to ten. Offline income remains planned.

## Tech stack

| Piece | Role |
| ----- | ---- |
| [Roblox Studio](https://create.roblox.com) | Place, playtests, Toolbox assets |
| [Luau](https://luau.org) (`--!strict`) | All game code |
| [Rojo](https://github.com/rojo-rbx/rojo) 7.7.0 | Filesystem ↔ Studio sync (`aftman.toml`) |
| Codex | Agent workflow, local project edits, and connected Studio inspection |

Gameplay values live in `Shared.Config` and data registries (`Brainrots`,
`Monsters`, `Levels`) — not hardcoded in services. The **server** owns combat,
economy, days, placement, and saves. The **client** owns UI, camera, input,
VFX, and sound.

## Layout

```
src/shared    → ReplicatedStorage.Shared   (config, remotes, registries)
src/server    → ServerScriptService.Server  (Services)
src/client    → StarterPlayerScripts.Client (Controllers)
docs/         → design, architecture, roadmap
```

Rojo maps this in `default.project.json`. Authored models sit under
`ReplicatedStorage.Assets` (Brainrots, Monsters, Houses, Stores) and survive
Studio sync via `$ignoreUnknownInstances`.

## Docs

| Doc | Contents |
| --- | -------- |
| [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) | What the game is |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Codebase structure and conventions |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Milestones (M0–19 delivered; M20/M21 release QA pending; M22–25 planned) |
| [`docs/LEVELS.md`](docs/LEVELS.md) | Campaign days, victory / defeat / rewind |
| [`docs/BRAINROTS.md`](docs/BRAINROTS.md) / [`docs/MONSTERS.md`](docs/MONSTERS.md) | Unit registries |
| [`docs/STORE.md`](docs/STORE.md) | Per-plot shops and brains spends |
| [`docs/EVOLUTIONS.md`](docs/EVOLUTIONS.md) | Brainrot leveling + Epic→God tiers (M19) |
| [`AGENTS.md`](AGENTS.md) | Canonical project engineering rules |
| [`docs/IMPLEMENTATION_NOTES.md`](docs/IMPLEMENTATION_NOTES.md) | Current caveats and audit scope |
| [`docs/RETENTION.md`](docs/RETENTION.md) | M20 daily quests, budgets, and durable claim rules |
| [`docs/HOUSE.md`](docs/HOUSE.md) / [`docs/FARM_PROGRESSION.md`](docs/FARM_PROGRESSION.md) | Farm residents/income, stars, shards, size tiers, and fusion |
