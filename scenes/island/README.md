# Compact island — Task 8.1 material and rendering foundation

## Material / rendering pass

The 768 m layout, all nine heightmaps and color maps are byte-identical to
Task 8.0. No geometry smoothing, new coast profile or regeneration was needed.
The complete pre-pass data, scene, assets and textures are preserved in
`backups/task_8_0/`; restore matching scene/assets/textures and all nine region
files together if reverting the material pass. Do not restore the older
single-region Task 7.8 data into the compact layout.

Four native Terrain3D texture slots use existing stable indices Grass=0,
Earth=1, Stone=2 and new Sand=3. Lightweight 128px tileable ImageTextures
include mipmaps and restrained tonal variation; albedo alpha is neutral height
0.5, normal alpha stores matte roughness 0.96. Flat normals have depth zero;
material AO is explicitly zero because these placeholders contain no authored
occlusion. UV scale remains 0.25. No custom shader or runtime generation.

The existing rock mask is feathered over several meters and supplemented only
on steep ground. Earth supplies subdued intermediate ground, while sand follows
low, gentle ocean/lake banks, fading out on steeper rocky shores. Native packed
base/overlay weights remain editable with Terrain3D's paint tools. Existing
hole/navigation/orientation/scale bits and all color-map variation are retained.
Macro tint is deliberately mild. Terrain geometry is not altered to hide shading.

Controlled same-camera comparisons showed the very dark west-facing patches
persist with material AO disabled but largely disappear with a higher sun.
They are primarily the direct-light terminator on steep, curved slopes with
insufficient fill, not missing triangles or holes. Sun elevation is now 52°
(previously 38°); azimuth and daytime colors are unchanged. Explicit ambient
color at energy 0.5 with 0.25 sky contribution keeps unlit faces readable.
Sun energy is reduced from 1.35 to 1.15 to avoid bleaching the new sand/stone.
This reduces the defect without flattening the heightmap or disabling lighting.

The native shader still raises material weights to at least the eighth power
with blend sharpness zero. Authored intermediate control weights compensate for
this contrast; feathering the original rock mask alone was insufficient. Sand
width varies with local grade, bank elevation and low-frequency variation,
rather than painting a constant-width beach ring. No shader override is used.

Native mesh size 128, smooth terrain normals, projection, camera far 1800 m,
water planes, fog and Compatibility renderer are retained. A size-64 comparison
did not justify reducing mesh density. One-meter sampling, the native shader's
distance-dependent normal filtering and clipmap LOD still permit fine stepping
and residual faceting on steep silhouettes; this is not claimed to be eliminated.

`tools/refine_island_materials.gd -- --materials-v81` is an OFFLINE authoring
record, guarded by exact pre-pass hashes. It stages/reloads all nine native
maps and verifies unchanged height bytes before committing. It intentionally
refuses the painted world or subsequent editor edits. Do not rerun to refresh
textures or overwrite later painting; edit assets or paint in the editor.

The focused island suite adds three material assertions (39 island + 11
preflight checks): unchanged height/color bytes, valid four-slot blended masks,
and consistent mipmapped matte texture packing. The previous three-texture
expectation was updated for the explicitly requested fourth material.

## Task 8.0 landscape foundation

Godot 4.7.2 / Terrain3D 1.0.2 / Compatibility / GodotPhysics3D.
F5 → Play opens `island.tscn`; F6 runs it directly. The original technical
playground stays independently available at `res://scenes/main.tscn`.

## Native layout

The saved world is **768 × 768 m**, using **3 × 3 native 256 m regions** at
**1 m vertex spacing**, locations `(0,0)` through `(2,2)`. Terrain3D exposes
64/128/256/512/1024/2048 m region sizes; 768 is not a single-region size.
Nine ordinary region resources achieve the preferred size without a terrain
framework, streaming layer, scene-per-tile system or scaled terrain node.

This reduces actual saved samples from 1,048,576 to 589,824 (43.75%). The nine
native files total about 2.93 MB rather than 4.97 MB. There is one Terrain3D
node and one active data directory. No obsolete 1024 m region remains active.
Mesh size 128, island camera far plane 1800 m and the renderer are retained.
Although the plugin inspector advertises a narrower mesh slider range, the
installed native setter accepts and returns 128; this was checked directly.

## Landscape adaptation

The previous saved height/control/color maps supply the landscape. This is not
an unrelated procedural island or a uniform image resize:

- A monotone cubic coordinate mapping reserves relatively more room for the
  central valley and lake, while compressing outer uplands more. Smooth tangents
  avoid artificial slope breaks at mapping control points.
- The two bent, branching mountain systems, northern gulf, western inlet,
  eastern capes, southern peninsula, hills and quiet open areas remain recognizable.
  Elevation compression varies with height; valley and lake levels remain stable.
  Maximum terrain height is approximately 81.16 m rather than 112.11 m.
- The lake remains a real native basin at water level 5 m. Its approximately
  16,933 m² water area is prominent relative to the smaller island. A local
  coordinate adjustment retains the islet's useful physical footprint: 778 m²
  dry land, 232 m² below 10°, rather than uniformly shrinking it with the world.
- Coast profiles retain broad sandy beaches and higher rocky headlands. Smooth
  inherited headland weights replace discrete nearest-shore type changes that
  caused thin height-normal streaks on some coastal slopes.
- Only resampling overshoots on steep lower faces are bounded locally; 225 such
  edits were needed. Peaks are not globally blurred. Encoded control-map bits
  use nearest-pixel copying, never interpolation of packed floating-point bits.

### Measured usable ground

| Measure | Compact world |
| --- | ---: |
| Dry land | 337,549 m² |
| Dry land below 20° | 183,768 m² |
| Connected dry 4 m route grid below 32° | 275,056 m² |
| Southern uplands above 20 m and below 20° | 31,431 m² |
| Lake water | 16,933 m² |
| Dry lake island | 778 m² |

These are terrain measurements, not a building-placement guarantee. Natural
clearings, coastal lowlands, valley ground and gently sloping uplands remain
available for future assets. No vegetation, resources or placement systems are added.

## Underwater terrain and boundaries

The same native heightmaps continue below sea level. Fractional shoreline seeds
and Euclidean-distance refinement form gradual submerged beaches and coastal
shelves, steeper short approaches at rocky capes, then deeper seabed. Rock-type
influence fades offshore; it cannot create abrupt Voronoi walls between bays.
Subtle broad seabed relief fades in/out with depth-distance.

The final map contains about 93,985 m² between −1 and −8 m and 62,872 m² below
−15 m. Minimum elevation is approximately −36.15 m. Every outer sample along
all four finite boundaries stays below −5 m. The ocean quad is only visual water,
not extra terrain or an infinite underwater world; it hides submerged outer
cutoffs from normal above-water play. There is no water collision, swimming,
buoyancy or underwater gameplay.

The lake plane is 210 × 190 m at `(414, 5, 352)`; all four edges remain buried
under actual land. Player spawn is `(376, 9.6, 494)`, above terrain at ~9.277 m.
R retains the existing spawn reset. Player, cameras, inventory, menus, materials
and lighting are reused. World collision remains layer 1 / Player mask 2.

## Editing, authoring and recovery

Open `island.tscn`, select Terrain3D and sculpt/paint with the installed plugin.
All nine regions are native and persistent. Keep the Terrain3D transform locked;
do not move/scale regions individually to resize the world. Recheck routes and
spawn after hand edits. No generation runs during normal gameplay.

`backups/task_7_8/` preserves the complete previous island: its native data,
scene, texture/assets, both tools, terrain tests, documentation and project-settings
snapshot. Native baseline SHA-256:
`d9591a794a001a8fba88b8c7e959699d61a9ab25b033cce14cc255f0b24961b1`.
Archived scenes/scripts/text resources use `.txt`; binary texture backups use
`.bak` to avoid registering duplicate asset/scene UIDs in the active project.

To restore Task 7.8, close Godot, preserve later work, replace the **entire** active
data directory with the backup's single-region data and restore the matching
`island.tscn.txt` as `island.tscn`. Do not mix a 1024 m region with the compact
256 m regions. Restore asset suffixes only if those assets also need recovery.
The settings snapshot is reference material, not an instruction to overwrite
unrelated later project changes.

There is one active offline adaptation tool:

```powershell
& '<Godot executable>' --headless --path . --script res://tools/build_island.gd -- --compact-island-v80
```

It requires exactly one active, hash-matching Task 7.8 original region plus its
verified backup. Output is first saved and reloaded in an ignored staging folder;
every native height tile must equal its authored 256-square source before active
data is replaced. Running it again against the compact world or later sculpting
is rejected. Historical generators are archived; `refine_island.gd` rejects old
1024 m refinement operations. No parallel terrain system or autoload is introduced.

## Focused verification

```powershell
./tests/run_tests.ps1 -GodotPath '<Godot executable>' -TerrainOnly -Graphical -FocusedViews
```

Actual checks: **36 compact-island assertions plus 11 independent preflight
assertions passed**, with import and bounded headless/menu/playground/graphical
startup checks. Main-menu Play was exercised by the graphical survey. Native
edit/save/reload checks retain all nine regions, including an edit beside a join.

Coverage includes all four outer boundaries, lake-plane burial, native region
sizes, join heights/curvature, underwater shelves, connected routes, fifteen
physical collision samples (three at region joins and one at a rocky coast),
two actual twelve-second walks, jumping, lake-islet walking and pause compatibility.
Maximum adjacent height difference is 2.396 m (unchanged limit 2.5 m); maximum
join second difference is 0.153 m. Collision tolerance stays 0.15 m, route grades
32° and gentle-ground grades 20°.

Area thresholds were converted for 768²/1024² and rounded upward: dry 310,000,
gentle 175,000, connected 255,000 and southern elevated gentle land 17,000 m².
Old Task 7.8 bounded-edit/unchanged-height tests do not describe a resized world;
native layout, proportions, seabed and seam checks replace those obsolete claims.
The eastern route landmark follows the actual comfortable approach ten meters
inland; the steep headland itself has a separate collision sample. No physics,
grade, jump or movement tolerances were relaxed.

Six focused views cover the full island, both mountain feet, southern coast,
exposed seabed and a grounded FPS lake-shore pose. Only changed overhead/seabed
areas were recaptured after targeted profile corrections; no further tour or
unrelated inventory/equipment/gathering suite was run. Images are ignored files:
`.godot/island_survey/task80-after/` and final overhead/shelf images in
`.godot/island_survey/task80-detail/`.

Godot AI/MCP confirmed Wildscape 4.7.2 editor access, 256 m / 1 m node settings
and loading of the far `(2,2)` native region after reopening the editor. Normal
editor brush/undo gestures are not exhaustively tested.
The final bounded editor restart exited 0 without logged errors and left all
nine native hashes unchanged. Repeating the adaptation against the compact world
was rejected with the expected guard message and likewise changed no region.

## Rendering diagnosis and remaining limits

Confirmed coastal type-change streaks and eight-direction seabed contours were
corrected in geometry, not hidden by materials. No holes/cracks were detected.
Native mesh size, shadow-disabled, flat-normal, normal-map-depth and ambient-fill
comparisons did not establish a reliable small fix for the remaining dark rock
patches. Flat normals visibly increased faceting. These diagnostic changes were
not saved; shading is not claimed fixed. Native distant LOD and 1 m shoreline
sampling remain visible, particularly in close or high-contrast views.

The native interpolation deprecation warning remains. No renderer/plugin changes,
new art assets, runtime generation, gameplay systems, commits, pushes or merges.
