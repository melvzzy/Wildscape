# Island foundation — Task 7.4

Godot 4.7.2 / Terrain3D 1.0.2, unchanged Compatibility renderer and
GodotPhysics3D. F5 → Play opens `island.tscn`; F6 runs it directly.
`res://scenes/main.tscn` remains the original playground with collection fixtures;
the separate `terrain_preflight` fixture is unchanged.

## Landscape composition

One native **1024 × 1024 region**, **1 m vertex spacing**, location `(0, 0)`.
The land occupies approximately 780 × 810 m inside a submerged border. The extra
space gives 300–400 m mountain chains broad feet, a generous central valley and
comfortable coastal approaches without streaming or additional regions.

This is a new authored layout, not another filter on the previous heightmap:

- An asymmetric spline coastline with western coves, northern fingers, eastern
  headlands and broad southern beaches. Beach gradients vary by coastal sector;
  three local rocky headlands interrupt the accessible shores.
- A high western chain with a bent crest and three branching spurs, and a lower,
  offset eastern chain with two spurs. A low broken northern rim frames the
  crater-inspired basin without enclosing it behind steep walls.
- Broad open lowlands, distinct southwestern and southeastern hills, smaller
  valleys between the spurs and gentle routes around both massifs. Small relief
  is restricted to mountain faces rather than applied uniformly to the ground.
- An irregular roughly 110 × 100 m lake basin with graded banks and a dry islet.
  Water remains at 5 m; the existing simple lake plane was resized/repositioned.

Measured from saved heights, excluding water-covered ground:

| Measure | Task 7.3 | Task 7.4 |
| --- | ---: | ---: |
| Region width | 512 m | 1024 m |
| Dry land | 114,189 m² | 457,883 m² |
| Dry land below 20° | 53,327 m² | 322,641 m² |
| Connected dry 4 m path grid below 32° | 74,448 m² | 381,360 m² |
| Elevation range | −7 to 90.62 m | −8 to 92.80 m |

`data/terrain3d_00_00.res` embeds the editable height/control/color maps.
Grass/earth/stone resources, lighting, sky, water material and renderer are
unchanged. Paint follows the new elevations/slopes using the same three assets.
There are no runtime generation scripts attached to the scene.

The reusable player and gameplay menu are instanced, with initially empty
inventory. Spawn is `(500, 11.28, 650)` on the southern valley approach (floor
about 11.177 m). R returns there. Only this scene overrides the player camera's
far plane from 160 to **1800 m**, so distant mountains remain visible in FPS/TPS.
The playground camera configuration remains unchanged.

World collision remains layer 1 / mask Player 2. Native dynamic terrain collision
follows the active camera (64 m radius); camera visibility distance does not
increase that physics radius.

## Editing, backups and deliberate rebuilds

Open `island.tscn`, select **Terrain3D**, sculpt/paint using the installed plugin,
and save the native terrain. Reopen and run F6 after edits. The terrain transform
is plugin-locked: sculpt data rather than moving/scaling the node. Keep the player
above dry ground if editing near spawn.

`backups/task_7_3/` preserves the original 512 m region byte-for-byte, the scene
configuration and both previous offline tools as non-executable `.txt` snapshots.
Its SHA-256 is recorded in that folder. Earlier Task 7.1/7.2 backups remain intact.
To restore an older region, restore its matching scene region size and spawn too.

There is one active offline authoring implementation, `tools/build_island.gd`.
It creates a deterministic authored heightmap, imports it through native
Terrain3D APIs and saves the native region. It is never called during play.
`tools/refine_island.gd` is a short retired-entry-point guard; it cannot overwrite
the new island with old refinement data. All old authoring flags are rejected.

**Back up later hand edits before rebuilding.** The following deliberately
replaces current heights and paint and requires the hash-verified Task 7.3 backup:

```powershell
& '<Godot executable>' --headless --path . --script res://tools/build_island.gd -- --write-island-v4
```

## Focused verification

After terrain changes, import and run the existing focused suites:

```powershell
& '<Godot executable>' --headless --path . --import
& '<Godot executable>' --headless --path . --script res://tests/island_test.gd
& '<Godot executable>' --headless --path . --script res://tests/terrain_preflight_test.gd
& '<Godot executable>' --path . --script res://tests/island_test.gd -- --capture-island
```

Check exit codes **and logs** for SCRIPT ERROR / ERROR / FAIL / parse errors.
The full `tests/run_tests.ps1 -GodotPath '<exe>' -Graphical` workflow remains
available; this terrain-only task does not require unrelated inventory/gathering
suites. Player, interaction and menu-flow checks also cover integration.

The island test checks finite native data, material loading, area/grade measures,
connected dry routes to ten landmarks, native collision at eight locations,
mountain/lake/islet elevations, actual 12-second valley and beach walks, jumping,
inventory-window pause integration and native edit/save/reload in ignored scratch
copies. Terrain-dependent coordinates now match the rebuilt geography; slope,
collision and movement tolerances remain unchanged. Area minimums were increased
for the larger island. An extra check protects the island camera visibility fix.

A 4 m path grid is a conservative offline regression measure, not gameplay
navigation or a guarantee that every steep summit/between-sample point is walkable.
The physical beach walk starts on its coastal approach; spawn is now inland.

Actual Godot screenshots are saved under `.godot/`: `island-ground-tps.png`,
`island-ground-fps.png`, `island-overview.png`, `island-top.png`, `island-west.png`,
`island-east.png`, `island-lake.png`, `island-beach.png`. MCP also verifies editor
reload and actual grounded player-level views. Physical mouse feel and editor
brush/undo gestures still require manual testing.

Final verification on 2026-10-22: **150 assertions passed**: island 20 headless
and 28 graphical, preflight 11, player 23, interaction 26, menu flow 42. Import,
bounded headless main-menu/playground startup and graphical main-menu startup
all exited 0 without logged errors. All eight final rendered views were inspected;
MCP additionally confirmed actual grounded player views and editor/native region
reload. Native edit/save/reload passed using scratch copies; the active region
and the Task 7.3 backup hashes remained unchanged by verification. No unrelated
inventory/gathering suites were rerun for this terrain-only task.

During inspection, the inherited 160 m camera cutoff hid the distant mountains;
the scene-only far-plane override fixes that. The route test also identified an
overly abrupt first lake-bank blend; widening the geometric transition restored
the tested dry connections without relaxing the slope or collision tolerances.

## Limits

Simple materials and 1 m geometry intentionally remain visible. No vegetation,
new gameplay, detailed assets or water physics were added. Water is visual: the
player can walk underwater or eventually leave the finite region; R resets spawn.
The existing Terrain3D interpolation deprecation warning on Godot 4.7 remains.
Next, walk the longer routes manually and selectively sculpt local ridge/bay
transitions while preserving broad usable valley space.
