# Island foundation — Task 7.6

Godot 4.7.2 / Terrain3D 1.0.2, Compatibility renderer, GodotPhysics3D.
F5 → Play loads `island.tscn`; F6 runs it directly. The original playground
remains `res://scenes/main.tscn`, and terrain_preflight remains isolated.

## Complete landscape composition

One saved **1024 × 1024 m native region**, 1 m vertex spacing, location `(0, 0)`.
Task 7.6 replaces the repetitive coastline and reorganizes regional elevations;
it does not uniformly enlarge or blur the previous island.

- **Silhouette:** a deep northern gulf, sheltered western inlet, longer quiet
  eastern shore, distinct rocky capes and a substantial southern peninsula.
  Coast control points no longer alternate regularly between convex/concave lobes.
  The region retains submerged margins on all four sides.
- **West massif:** the existing bent, branching mountain chain now rises from a
  broad northwestern upland. A lower ridge/fan continues through the western
  foothills toward the southwest, connecting it with the new meadows and terraces.
- **East massif:** its distinct lower silhouette sits within an eastern elevation
  belt, with a long southwestern foothill extension reaching the southeastern hills.
- **Underused regions:** southwest terraces, a southern low ridge, southeastern
  rolling high ground, a shallow western depression and northeastern plateaus.
  These are authored regional landforms; no global noise layer was added.
- **Central valley:** broad, gently meandering lowlands separate the elevated
  belts and connect the north, lake, western inlet and southern coast. The lower
  valley deliberately remains open for later gathering/building/settlement tests.
- **Lake:** an elongated, one-sided indented basin replaces the flower-like
  outline. Graded access remains around it; the small asymmetric islet is retained.
  Existing water plane/material and water level 5 m remain unchanged.

The high ridge crests are rounded only over their central few meters, reducing
knife-like peaks while preserving the main silhouettes. Connected uplands replace
abrupt transitions from a small isolated massif to a flat nine-meter base.
Existing local drainage cuts, smooth ridge unions, robust polygon containment,
positive waterline grades and distance-based material painting remain in place.
No new lighting, textures, shader framework, water system or gameplay was added.

## Measured land use

Measurements use saved native heightmaps and the unchanged sea/lake levels:

| Measure | Task 7.5 | Task 7.6 |
| --- | ---: | ---: |
| Dry land | 460,041 m² | 603,932 m² |
| Dry land below 20° | 311,154 m² | 341,581 m² |
| Connected dry 4 m path grid below 32° | 400,208 m² | 509,040 m² |
| Southern land above 20 m, below 20° (Z 700–900) | 3,361 m² | 63,219 m² |
| Elevation range | −8 to 93.72 m | −8 to 112.11 m |

Land area grows about 31%, while gently sloping usable land also increases.
The southern measure distinguishes actual elevated usable ground from merely
adding empty shoreline or making existing flat plains larger.

`data/terrain3d_00_00.res` embeds editable height/control/color maps. Grass/earth/
stone assets, basic paint rules, lighting, sky, water and native mesh size 128
are retained. No generation is attached to the gameplay scene.

Spawn X/Z stays `(500, 650)`; Y is 9.57 m just above the new floor (~9.462 m).
R returns to spawn. Existing player, cameras, empty inventory, UI and menu scenes
are instanced as before. The island-only camera far plane remains 1800 m.
World collision stays layer 1 / mask Player 2; dynamic terrain collision follows
the active camera within the existing 64 m radius.

## Editing and guarded offline authoring

Open `island.tscn`, select Terrain3D, sculpt/paint using the installed plugin and
save native data. The terrain transform remains locked; edit heights rather than
moving/scaling the node. Recheck spawn and routes after hand edits.

`backups/task_7_5/` preserves the previous native region byte-for-byte, plus its
scene, offline source and documentation. SHA-256 is recorded there. Earlier
backups remain intact. Restore a matching scene when restoring older terrain.

There is one active offline implementation, `tools/build_island.gd`.
`refine_island.gd` only rejects obsolete operations. All older authoring flags
are rejected. Back up later hand edits before deliberately replacing heights/paint:

```powershell
& '<Godot executable>' --headless --path . --script res://tools/build_island.gd -- --write-island-v6
```

This requires the hash-verified Task 7.5 backup. Normal play never generates or
saves terrain, and inspection/tests do not modify the active native region.

## Focused verification

```powershell
./tests/run_tests.ps1 -GodotPath '<Godot executable>' -TerrainOnly -Graphical
```

Actual result on 2026-10-22: **69 assertions passed**: island 25 headless,
33 graphical, separate preflight 11. Import, bounded headless menu/playground
startup and graphical menu startup exited 0 without logged errors. Four additional
survey poses require the real CharacterBody3D player to be grounded before capture.

The suite covers native loading, eleven collision locations, spawn, actual valley
and coastal walks/jumping, pause integration and native scratch-copy edit/save/
reload. Whole-map continuity/holes and all four lake-plane edges remain checked.
The final maximum adjacent height difference is **1.338 m**; all **4,135 sea-level
samples** have a positive grade above 0.05. Every region boundary is submerged
below −5 m. There are no painted terrain holes.

Tests were strengthened rather than relaxed: minimum dry/gentle area increased
to 550,000 / 300,000 m²; connected area to 450,000 m². Southern high-ground use
and all four boundaries received explicit checks. Path coverage adds southwest,
southeast and northeastern uplands. The west/east/south coastal landmarks moved
with the actual shoreline. The southern physical walk now starts at Z 880 and
must reach Z > 932 on dry ground below 5 m, rather than stopping at the old beach.
Original grade, collision, jump and movement tolerances remain unchanged.

The 4 m route grid is an offline regression measurement, not gameplay navigation
or a guarantee of walkability at every point between samples. No unrelated full
inventory/equipment/gathering suites were repeated for this terrain-only task.

## Full-map visual coverage

`tests/island_visual_survey.gd` saves native Godot renders without editing data:

- One complete top-down image and four cardinal whole-island oblique views.
- Nine overlapping regional overhead tiles covering the entire landmass.
- Both mountain foothills, northern upland and southern plains.
- Four lake shores and eight updated coastal sectors.
- Four real FPS player poses: southwest terrace (~40.76 m floor), southeast
  hills (~36.63 m), northeast plateau (~28.42 m) and western inlet (~11.45 m).

All **34 final views** were reviewed. Before/after whole-island and regional
angles are identical, enabling direct comparison. Coastal eye positions were
updated to the reshaped shore instead of photographing the old inland locations.

Images under ignored `.godot/island_survey/`:

- `task76-before/`: 30 baseline views of Task 7.5.
- `task76-after/`: 34 final views, individual PNGs and contact sheets.
- `task76-comparison.png`: matching overheads, Task 7.5 left / Task 7.6 right.
- `after/`: output of the reusable terrain test runner (same final geometry;
  rerun the survey for the latest camera headings).

Godot editor loading and an editor camera preview were checked through MCP.
Temporary preview-only camera/visibility changes were discarded without saving.
The connection initially had no editor session; opening the existing project
restored it without installing/changing plugins. MCP then verified the real
main-menu Play action loads the island, unpaused, with the player on the terrain.
Native data and backup hashes remained unchanged by the tests and previews.

## Remaining limitations

Terrain and the existing solid-color materials remain intentionally simple;
close waterlines still reveal 1 m sampling and distant native LOD simplifies
some ridges. Water is visual-only and the finite region has no swimming/drowning
or gameplay boundary system; R resets spawn. Extended manual traversal of every
route and editor brush/undo gestures are not exhaustively verified.

The known native interpolation deprecation warning remains. The editor also
reports existing variable-shadowing/confusable-local warnings in unchanged menu
and inventory scripts. These are warnings, not failed terrain tests; unrelated
scripts were not refactored. No commits, pushes or merges were created.
