# First island

Godot 4.7.2, Terrain3D 1.0.2, unchanged Compatibility renderer and
GodotPhysics3D. Main menu **Play** opens `island.tscn`; F6 runs it directly.
The original playground remains `res://scenes/main.tscn` (F6), and the separate
Terrain3D preflight scene remains unchanged.

## Terrain and ownership

One native **256 x 256 sample region**, 1 m vertex spacing, at region `(0, 0)`.
Its 256 x 256 m footprint includes shallow seabed around roughly 200 m of dry
island. The saved elevation range is approximately -7 to 42 m, sea level 0 m.
The asymmetrical coastline surrounds two elevated areas, a broken northern
impact rim and broad central valley, opening south. The south-west shelf is
deliberately gentler for exploration and future building. No central lake yet.

`data/terrain3d_00_00.res` owns native height, control and color maps, not a mesh.
`assets.tres` references three basic solid grass/earth/stone colors and a shared
flat normal. Tiny 8 x 8 ImageTexture resources have no detailed surface art.
Native material controls blend earth near the coast and stone on steep/high
terrain. Directional light, procedural sky and basic distance fog provide the
atmosphere. `Sea` is a single opaque plane, without a collider or water script.

The existing player, camera rig and menu are instanced without gameplay changes.
Player inventory remains empty. World collision stays on layer 1, mask Player 2.
Native dynamic collision follows the active camera (64 m radius); distant terrain
does not have to generate physics until approached. `free_editor_textures=false`
keeps the tiny texture definitions available for inspection during play.

## Editing

1. Open `island.tscn`, select **Terrain3D**, use the plugin's sculpt/paint tools.
   Terrain transform is intentionally locked by the plugin; edit its region data.
2. Save the scene/terrain in Godot and retain the entire `data/` directory.
   Reopen the scene and run F6 to verify collision after sculpting.
3. Keep the spawn around `(128, 6.15, 180)` just above dry ground if changing
   the southern valley. **R** uses the existing return-to-spawn control.

`tools/build_island.gd` is the one-time deterministic authoring source, seed 71043.
It is not attached to the scene, called by tests, or run during gameplay.
**Rebuilding replaces hand-sculpted heights and paint**; intentionally invoke only:

```powershell
& '<Godot executable>' --headless --path . --script res://tools/build_island.gd -- --write-island
```

The explicit flag is required. To continue ordinary editing, just use the saved
region; do not rebuild. No runtime generation, streaming or terrain framework.

## Verification

Run `tests/run_tests.ps1 -GodotPath '<exe>' -Graphical`. It now includes eight
suites, including `island_test.gd`, and scans logs for errors even with exit 0.
The previous menu-flow test now checks Play's island destination, relative
movement and a fresh island session; its original switch/interaction/pause
assertions still run against the explicitly opened playground fixture.

Island checks cover saved data/material loading, dry spawn, camera-following
collision at the valley, shelf and both elevated areas, a 12-second walk into
the central valley, jumping, inventory/character pause integration, and a native
height edit/save/reload roundtrip in ignored `.godot/island_roundtrip/` copies.
The original map is reloaded afterwards; tests never regenerate or save it.

Graphical captures are `.godot/island-ground-tps.png`, `island-ground-fps.png`,
`island-overview.png` and `island-top.png`. The elevated cameras are test-only.
MCP also opened/inspected/saved/reloaded the native scene and launched it in the
connected editor; live game inspection confirmed the player standing on terrain.
Editor terrain auto-framing reports a fallback AABB at origin, so runtime
captures are the meaningful visual reference, rather than MCP's automatic frame.
Actual editor brush gestures and physical keyboard/mouse feel remain manual.

Final run on 2026-10-22: **591 assertion executions passed** (371 headless,
220 graphical). Import, main-menu and playground startup checks logged no
errors. Island contributed 14 headless and 18 graphical checks. Ground-level,
overview and top-down renders were inspected, plus an actual MCP live-game TPS
capture; the live player stood at `(128, 6.0995, 180)` on the native collider.

## Current limits

No swimming, drowning, water boundary or island gameplay objects have been added.
The sea is visual: the player can walk below it onto seabed and eventually beyond
the finite terrain. Use R to return. The existing below--12 m fall reset remains.
The island is an editable foundation; texture transitions and coastline are still
simple at 1 m resolution. No vegetation, detailed art, persistence, respawns or
production water. Terrain3D's existing Godot 4.7 interpolation deprecation warning
remains; the renderer and native plugin were not changed.
