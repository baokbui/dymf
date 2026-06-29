# Brainrots vs. Zombies (BVZ) Roadmap

## Purpose

This roadmap defines the development milestones for Brainrots vs. Zombies. Every milestone should result in a working, playable version of the game. Do not begin a new milestone until the current one is complete and tested.

---

# Milestone 0 — Project Setup

## Goal

Create a solid foundation for the project.

## Tasks

* Create Git repository
* Configure Rojo
* Connect Rojo to Roblox Studio
* Create `.cursorrules`
* Create documentation
* Create project folder structure
* Create empty services
* Create shared configuration modules

## Complete When

* Project syncs correctly between Cursor and Roblox Studio.
* Folder structure is complete.
* Documentation exists.

---

# Milestone 1 — Player Plot System

## Goal

Every player receives their own isolated battlefield.

## Tasks

* Plot assignment
* Plot ownership
* Plot cleanup
* Invisible barriers
* Spawn locations
* Camera positioning

## Complete When

* Multiple players can join.
* Each player receives a unique plot.
* No player can interfere with another player's plot.

---

# Milestone 2 — Grid System

## Goal

Create the battlefield grid.

## Tasks

* Grid generation
* Grid tiles
* Tile coordinates
* Occupied tile tracking
* Grid highlighting

## Complete When

* Grid appears correctly.
* Tiles know whether they are occupied.

---

# Milestone 3 — Coin System

## Goal

Implement the game's economy.

## Tasks

* CoinService
* Coin UI
* Passive coin drops
* Coin collection
* Server-side validation

## Complete When

* Players receive coins.
* Coin count updates correctly.
* Coins cannot be exploited.

---

# Milestone 4 — Placement System

## Goal

Allow players to place Brainrots.

## Tasks

* Shop UI
* Brainrot selection
* Placement preview
* Tile validation
* Placement RemoteEvents
* Cost validation

## Complete When

* Players can purchase and place Brainrots.
* Coins are deducted correctly.
* Invalid placements are rejected.

---

# Milestone 5 — Brainrot Framework

## Goal

Create the base Brainrot system.

## Tasks

* Base Brainrot module
* Configuration system
* Health
* Attack stats
* Cooldowns
* Animations
* Sounds

## Initial Brainrots

* Shooter
* Money Generator

## Complete When

* Both Brainrots function correctly.

---

# Milestone 6 — Zombie Framework

## Goal

Create enemies.

## Tasks

* Base Zombie
* Pathfinding
* Health
* Damage
* Death
* Animations

## Initial Zombie

* Basic Zombie

## Complete When

* Zombies walk across the battlefield.

---

# Milestone 7 — Combat System

## Goal

Implement combat.

## Tasks

* CombatService
* Projectile system
* Damage
* Death
* Target acquisition
* Health bars

## Complete When

* Brainrots attack zombies.
* Zombies die correctly.

---

# Milestone 8 — Wave System

## Goal

Create the gameplay loop.

## Tasks

* Preparation phase
* Countdown
* Start Wave button
* Wave spawning
* Rewards
* Difficulty scaling

## Complete When

* Players can repeatedly complete waves.

---

# Milestone 9 — Save System

## Goal

Persist player progress.

## Save

* Current wave
* Coins
* Player health
* Brainrots
* Brainrot positions
* Brainrot health
* Unlocks
* Upgrades
* Statistics

## Do Not Save

* Zombies
* Zombie positions
* Projectiles
* Ground coins
* Temporary combat state

## Rejoin Behavior

* Restore battlefield
* Restore player progress
* Restart the saved wave from the beginning

## Complete When

* Players can leave and return without losing progress.

---

# Milestone 10 — Additional Zombies

## Add

* Fast Zombie
* Tank Zombie
* Shield Zombie
* Flying Zombie
* Carrier Zombie
* Boss Zombie

## Complete When

* Multiple enemy types appear during gameplay.

---

# Milestone 11 — Additional Brainrots

## Expand the roster.

Potential additions

* Freeze
* Fire
* Cannon
* Wall
* Electric
* Poison
* Sniper
* Healer
* Bomb
* Support
* Laser
* Summoner

## Complete When

* The roster contains at least 15 Brainrots.

---

# Milestone 12 — Visual Effects

## Add

* Projectiles
* Explosions
* Particles
* Death effects
* Coin effects

## Complete When

* Combat feels visually satisfying.

---

# Milestone 13 — Audio

## Add

* Background music
* UI sounds
* Zombie sounds
* Brainrot sounds
* Ambient sounds
* Boss music

## Complete When

* All major gameplay events have audio feedback.

---

# Milestone 14 — UI Polish

## Improve

* Shop
* Coins
* Wave display
* Health
* Settings
* Reset Progress
* Statistics

## Complete When

* UI is polished and easy to use.

---

# Milestone 15 — Balancing

## Tune

* Costs
* Damage
* Health
* Coin generation
* Cooldowns
* Wave difficulty
* Enemy scaling

## Complete When

* Gameplay feels fair and engaging.

---

# Milestone 16 — Optimization

## Improve

* Performance
* Memory usage
* Network traffic
* Object cleanup
* Event management

## Complete When

* Stable performance with multiple players and many units.

---

# Milestone 17 — Testing

## Test

* Saving
* Rejoining
* Multiplayer
* Placement
* Combat
* Bosses
* Exploit prevention
* Edge cases

## Complete When

* No critical bugs remain.

---

# Milestone 18 — Release

## Final Tasks

* Publish game
* Create icon
* Create thumbnails
* Create trailer
* Configure game page
* Enable analytics
* Final playtesting

## Complete When

* Brainrots vs. Zombies is publicly released.

---

# Milestone 19 — Post-Launch

## Continue Development

* New Brainrots
* New Zombies
* New Maps
* Seasonal Events
* Daily Rewards
* Achievements
* Cosmetics
* Quality of Life updates
* Balance patches

Development continues indefinitely after release.
