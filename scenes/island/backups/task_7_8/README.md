# Island foundation — Task 7.8

## Task 7.8: selective cohesion pass

The saved Task 7.7 region was edited directly, **without regenerating the island**.
`backups/task_7_7/` contains its native data, scene, generator and documentation;
the native SHA-256 is
`7b94d6db69e2b98bbfd15b0606906dc723a1a2748c8ed3ceeaa55d6da55a6b68`.

Nine smoothly bounded elliptical transition areas receive modest corrections:
the west/east lake-facing mountain feet, both southern mountain approaches,
northwestern/northeastern upland shoulders, southwestern meadows, southern ridge
transition and southeastern hills. A sparse Gaussian neighborhood reduces local
curvature without imposing flat pads, terraces, repeated bumps or new noise.
Corrections taper by distance and elevation. No island-wide smoothing is applied.

135,537 cells change by more than 0.1 mm (about 13% of the region); the largest
adjustment is 0.876 m. Aggregate squared slope across edited cells falls from
22,306.48 to 22,074.02, about 1%. This is a restrained transition correction,
not a claim that steep mountains became building ground. Existing calm lowlands
and clearings remain available for future assets; no placement system is added.

All original heights at or below 8 m and at or above 58 m remain exactly unchanged.
This protects the sea/lake waterlines, low beaches, lake island and high crests.
Control and color maps are byte-identical. Lake dimensions, water planes, camera,
spawn, lighting, materials, renderer and gameplay code are unchanged.
Dry area remains 588,170 m²; area below 20° remains 331,700 m². The connected
4 m route grid measures 488,672 m², versus 488,752 m² previously; this tiny sampling
change does not remove any required landmark connection or physical walking route.

The existing `refine_island.gd` entry point is now a guarded native-data editor:

```powershell
& '<Godot executable>' --headless --path . --script res://tools/refine_island.gd -- --polish-island-v8
```

It requires both active data and the Task 7.7 backup to match the recorded hash.
It refuses repeat execution against the refined result or later hand sculpting.
The full V7 generator is retained for historical restoration, but now refuses
active data newer than Task 7.6. Normal gameplay never runs either authoring tool.

Focused verification uses:

```powershell
./tests/run_tests.ps1 -GodotPath '<Godot executable>' -TerrainOnly -Graphical -FocusedViews
```

This retains import, terrain assertions, preflight, bounded startup and graphical
checks, while replacing the full screenshot batch with six views: whole-island
overhead, both mountain feet, southern transition and two grounded FPS poses.
Existing collision/route/waterline/persistence limits remain unchanged. Additional
assertions check bounded local edits, protected heights, unchanged paint maps and
reduced slope energy. No inventory/gathering/equipment suites are repeated.

Actual result: **79 assertions passed** (34 headless island, 34 graphical island,
11 preflight), plus import, bounded menu/playground startup and six focused
renders. The first graphical attempt entered pause near the beach walk and then
failed the dependent menu checks, consistent with external focus loss. Only that
graphical run and the pending six-view survey were repeated; both then passed.
The test logs future focus loss without suppressing native pause behavior.
All six final images were reviewed in `.godot/island_survey/task78-after/`.
The original 2.5 m adjacent-height and all route/physics tolerances remain intact.

A fixed-camera rendering diagnosis compared original shading, disabled native
texture projection and color-based ambient light. Neither alternative removes
the dark steep-face patches; no diagnostic setting was saved. Existing normal
texture values were also checked. The prior unshaded comparison and native
height/collision checks distinguish these lighting-dependent surfaces from holes.
The remaining strong shading contrast and 1 m/native LOD edges are not hidden by
new materials, renderer changes or broad terrain smoothing.

The following sections document the preserved Task 7.7 baseline.

Godot 4.7.2 / Terrain3D 1.0.2, Compatibility renderer, GodotPhysics3D.
F5 → Play loads `island.tscn`; F6 runs it directly. The original playground
remains `res://scenes/main.tscn`; terrain_preflight remains isolated.

## Controlled landscape refinement

One saved **1024 × 1024 m native region**, 1 m vertex spacing, location `(0, 0)`.
Task 7.7 preserves Task 7.6's outer coastline, northern gulf, western inlet,
mountain ridges, connected foothills, southern terraces and northeastern uplands.
Changes are restricted to the central lake basin and selected coastal profiles.
There is no global noise/smoothing pass or runtime generation.

- **Lake:** approximately **183 × 177 m**, **22,244 m²** water, about 3.4 times
  the old lake area. Its asymmetric basin combines a broad northern shore,
  eastern basin, western indentation and narrower southern bay. The native
  heightmap is excavated, rather than merely enlarging the water mesh.
- **Islet:** near `(538, 488)`, approximately **38 × 24 m**, **778 m²** dry land,
  **232 m² below 10°**. This is about 3.5% of the lake's water area. A low plateau
  and asymmetric shoulder replace the old tiny dome; actual walking is tested.
- **Lake banks:** the outside profile rises with distance and rejoins existing
  terrain within 65 m. A smooth minimum avoids raising low valley ground or
  cutting a broad flat shelf into mountain faces. Five principal crest heights
  are compared against the Task 7.6 backup within 0.1 m.
- **Beaches:** southern, southwestern and western-inlet profiles extend farther
  inland. Narrower northern/eastern shores and rocky capes remain for contrast.
  Read-only measurements of ground between 0–3 m in fixed coastal rectangles
  grew from 3,134 to 4,230 m² (south), 2,897 to 3,407 m² (southwest), and 1,768
  to 2,065 m² (western inlet). These are sampled low coastal areas, not a
  calculation of total beach surface or material coverage.

Sea level stays 0 m; lake level stays 5 m. The lake's containing plane is
260 × 210 m, centered at `(535, 5, 480)`; every edge is buried beneath land.
Simple grass/earth/stone assets, water material, sky, lighting and mesh size 128
are unchanged. No vegetation, new assets, renderer changes or gameplay additions.

## Measured land use

| Measure | Task 7.6 | Task 7.7 |
| --- | ---: | ---: |
| Dry land | 603,932 m² | 588,170 m² |
| Dry land below 20° | 341,581 m² | 331,700 m² |
| Connected dry 4 m path grid below 32° | 509,040 m² | 488,752 m² |
| Southern land above 20 m, below 20° (Z 700–900) | 63,219 m² | 62,442 m² |
| Elevation range | −8 to 112.11 m | −8 to 112.11 m |

The larger lake retains substantial usable valley and upland areas. The 4 m
route grid is a conservative regression measure, not gameplay navigation or
a guarantee that every slope is walkable. Mountain faces intentionally remain steep.

## Loading, editing and backups

`data/terrain3d_00_00.res` embeds persistent, editable height/control/color maps.
Open `island.tscn`, select Terrain3D, sculpt/paint using the installed plugin and
save native data. The terrain transform stays locked; edit heights instead of
moving/scaling the node. Normal play loads data and never generates/saves it.

Spawn stays `(500, 9.57, 650)`, above the terrain floor (~9.462 m). R resets spawn.
Player, cameras, empty inventory, UI and MenuController are reused unchanged.
The island-only camera far plane stays 1800 m. Native dynamic collision uses
World layer 1 / Player mask 2 and follows the camera within its existing radius.

`backups/task_7_6/` preserves the preceding native region byte-for-byte, matching
scene, generator and documentation. Native SHA-256:
`6e384434cfcb55b0d22e4443734e118380cfe48b434742de4323d8fa13a38f9d`.
Earlier backups remain intact. Restore a matching scene with its native data.

Historical Task 7.7 full-generation command (not used for Task 7.8):

```powershell
& '<Godot executable>' --headless --path . --script res://tools/build_island.gd -- --write-island-v7
```

This now requires both active Task 7.6 data and its hash-verified backup, protecting
all later edits. For local Task 7.8 authoring use the guarded refinement described
above. Neither tool is attached to the gameplay scene.

## Focused verification

```powershell
./tests/run_tests.ps1 -GodotPath '<Godot executable>' -TerrainOnly -Graphical
```

Final Task 7.7 run: **79 assertions passed**: island 30 headless, 38 graphical,
and separate terrain preflight 11. Import, bounded headless menu/playground and
graphical menu startup exited 0 without logged errors. The native interpolation
deprecation warning remains; it is not a terrain failure.

Coverage includes native loading, eleven collision locations, actual valley and
coastal walking/jumping, walking over 5 m on the islet, pause integration, and
scratch-copy edit/save/reload without modifying active native data. Whole-map
checks retain the original area/grade/height-step limits: no painted holes,
maximum adjacent step **2.385 m** (limit 2.5 m), submerged boundaries, graded
sea/lake waterlines and buried lake-plane edges. New checks cover lake area,
islet proportions/flat ground and preservation of five original ridge landmarks.

Old lake-bank waypoints now lie inside the expanded basin and were moved to its
actual banks. The northwestern approach shifts 48 m north; its original native
collision sample remains at `(448, 392)`. No grade, collision, area or movement
tolerances were relaxed. Earlier iterations exposed steep approaches and a
clipped blend boundary; these were corrected before final verification. A later
visual pass replaced an artificial flat mountain-side excavation with rising banks. The final outline retreats from the western mountain foot and extends into the lower northern valley.

## Visual inspection

`tests/island_visual_survey.gd` captures native Godot renders without saving data:
complete overhead, four cardinal obliques, nine overlapping regional overheads,
both foothills, northern upland, southern plain, four lake shores, eight coastal
sectors and six actual grounded FPS player poses, including lake shore and islet.

Ignored output under `.godot/island_survey/`:

- `task77-before/`: Task 7.6 views copied before authoring.
- `task77-after/`: final 36 views and contact sheets.
- `task77-comparison.png`: matched top-down before/after views.
- `after/`: latest reusable test-runner survey output.

MCP verified editor access to Wildscape 4.7.2, native resource loading and the
actual main-menu Play transition, grounded spawn and a live lake-shore FPS view.
No project/plugin configuration was changed for inspection.

A live MCP comparison with the same camera and temporarily unshaded rendering
confirmed that the dark western rock patch is lighting-dependent, not a terrain
hole. Debug drawing was restored immediately; no material or lighting changes
were saved. Diagnostic captures: `.godot/task77-west-lit.png` and
`.godot/task77-west-unshaded.png`.

## Remaining limitations

Water is visual-only: no swimming, drowning, boats or boundary system. Close
waterlines reveal 1 m sampling; distant native LOD simplifies terrain. The simple
solid-color materials remain intentionally unfinished. Extended manual traversal
of every route and editor brush/undo gestures are not exhaustively tested.
Some steep rock faces retain conspicuously dark shading in the existing renderer
and lighting; this visual limitation is preserved rather than disguised as a
heightmap repair.
No unrelated inventory/equipment/gathering suites were repeated for terrain-only
changes. No commits, pushes or merges were created.
