# Island foundation — Task 7.5

Godot 4.7.2 / Terrain3D 1.0.2, unchanged Compatibility renderer and
GodotPhysics3D. F5 → Play opens `island.tscn`; F6 runs it directly.
`res://scenes/main.tscn` remains the original playground. The separate terrain
preflight fixture, player/controller, gameplay UI and menus are unchanged.

## Saved landscape and regional work

One native **1024 × 1024 m region**, **1 m spacing**, location `(0, 0)`.
Task 7.5 retains the Task 7.4 footprint and deliberately open central valley.
Changes apply regionally across the entire island:

| Region | Quality pass |
| --- | --- |
| Western massif | Broader shoulders, smooth spur junctions, two branching drainage cuts and a southern foothill fan. |
| Eastern massif | Softer foot transitions, separate inner/outer gullies and a shallow southern side valley. |
| Northern rim | Rounded low crests, northeastern upland and coastal knolls; removed large triangular normal patches at ridge-segment endpoints. |
| Valley / southern plains | Preserved broad useful ground; added a western depression, low southern terrace and distinct eastern hill/valley transitions. No uniform fine noise. |
| Entire coast | More accurate 2 m authoring distance field, non-flat sea crossings, broad southern/western beaches and five rocky headland sectors. |
| Lake / islet | Graded non-flat shore profile, distance-based paint instead of a rectangular mask, and an asymmetric low islet with two joined shoulders. |

Measured from saved heights, excluding water-covered ground:

| Measure | Task 7.4 | Task 7.5 |
| --- | ---: | ---: |
| Region width | 1024 m | 1024 m |
| Dry land | 457,883 m² | 460,041 m² |
| Dry land below 20° | 322,641 m² | 311,154 m² |
| Connected dry 4 m path grid below 32° | 381,360 m² | 400,208 m² |
| Elevation range | −8 to 92.80 m | −8 to 93.72 m |

`data/terrain3d_00_00.res` embeds all editable height/control/color maps. There
is no terrain generation on startup. Lighting, sky, water surfaces/material,
solid-color texture assets and renderer remain unchanged. Only native terrain
mesh density and basic blend sharpness changed for artifact/readability fixes.

Spawn X/Z remains `(500, 650)`, with Y 11.38 m just above the new floor
(about 11.275 m). R returns there. The island-only camera far plane stays at
1800 m; the playground camera remains unchanged. World layer 1 / mask Player 2
and native dynamic terrain collision (64 m around the active camera) are retained.

## Identified causes and corrections

- Linear ridge-height interpolation changed its derivative at clamped segment
  endpoints. This produced large straight triangular normal patches, especially
  on the northern rim. Smooth endpoint interpolation and rounded unions fix the
  height function itself. Low ridges have rounded cross-sections; high exposed
  crests retain their sharper profiles.
- Near-zero shoreline grades previously left almost coplanar water/ground strips
  and long jagged fingers at distant LOD. A positive-grade coastal/lake profile
  and native mesh size **128** (previously 64) improve those edges. One-meter
  sampling remains visible on close, high-contrast waterlines.
- The old `rock > 0.05` overlay-ID switch could replace sand abruptly. Paint now
  uses the two strongest normalized material weights and broader slope samples.
  Rocky shore weights are no longer suppressed merely because they meet sea level.
  Blend sharpness 0 reduces patchy transitions with the existing neutral textures.
- Whole-map analysis found an isolated deep pit during authoring. The native
  polygon containment test reproducibly returned false at `(302, 738)` while its
  neighboring samples returned true. A half-open crossing test in the offline
  distance calculation removes that sign error. The final map's largest adjacent
  height difference is **1.414 m**, with no painted holes. This is an authoring
  calculation only, not a runtime terrain subsystem.

## Editing and backups

Open `island.tscn`, select **Terrain3D**, sculpt/paint through the installed
plugin, and save native terrain. Reopen and run F6 after edits. The transform
remains plugin-locked: sculpt the data rather than moving/scaling the terrain.
Keep the player just above dry ground when sculpting near spawn.

`backups/task_7_4/` preserves the native region byte-for-byte, the scene, offline
source and prior documentation. Its SHA-256 is recorded there. Earlier backups
remain intact. Restore a matching scene configuration with an older region.

There is one active offline authoring implementation: `tools/build_island.gd`.
The retired `refine_island.gd` only rejects obsolete operations. Old V4 and earlier
flags are rejected. **Back up later hand edits before deliberately rebuilding:**

```powershell
& '<Godot executable>' --headless --path . --script res://tools/build_island.gd -- --write-island-v5
```

This replaces current heights and paint and requires the hash-verified Task 7.4
backup. Ordinary play and editor sculpting do not call the authoring script.

## Focused tests and island-wide inspection

```powershell
./tests/run_tests.ps1 -GodotPath '<Godot executable>' -TerrainOnly -Graphical
```

The existing runner's optional terrain mode uses the same exit-code and log-error
checks as the full workflow, without rerunning unrelated inventory/gathering suites.
Its default full workflow remains available and unchanged.

Final verification on 2026-10-22: **65 assertions passed**: island 23 headless,
31 graphical and separate terrain preflight 11. Import, bounded headless main-menu
and playground startup, and graphical main-menu startup exited 0 without logged
errors. No previous collision, grade, movement or area tolerances were weakened.

The island suite now additionally checks whole-region height continuity / painted
holes, positive sea-level grades and burial of all four lake-plane edges. All
**4,152 sampled sea-level points** have grade above 0.05; the maximum neighboring
height step is 1.414 m. Collision rays now cover eleven representative positions,
including remote northern, northeastern and southwestern terrain. Existing actual
12-second valley/beach walks, jumping, pause integration and native scratch-copy
edit/save/reload remain in place.

A conservative 4 m grid verifies connected dry routes below 32° local/edge grade
between ten established landmarks. It is an offline regression measurement, not
navigation or a guarantee of walkability at every point between samples.

`tests/island_visual_survey.gd` produces **30 actual Godot views**:

- Full-island overhead and four elevated cardinal directions.
- Nine overlapping regional overhead tiles covering the complete island.
- Both mountain foothills, northern upland and southern plains.
- All four lake shores and eight coastal sectors at terrain-relative eye height.

Before/after individual images and two contact sheets per survey are under
`.godot/island_survey/before/` and `after/`. They were reviewed, including remote
edges. The existing island suite also saves its eight standard screenshots.
Four additional **live player** views were captured through MCP at the western
and eastern foothills, northern upland and lake; all four players were grounded.
They are saved as `after/live_west.png`, `live_east.png`, `live_north.png` and
`live_lake.png`. The survey is test-only and never saves terrain/scene resources.

MCP confirmed editor reload, native region configuration and an editor camera
preview. Automatic viewport framing does not reliably frame Terrain3D; island-wide
visual approval uses the real game captures instead. A temporary editor camera
pose used for preview was discarded without saving the scene. Brush/undo gestures
and extended physical keyboard/mouse exploration remain manual checks.

Active region and Task 7.4 backup hashes remained unchanged by the final tests.

## Remaining limits

The intentionally simple materials and 1 m height sampling are still apparent,
particularly on close shorelines. Native LOD can simplify distant silhouettes;
mesh size 128 trades more triangles for clearer geometry (not a hardware-wide
performance benchmark). No detailed textures, vegetation or new assets were added.
Water remains visual, without swimming/drowning or region-boundary behavior; R
returns to spawn. The existing Terrain3D interpolation deprecation warning on
Godot 4.7 remains. Longer manual routes and selective local sculpting can refine
individual places further without sacrificing the connected open lowlands.
