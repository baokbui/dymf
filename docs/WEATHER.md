# Weather System

Per-day weather is **data-driven** on `LevelDefinition.weather`. Services and
controllers never branch on day numbers for fog/night — they read the current
day's definition (or the `weather` field on `LevelStateChanged`).

Status: ✅ `Night` (Days 21–24) · ✅ `NightFog` (Days 25–34) · ✅ `NightFogReceded`
(Days 35–40).

---

## Weather ids

| Id | Config constant | Campaign | Effects |
| -- | --------------- | -------- | ------- |
| `Night` | `WeatherConfig.NIGHT` | Days **21–24** | Moonlit night Lighting only |
| `NightFog` | `WeatherConfig.NIGHT_FOG` | Days **25–34** | Night + fog bank; **3** east lawn columns unplantable |
| `NightFogReceded` | `WeatherConfig.NIGHT_FOG_RECEDED` | Days **35–40** | Same night fog look; only **2** east columns unplantable |

---

## Fog extras (`NightFog` / `NightFogReceded`)

| Effect | Owner | Behavior |
| ------ | ----- | -------- |
| Visible fog banks | Client `WeatherController` | Soft particle mist (no box mesh): heavy deep forest → medium near forest → light on fog lawn columns; monsters stay fully visible. Lawn bank width follows `WeatherConfig.fogStartColumn(weather)`. |
| Unplantable fog columns | Server `BrainrotService` + client placement | Easternmost `fogPlotColumns(weather)` lawn columns reject **permanent** plants; **one-shot** Brainrots (`triggersOnPlace` — Lirili, Bombardino) may still be placed there. Other plants on fog columns are cleared on prep / lawn restore |
| No fog-tile hover | Client `GridController` | Fog columns do not show a hover highlight |
| Clear-lawn coin drops | Server `CoinService` | Passive rain + Ballerina spit land only on non-fog tiles |

Fog does **not** hide monsters (keeps combat readable and avoids heavy per-tile FX).

---

## Configuration

| Module | Role |
| ------ | ---- |
| `Shared.Config.WeatherConfig` | Weather ids, fog column counts, night Lighting, fog bank look |
| `Shared.Utilities.WeatherUtil` | `isNight`, `isNightFog`, `isFogPlotColumn`, `randomClearPlotPosition` |

`WeatherConfig.fogPlotColumns(weather)` → blocked column count (`3` for
`NightFog`, `2` for `NightFogReceded`, `0` otherwise).

`WeatherConfig.fogStartColumn(weather)` → first blocked lawn column
(`COLUMNS - fogPlotColumns + 1`; with 9 columns → **7–9** or **8–9**).

`WeatherConfig.forestFogDepthFromLawnEdge()` → studs from the lawn east edge
through the player margin + full enemy-column forest (aligned with
`ForestBuilder`).

---

## Server rules

- `LevelService` includes `weather` on every `LevelStateChanged` / join payload.
- `LevelService.getWeather(player)` reads the current day's definition.
- On NightFog / NightFogReceded prep and after lawn restore:
  `BrainrotService.clearFogBlockedPlacements` strips Brainrots on fog columns
  and refreshes the committed lawn checkpoint.
- `BrainrotService.place` rejects fog columns for permanent plants (toast);
  one-shot `triggersOnPlace` units (Lirili / Bombardino) are allowed in fog.
- `CoinService.dropRandomCoinForOwner` / `dropCoinForOwner` skip fog columns.

---

## Client rules

- `WeatherController` applies night Lighting for `Night`, `NightFog`, and
  `NightFogReceded`; fog banks for both fog weathers (lawn band respects
  that weather's column count).
- `PlacementController.setWeather` blocks ghost/place on fog columns except
  when the selected Brainrot has `triggersOnPlace`.
- `GridController` does **not** highlight fog tiles on hover.

---

## Authoring new weather

1. Add a weather id constant in `WeatherConfig`.
2. Extend `WeatherUtil` with rule helpers (prefer pure functions).
3. Author `weather = "..."` on the relevant `Shared.Levels` entries.
4. Teach `WeatherController` (and any server rules) the new id — do **not**
   hardcode day numbers in Services.
