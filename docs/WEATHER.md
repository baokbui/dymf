# Weather System

Per-day weather is **data-driven** on `LevelDefinition.weather`. Services and
controllers never branch on day numbers for fog/night — they read the current
day's definition (or the `weather` field on `LevelStateChanged`).

Status: ✅ `Night` (Days 21–24) · ✅ `NightFog` (Days 25–30).

---

## Weather ids

| Id | Config constant | Campaign | Effects |
| -- | --------------- | -------- | ------- |
| `Night` | `WeatherConfig.NIGHT` | Days **21–24** | Moonlit night Lighting only |
| `NightFog` | `WeatherConfig.NIGHT_FOG` | Days **25–30** | Night + visible fog bank (cosmetic) |

---

## NightFog extras (Days 25–30)

| Effect | Owner | Behavior |
| ------ | ----- | -------- |
| Visible fog banks | Client `WeatherController` | Soft particle mist (no box mesh): heavy deep forest → medium near forest → light on fog lawn columns; monsters stay fully visible |
| Unplantable fog columns | Server `BrainrotService` + client placement | Easternmost `FOG_PLOT_COLUMNS` (3) lawn columns reject placement; plants already there are cleared on prep / lawn restore |
| No fog-tile hover | Client `GridController` | Fog columns do not show a hover highlight |
| Clear-lawn coin drops | Server `CoinService` | Passive rain + Ballerina spit land only on non-fog tiles |

Fog does **not** hide monsters (keeps combat readable and avoids heavy per-tile FX).

---

## Configuration

| Module | Role |
| ------ | ---- |
| `Shared.Config.WeatherConfig` | Weather ids, fog column count, night Lighting, fog bank look |
| `Shared.Utilities.WeatherUtil` | `isNight`, `isNightFog`, `isFogPlotColumn`, `randomClearPlotPosition` |

`WeatherConfig.fogStartColumn()` → first blocked lawn column
(`COLUMNS - FOG_PLOT_COLUMNS + 1`; with 9 columns → **7, 8, 9**).

`WeatherConfig.forestFogDepthFromLawnEdge()` → studs from the lawn east edge
through the player margin + full enemy-column forest (aligned with
`ForestBuilder`).

---

## Server rules

- `LevelService` includes `weather` on every `LevelStateChanged` / join payload.
- `LevelService.getWeather(player)` reads the current day's definition.
- On NightFog prep and after lawn restore: `BrainrotService.clearFogBlockedPlacements`
  strips Brainrots on fog columns and refreshes the committed lawn checkpoint.
- `BrainrotService.place` rejects fog columns with a plant-failed toast.
- `CoinService.dropRandomCoinForOwner` / `dropCoinForOwner` skip fog columns.

---

## Client rules

- `WeatherController` applies night Lighting for `Night` and `NightFog`; fog
  banks only for `NightFog`.
- `PlacementController.setWeather` blocks ghost/place on fog columns.
- `GridController` does **not** highlight fog tiles on hover.

---

## Authoring new weather

1. Add a weather id constant in `WeatherConfig`.
2. Extend `WeatherUtil` with rule helpers (prefer pure functions).
3. Author `weather = "..."` on the relevant `Shared.Levels` entries.
4. Teach `WeatherController` (and any server rules) the new id — do **not**
   hardcode day numbers in Services.
