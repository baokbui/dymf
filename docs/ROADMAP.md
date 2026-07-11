# Brainrots vs. Monsters (BVM) Roadmap

## Purpose

This roadmap defines the development milestones for Brainrots vs. Monsters. Every milestone should result in a working, playable version of the game. Do not begin a new milestone until the current one is complete and tested.

---

# Milestone 0 — Project Setup

**Status: ✅ Complete**

## Goal

Create a solid foundation for the project.

## Tasks

- Create Git repository
- Configure Rojo
- Connect Rojo to Roblox Studio
- Create `.cursorrules`
- Create documentation
- Create project folder structure
- Create empty services
- Create shared configuration modules

## Complete When

- Project syncs correctly between Cursor and Roblox Studio.
- Folder structure is complete.
- Documentation exists.

---

# Milestone 1 — Player Plot System

**Status: ✅ Complete**

## Goal

Every player receives their own isolated battlefield.

## Tasks

- Plot assignment
- Plot ownership
- Plot cleanup
- Invisible barriers
- Spawn locations
- Camera positioning

## Complete When

- Multiple players can join.
- Each player receives a unique plot.
- No player can interfere with another player's plot.

---

# Milestone 2 — Grid System

**Status: ✅ Complete**

## Goal

Create the battlefield grid.

## Tasks

- Grid generation
- Grid tiles
- Tile coordinates
- Occupied tile tracking
- Grid highlighting

## Complete When

- Grid appears correctly.
- Tiles know whether they are occupied.

---

# Milestone 3 — Coin System

**Status: ✅ Complete**

## Goal

Implement the game's economy.

## Tasks

- CoinService
- Coin UI
- Passive coin drops
- Coin collection
- Server-side validation

## Complete When

- Players receive coins.
- Coin count updates correctly.
- Coins cannot be exploited.

---

# Milestone 4 — Placement System

**Status: ✅ Complete**

## Goal

Allow players to place Brainrots.

## Tasks

- Shop UI
- Brainrot selection
- Placement preview
- Tile validation
- Placement RemoteEvents
- Cost validation

## Complete When

- Players can purchase and place Brainrots.
- Coins are deducted correctly.
- Invalid placements are rejected.

---

# Milestone 5 — Brainrot Framework

**Status: ✅ Complete**

## Goal

Create the base Brainrot system.

## Tasks

- Base Brainrot module
- Configuration system
- Health
- Attack stats
- Cooldowns
- Animations
- Sounds

## Initial Brainrots

- Ballerina Cappucina (coin producer)
- Tung Tung Sahur (melee)
- Tralalero Tralala (bubble trap)
- Bombardino Crocodilo (line bomb)
- Lirili Larila (freeze)
- Cappuccino Assassino (full-row knife)
- Chimpanzini Bananini (wall)

## Complete When

- All seven Brainrots function correctly (coin generation + combat through
`CombatService`). ✅

---

# Milestone 6 — Monster Framework

**Status: ✅ Complete**

## Goal

Create enemies.

## Tasks

- Base Monster
- Pathfinding
- Health
- Damage
- Death
- Animations

## Roster

- Zombie, Vampire, Werewolf, Skeleton, Goblin
- Bosses: Orc, Necromancer, Goblin King, Queen Spider, Duke Vampire
- Spider (jump ability)

## Complete When

- Monsters walk across the battlefield. ✅
- Brainrots can damage monsters; monsters attack brainrots on tiles. ✅

---

# Milestone 7 — Combat System

**Status: ✅ Complete**

## Goal

Implement combat.

## Tasks

- CombatService
- Projectile system
- Damage
- Death
- Target acquisition
- Health bars

## Complete When

- Brainrots attack monsters.
- Monsters die correctly.

---

# Milestone 8 — Level System

**Status: ✅ Complete**

## Goal

Create the gameplay loop: a PvZ-style campaign of discrete, authored levels.

## Tasks

- Levels registry (authored, data-driven)
- Preparation phase
- Countdown
- Start Level button
- Spawn groups (internal waves) + progress bar
- Big final wave + warning
- Victory / Defeat detection
- Rewards
- Linear progression (unlock next level)

## Complete When

- Players can play a level, win it, and advance to the next one.
- Losing (house breached) lets the player retry the same level.

---

# Milestone 9 — Save System

**Status: ✅ Complete**

## Goal

Persist player progress.

## Save

- Current level
- Highest unlocked level
- Coins
- Player health
- Brainrots
- Brainrot positions
- Brainrot health
- Unlocks
- Upgrades
- Statistics

## Do Not Save

- Monsters
- Monster positions
- Projectiles
- Ground coins
- Temporary combat state

## Rejoin Behavior

- Restore battlefield
- Restore player progress
- Restart the saved level from the beginning

## Complete When

- Players can leave and return without losing progress.

---

# Milestone 10 — Additional Monsters

**Status: ✅ Complete**

## Add

- Introduce monsters from the roster into campaign data.
- **One** new non-boss every 5 levels (Level 5 = Goblin).
- **One** boss every 10 levels (Level 10 = Orc); repeat at 15 / 20, etc.
- Adjacent levels ramp slowly — sometimes the same difficulty as the prior level.

## Complete When

- Multiple enemy types appear during gameplay.

---

# Milestone 11 — Visual Effects

**Status: ✅ Complete**

## Add

- Projectiles
- Explosions
- Particles
- Death effects
- Coin effects

## Complete When

- Combat feels visually satisfying.

---

# Milestone 12 — Audio

**Status: ✅ Complete**

## Add

- Background music
- UI sounds
- Monster sounds
- Brainrot sounds
- Ambient sounds
- Boss music

## Complete When

- All major gameplay events have audio feedback.

---

# Milestone 13 — UI Polish

## Improve

- Shop
- Coins
- Level display (progress bar)
- Level Select
- Health
- Settings
- Reset Progress
- Statistics

## Complete When

- UI is polished and easy to use.

---

# Milestone 14 — Balancing

## Tune

- Costs
- Damage
- Health
- Coin generation
- Cooldowns
- Level difficulty
- Enemy scaling

## Complete When

- Gameplay feels fair and engaging.

---

# Milestone 15 — Additional Brainrots

## Expand the roster.

Potential additions

- Freeze
- Fire
- Cannon
- Wall
- Electric
- Poison
- Sniper
- Healer
- Bomb
- Support
- Laser
- Summoner

## Complete When

- The roster contains at least 15 Brainrots.

---

# Milestone 16 — Optimization

## Improve

- Performance
- Memory usage
- Network traffic
- Object cleanup
- Event management

## Complete When

- Stable performance with multiple players and many units.

---

# Milestone 17 — Testing

## Test

- Saving
- Rejoining
- Multiplayer
- Placement
- Combat
- Bosses
- Exploit prevention
- Edge cases

## Complete When

- No critical bugs remain.

---

# Milestone 18 — Release

## Final Tasks

- Publish game
- Create icon
- Create thumbnails
- Create trailer
- Configure game page
- Enable analytics
- Final playtesting

## Complete When

- Brainrots vs. Monsters is publicly released.

---

# Milestone 19 — Retention Systems

## Goal

Add first-time and recurring meta rewards that bring players back without
touching core combat or level authority. Server owns all claim/progress state;
UI only displays and sends intents.

## Systems

### 7-Day First-Time Rewards

- One-time login streak for new players (days 1–7)
- Authored reward table (coins and/or unlocks)
- Persist claimed days + streak day via `SaveService`
- Missed-day rules (reset streak vs. pause — decide at implementation)
- Claim UI; server validates eligibility before granting

### Spinner

- Weighted reward wheel (coins, unlocks, cosmetics placeholders as available)
- Free spin cadence (e.g. daily) + optional paid/extra spins later
- Server rolls outcome; client only animates the result
- Persist last spin time / remaining free spins

### Daily Quests

- Small rotating quest pool (e.g. place N Brainrots, clear a level, collect coins)
- Daily reset (timezone / UTC — decide at implementation)
- Progress tracked server-side; claim rewards when complete
- Persist quest ids, progress, and claim state via `SaveService`

## Architecture Notes

- New service(s) own eligibility, rolls, and quest progress (e.g. `RewardService`,
  `QuestService`) — never trust client claim/spin results
- Grants go through existing economy / unlock APIs (`CoinService`, etc.)
- Remotes for claim / spin / quest claim with full server validation
- UI panels under `UIController` (display-only)

## Complete When

- New players can claim a 7-day first-time reward track.
- Players can use the spinner on its free cadence and receive the rolled reward.
- Daily quests appear, track progress, reset on schedule, and grant rewards on claim.
- All progress survives leave/rejoin; exploits (double-claim, fake progress) fail server checks.

---

# Milestone 20 — Post-Launch

## Continue Development

- New Brainrots
- Brainrot skins
- New Monsters
- New Maps
- Seasonal Events
- Achievements
- Cosmetics
- Quality of Life updates
- Balance patches

Development continues indefinitely after release.