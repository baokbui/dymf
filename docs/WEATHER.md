# Weather System

Per-day weather is **data-driven** on `LevelDefinition.weather`. Services and
controllers never branch on day numbers for fog/night/desert — they read the
current day's definition (or the `weather` field on `LevelStateChanged`).

Status: ✅ `Night` (Days 21–24) · ✅ `NightFog` (Days 25–34) · ✅ `NightFogReceded`
(Days 35–40) · ✅ `Desert` (Days 41–50). Hidden Day (pending and active)
uses `Night`, with no fog banks, blocked columns, or graves.

---

## Weather ids

| Id | Config constant | Campaign | Effects |
| -- | --------------- | -------- | ------- |
| `Night` | `WeatherConfig.NIGHT` | Days **21–24** and Hidden Day | Moonlit night Lighting only |
| `NightFog` | `WeatherConfig.NIGHT_FOG` | Days **25–34** | Night + fog bank; **3** east lawn columns unplantable |
| `NightFogReceded` | `WeatherConfig.NIGHT_FOG_RECEDED` | Days **35–40** | Same night fog look; only **2** east columns unplantable |
| `Desert` | `WeatherConfig.DESERT` | Days **41–50** | Hot lighting; **sand lawn**; fog off; east forest hidden locally and replaced with **pyramids**. Full lawn plantable |

---

## Fog extras (`NightFog` / `NightFogReceded`)

| Effect | Owner | Behavior |
| ------ | ----- | -------- |
| Visible fog banks | Client `WeatherController` | Lighting Fog + Atmosphere carry the look. Three particle volumes (one lawn bank + near/deep forest) add local mist; monsters stay fully visible. Lawn bank width follows `WeatherConfig.fogStartColumn(weather)`. Giraffa hides all three banks for the timed clear. |
| Unplantable fog columns | Server `BrainrotService` + client placement | Easternmost `fogPlotColumns(weather)` lawn columns reject **permanent** plants unless those **rows** are cleared (`FogRowsChanged`). **Girafa Celestre** (`ClearFogRow`) is a one-shot: after her gust anim, wind VFX lifts fog on **the whole plot** for 7s then fog returns. **One-shot** Brainrots (`triggersOnPlace`) and **grave-busters** (`plantOnGrave`) may still be placed on fog tiles. Other plants on fog columns are cleared on prep / lawn restore unless the row is fog-cleared |
| Fog graves | Server `GraveService` | From Day 31, random fog tiles get graves at Start Day; a Zombie or Skeleton emerges later; monsters phase through graves **and** Patapim. Graves **block Brainrot shots and status** aimed at monsters **east** of the stone (invulnerable except to Patapim). **Piercing Brew** knives fly through. **Bombardino** column bombs still hit those monsters and do not shake or damage the grave. Only **Patapim** smashes shake the stone. **Brr Brr Patapim** (`BustGrave`, `ignoreMonsterChew`) must be planted on a grave; it smashes until **6 hits** collapse it, then both fade like a monster death |
| No fog-tile hover | Client `GridController` | Fog columns do not show a hover highlight |
| Clear-lawn coin drops | Server `CoinService` | Passive rain + Ballerina spit land only on non-fog tiles |

Fog does **not** hide monsters (keeps combat readable and avoids heavy per-tile FX).

---

## Desert extras (`Desert`)

| Effect | Owner | Behavior |
| ------ | ----- | -------- |
| Sand tiles | Client `DesertVisuals` | Local Color/Material on **every** plot's grid tiles + local sand beds. Server lawn stays grass so grassy-weather players never see sand plots. |
| Hot lighting | Client `WeatherController` | Local Lighting / Atmosphere (sandy haze). Other players keep their own day's look |
| Hide forest | Client `DesertVisuals` | Entire `Workspace.Maps.DarkForest` hidden locally (`LocalTransparencyModifier` on all parts, including the forest floor). Other clients still see trees. |
| World floor | Client `DesertVisuals` | `Workspace.Baseplate` Color/Material set to sand **locally** (FilteringEnabled: other players still see grass) |
| Pyramids | Client `DesertVisuals` | Procedural ziggurats in the forest AABB, or clone `Assets.Decor.Pyramid` when present |
| Graves | — | Desert days do **not** place graves |

Desert does **not** use fog plant-blocking.

### Studio: pyramid model

1. Rojo-sync so `ReplicatedStorage.Assets.Decor` exists.
2. Insert a pyramid Model and rename it **`Pyramid`** (`WeatherConfig.DESERT_PYRAMID_MODEL_ID`).
3. Gameplay uses stacked-part fallbacks until the asset exists.

---

## Configuration

| Module | Role |
| ------ | ---- |
| `Shared.Config.WeatherConfig` | Weather ids, fog column counts, night/desert Lighting, sand colors, pyramid knobs |
| `Shared.Utilities.WeatherUtil` | `isNight`, `isNightFog`, `isDesert`, `isFogPlotColumn`, `randomClearPlotPosition`, `graveCandidatePositions` |

`WeatherConfig.fogPlotColumns(weather)` → blocked column count (`3` for
`NightFog`, `2` for `NightFogReceded`, `0` otherwise including Desert).

`WeatherConfig.fogStartColumn(weather)` → first blocked lawn column
(`COLUMNS - fogPlotColumns + 1`; with 9 columns → **7–9** or **8–9**).

`WeatherConfig.forestFogDepthFromLawnEdge()` → studs from the lawn east edge
through the player margin + full enemy-column forest (aligned with
`ForestBuilder`).

---

## Server rules

- `LevelService` includes `weather` on every `LevelStateChanged` / join payload.
- `LevelService.getWeather(player)` reads the current day's definition.
- On NightFog / NightFogReceded, `applyWeatherRules` runs
  `BrainrotService.clearFogBlockedPlacements` and refreshes the committed lawn
  checkpoint. Desert sand is **client-only**.
- `BrainrotService.place` rejects fog columns for permanent plants (toast);
  one-shot `triggersOnPlace` units (Lirili / Bombardino) are allowed in fog.
- `CoinService.dropRandomCoinForOwner` / `dropCoinForOwner` skip fog columns.

---

## Client rules

- `WeatherController` applies night Lighting for `Night`, `NightFog`, and
  `NightFogReceded`; **three** particle fog banks for both fog weathers (one
  lawn volume + near/deep forest; lawn width follows that weather's column
  count). Lighting Fog + Atmosphere do most of the look (closer fog end, denser
  haze). Particle rates stay low; the same mist is just more opaque.
- `AudioController` crossfades BGM from weather (`Default` / `Night` / `Desert`;
  see `AUDIO.md`).
- Desert: desert Lighting + `DesertVisuals` (hide forest, spawn pyramids).
- `PlacementController.setWeather` blocks ghost/place on fog columns except
  for `triggersOnPlace`, `plantsOnFog`, or `plantOnGrave` definitions, or cleared
  rows. Server validation still decides placement.
- `GridController` does **not** highlight fog tiles on hover.

---

## Authoring new weather

1. Add a weather id constant in `WeatherConfig`.
2. Extend `WeatherUtil` with rule helpers (prefer pure functions).
3. Author `weather = "..."` on the relevant `Shared.Levels` entries.
4. Teach `WeatherController` (and any server rules) the new id — do **not**
   hardcode day numbers in Services.
