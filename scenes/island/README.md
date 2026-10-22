# Island foundation — Task 7.3

Godot 4.7.2 / Terrain3D 1.0.2, unchanged Compatibility renderer and
GodotPhysics3D. F5 → Play opens `island.tscn`; F6 runs it directly.
The playground remains `res://scenes/main.tscn`, with all collection fixtures.
The separate `terrain_preflight` scene is preserved.

## Saved landscape

One native **512 x 512 region**, 1 m vertex spacing, region location `(0, 0)`.
Dry land spans approximately X 53–479 / Z 62–444 m, surrounded by seabed.
The larger footprint gives space for longer mountain ridges, broad valleys and
gentle beach approaches without adding regions, streaming or a terrain framework.

Measured from the saved height image (water surfaces excluded):

| Measure | Task 7.1 | Task 7.2 | Task 7.3 |
| --- | ---: | ---: | ---: |
| Region width | 256 m | 512 m | 512 m |
| Dry land | 28,017 m² | 117,838 m² | 114,189 m² |
| Dry land below 20° | 14,214 m² | 60,499 m² | 53,327 m² |
| Elevation range | −7 to 42.36 m | −7 to 91.28 m | −7 to 90.62 m |

The west massif is a long bent crest with branching foothills; the east massif
is lower and offset south. An incomplete northern rim connects their landscape.
Broad lowlands and a southern shelf replace repeated fine-scale ground noise.
Three embayments break the asymmetric coast. Most coastal transitions are
gentle, with only a few steeper headlands. A roughly 60 m lake, water level 5 m,
sits east of the valley center, containing a small dry island. Task 7.3 carved
directional erosion channels between branching ridges, varied the crests without
raising the overall summit height, and added two local low hills and a shallow
drainage valley. Three asymmetric coastal coves interrupt the continuous shore.
The lake now combines offset basins, with a southern lobe and an uneven shoreline.
The exact spawn floor and the established main route landmarks were preserved.

`data/terrain3d_00_00.res` contains the editable height/control/color maps.
Grass/earth/stone `assets.tres` and its tiny solid-color textures are unchanged.
The existing light/sky remain, with lighter distance fog for the larger scene.
`Sea` and `Lake` are simple opaque planes, without water scripts or colliders.
Native mesh size 64 retains more terrain detail at distance than the previous 48.

The existing player, camera rig and menu are instanced, with empty inventory.
World collision remains layer 1 / mask Player 2. Native dynamic terrain collision
follows the active camera (64 m radius), including lake bed and islet. The player
spawns on dry, gentle ground at `(252, 7.72, 367)`. R still returns to spawn.

## Editing and backup

Open `island.tscn`, select **Terrain3D**, sculpt/paint through the installed
plugin, and save the scene/terrain. Reopen and run F6 after changes. The transform
is locked by the plugin: edit the terrain data rather than moving/scaling it.
If sculpting near spawn, keep the player just above dry ground.

The original native Task 7.1 region is preserved in `backups/task_7_1/`, with a
verified identical SHA256 recorded there. It is never loaded by the active world.
To inspect it separately, use region size 256 and that backup directory.

Task 7.2 is additionally preserved byte-for-byte in `backups/task_7_2/`, including
its recorded SHA256. Task 7.3 did not invoke `build_island.gd`. Its separate
`tools/refine_island.gd` reads the hash-verified frozen backup and applies local
crest, gully, lowland, bay and lake edits. It preserves the colour map, uses the
existing material IDs to follow edited slopes, and does not change scene water,
lighting or textures. Intentional offline reapplication requires:

```powershell
& '<Godot executable>' --headless --path . --script res://tools/refine_island.gd -- --refine-island-v3
```

This replaces subsequent hand edits; normal play only loads saved native data.

`tools/build_island.gd` is controlled **offline** heightmap authoring, seed 72043.
It does not recreate terrain on startup. Ordinary editing uses only the saved
native region. The obsolete `--write-island` flag is rejected. Deliberately
replacing the current sculpted terrain requires the preserved backup and:

```powershell
& '<Godot executable>' --headless --path . --script res://tools/build_island.gd -- --write-island-v2
```

This replaces all current heights/paint. Back up any new hand edits first.

## Verification

`tests/run_tests.ps1 -GodotPath '<exe>' -Graphical` now includes nine suites,
including the original separate terrain preflight. The runner checks log errors
as well as exit status. Terrain-dependent island test coordinates were updated
to the actual new landscape; existing gameplay/model tests were preserved.

The island suite covers native map/material loading; safe dry spawn; finite
heights; land/flat-area measures; collision at both massifs, valley, lake shore,
islet and beach; lake water/bed elevations; real 12-second walks into the valley
and toward the southern beach; jumping; both inventory windows' pause state;
and native edit/save/reload using ignored scratch copies in `.godot/`.

A conservative **4 m grid** checks dry routes with local/edge grades below 32°.
The spawn connects to the shelf, both sides of the lake, both mountain approaches,
northern saddle and four coastal sectors. Connected grid coverage is about
74,448 m² after Task 7.3 (78,768 m² before). This is an offline regression measure, not gameplay navigation, and
does not imply that every steep summit or every point between samples is walkable.
Actual player movement is checked separately on the valley and coastal routes.

The collision-ray test now starts above each saved height: its former fixed
80 m origin was below the new western crest. Collision tolerance is unchanged.
No generation, modification or saving of the active map happens in tests.

Screenshots under `.godot/`: `island-ground-tps.png`, `island-ground-fps.png`,
`island-overview.png`, `island-top.png`, `island-west.png`, `island-east.png`,
`island-lake.png`, `island-beach.png`. All are real Godot captures, not reference
art. MCP also opened/reloaded the scene, inspected the native region and launched
the game; the live player was grounded at `(252, 7.6555, 367)` with no startup error.
Physical mouse/keyboard feel and editor brush/undo gestures remain manual.

Final verification on 2026-10-22: **616 assertion executions passed** (387
headless, 229 graphical), including 19 headless / 27 graphical island checks and
11 separate preflight checks. Import and bounded main-menu/playground startup
checks exited 0 without logged errors. The original backup hash still matches.

Task 7.3 repeated that full workflow with the tests unchanged: **616 passed**.
Overhead, west/east, ground, lake and beach captures were checked; a live MCP
first-person lake view confirmed the player grounded at `(238, 7.429, 301)`.
The saved map reloads as one 512-region with height/control/colour maps embedded
in the active data file, not dependent on the backup. Task 7.2 backup SHA256 was
verified again after all sculpt passes. No scene, lighting, water or material
resource changes were made during Task 7.3, and the V2 generator was not run.

## Current limits / next step

Terrain/material detail remains deliberately simple at 1 m spacing, including
visible broad paint transitions. No vegetation, detailed art or world supplies
were added. The islet is separated by water; swimming/drowning and water-boundary
behavior do not exist yet. Water is visual, so the player can walk on submerged
terrain and eventually leave the finite region; R returns to spawn.

The existing native Terrain3D interpolation deprecation warning remains on Godot
4.7. Next, walk the main routes manually and selectively sculpt local crests,
beach approaches and lake banks. Preserve the open lowlands for later placement
of gathering/building tests instead of filling them with decoration now.
