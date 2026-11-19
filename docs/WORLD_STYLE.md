# Studded world style ✅

The world uses a bright toy-brick finish inspired by the supplied reference.
The ground retains readable lawn checker colors; scenery and eligible unit
bodies use the same raised-square motif at different scales. These are PBR
material maps, not physical studs, collision parts or per-frame effects.

## Materials

Three Plastic-based MaterialVariants are declared under MaterialService in
`default.project.json`. No global material override is installed, so player
avatars, projectiles and unrelated props keep their materials.

| Variant | Stud repeat spacing |
| --- | ---: |
| BvmStudsGround | 2.8 studs |
| BvmStudsScenery | 2 studs |
| BvmStudsUnits | 0.85 studs |

They share original, seamless grayscale color, normal and roughness maps:

- ColorMap: `rbxassetid://122972533723280`
- NormalMap: `rbxassetid://86498502678851`
- RoughnessMap: `rbxassetid://88643028508905`

The source PNGs live in `assets/materials/studded`; the deterministic generator
is `tools/generate_stud_material.py` (Pillow + numpy). Those files are original
procedural artwork uploaded through the user's Studio account. Roblox's
[MaterialVariant](https://create.roblox.com/docs/reference/engine/classes/MaterialVariant)
provides tiling and surface relief. Engine graphics quality affects PBR detail.

## Construction and ownership

`Shared.Utilities.WorldStyle` owns assignment policy. PlotBuilder and
ForestBuilder style their completed scenery; GridService styles lawn tiles.
ModelUtil styles sanitized Brainrot, Monster, House, Store and Decor template
clones before use. This also covers farm residents and model previews.
Procedural unit/resident fallbacks receive the same finish. Source asset
models are not modified, and animation joints/poses are untouched.

WorldStyleService sets the shared baseplate finish and daytime lighting baseline.
Its tuning lives in WorldStyleConfig; brighter lawn/forest colors remain in
GridConfig and PlotConfig. WeatherController retains night/fog/desert ownership.
DesertVisuals reapplies the stud variants after swapping ground colors, including
sand beds and pyramids; leaving Desert restores the normal studded lawn.

## Preservation policy

- Keep mesh TextureID artwork, SurfaceAppearance, textured SpecialMeshes and decals.
  Those textured mesh surfaces require separately authored UV artwork to restyle.
- Preserve Neon, Glass, ForceField and Ice, invisible helpers, and valid custom
  MaterialVariants. A dangling variant name with no matching definition can use
  the new finish instead.
- `KeepAuthoredMaterial = true` on a part or model excludes it and its subtree.
- Preserve original physical properties when switching base material; geometry,
  collision flags, mass/density, friction and animation rig structure stay intact.
- The helper creates no additional Instances per styled part and has no frame loop.

## Verification and limits

Rojo build and Studio compilation pass. WorldStyle.spec verifies material policy,
idempotency, physical properties, nested exclusions, authored artwork/effect
preservation and missing-variant fallback. WorldStyleWeather.spec exercises
isolated Desert/day transitions, sand colors, pyramid materials and cleanup.

An isolated Edit-mode preview verified the shared ground, foliage and fence
finish and sample Zombie, Goblin Elite, Tung Tung Sahur, Ballerina Cappucina and
Chimpanzini Bananini models. The scene was removed after inspection. Texture
and mesh preloading succeeded after initial upload propagation. No real saves
or developer settings were changed. Full campaign/device and multiplayer
performance validation remain open.
