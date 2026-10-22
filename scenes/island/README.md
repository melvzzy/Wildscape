# Island foundation — Task 7.7

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

There is one active offline implementation, `tools/build_island.gd`.
The retired `refine_island.gd` and older authoring flags reject execution.
Back up later hand edits before deliberately replacing heights and paint:

```powershell
& '<Godot executable>' --headless --path . --script res://tools/build_island.gd -- --write-island-v7
```

This requires the hash-verified Task 7.6 backup and can take several minutes.
It replaces later editor sculpting; it is never attached to the gameplay scene.

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
