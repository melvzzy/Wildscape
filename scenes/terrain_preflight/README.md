# Terrain3D preflight (2026-10-22)

Open `terrain_preflight.tscn` and run F6. F5 and the original playground are
unchanged. This is an isolated compatibility fixture, not the future world.

## Configuration and workflow

- Installed/enabled Terrain3D **1.0.2**, native Windows x86_64 debug DLL;
  GDExtension minimum Godot 4.4. Tested with Godot **4.7.2 stable**.
- Project renderer remains **gl_compatibility**. Graphical runs used OpenGL 3.3
  on NVIDIA GeForce RTX 5060 Ti (driver 616.92). No renderer/plugin changes.
- One region at `(0, 0)`, `region_size = 128`, `vertex_spacing = 1.0`:
  nominal 128 x 128 m, X/Z 0 through 128, samples 0 through 127.
  Player starts at `(64, 1, 88)`; a gentle 2 m rise is centered at `(64, 64)`.
- Height data was imported as a **128 x 128 Image.FORMAT_RF** image, with
  heights in meters and import offset 0 / scale 1, through native
  `Terrain3DData.import_images([height, null, null], Vector3.ZERO, 0, 1)`.
  For external maps, prefer 16/32-bit EXR or R16, not 8-bit grayscale.
  Normalized heights require the intended vertical scale on import.
- `data/terrain3d_00_00.res` is the native editable region, saved with
  `Terrain3DData.save_directory()`. Keep the data directory with the scene.
  Select Terrain3D to sculpt in the editor, then save. Do not regenerate the
  region during startup. There is no generator or custom terrain mesh.
- Neutral native grey material; no texture assets. The empty `assets.tres` is
  deliberately external: this plugin version tries to reload the asset resource
  by its file path, and an embedded/unsaved asset list produced load errors.
- Native dynamic/game terrain collision, World layer 1, mask Player layer 2;
  existing GodotPhysics3D backend retained. Reuses the existing player and menu.
  Outside the single region there is no ground or boundary barrier.

## Executed verification

- Existing `tests/run_tests.ps1 -GodotPath <exe>`: all **357 assertions** across
  seven suites passed; import and bounded main-menu/gameplay startups logged no
  errors. No existing test was changed.
- `--headless --script res://tests/terrain_preflight_test.gd`: **11 checks** passed.
- Graphical `--script res://tests/terrain_preflight_test.gd -- --capture-terrain`:
  **12 checks** passed. Final logs contain no errors. Tests cover native version,
  region size/count, persisted heights, World-layer ray collision, player landing,
  simulated uphill movement and jumping, native edit/save/resource reload into
  `.godot/terrain_preflight_roundtrip`, and a fresh original scene instance.
- Direct graphical scene startup (120 iterations) passed without logged errors.
  `.godot/terrain-preflight.png` was actually inspected: neutral region renders,
  player and shadow visible. It is an overview captured by a test-only camera.
- Normal graphical editor startup opened the scene without logged errors.
  A separate editor script also read the saved region, changed one height, saved
  to `.godot/terrain_editor_roundtrip`, and reloaded the changed value successfully.
  **That scripted editor invocation was not error-free**: two Godot editor
  `progress_dialog.cpp` / `current_window is null` errors appeared, plus a scan
  aborted warning at shutdown. These did not occur in normal editor startup or
  game runs; their underlying cause has not been established.

All logs, screenshots and scratch regions are ignored under `.godot/`.
The terrain test is an explicit additional check, not part of the seven-suite
runner. Its expected fixture heights should change only if the fixture changes.

## Limits and next step

Terrain3D emits the Godot 4.7 deprecation warning
`instance_reset_physics_interpolation() is deprecated`. The installed Godot AI
editor plugin reports no server command; no MCP tools were available and nothing
was installed. No Terrain3D loading, shader or collision error remains in the
final runtime checks. This validates this Windows/GPU configuration, not every
GPU, export target or future Godot release.

Physical keyboard/mouse walking and actual editor brush/undo gestures remain
manual. Before building the full landscape, open this scene, sculpt a small spot,
save/reopen it and walk over it in FPS/TPS. The native data/editor roundtrip is
verified programmatically; interactive brush ergonomics are not. No terrain
blocker was found requiring a renderer switch. Retain one 128-region at 1 m
spacing for the next 128 x 128 m test landscape; plan edge handling separately.

Version-pinned upstream references:

- [1.0.2 release and Godot requirements](https://github.com/TokisanGames/Terrain3D/releases/tag/v1.0.2-stable)
- [Renderer support](https://github.com/TokisanGames/Terrain3D/blob/v1.0.2-stable/doc/docs/platforms.md)
- [Heightmap formats and scaling](https://github.com/TokisanGames/Terrain3D/blob/v1.0.2-stable/doc/docs/heightmaps.md)
- [Native region sizes](https://github.com/TokisanGames/Terrain3D/blob/v1.0.2-stable/src/terrain_3d.h)
