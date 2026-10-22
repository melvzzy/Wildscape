# Wildscape

Solo-developed 3D sandbox survival RPG using Godot **4.7.2 stable** and GDScript.
One Godot unit is one meter. Compatibility rendering is the current baseline;
art direction and later gameplay systems remain undecided.

## Open and play

Import `project.godot` into Godot and press F5. The main scene composes two
independent, reusable scenes:

- `scenes/player/player.tscn` and `player.gd`: CharacterBody3D controller, capsule,
  replaceable Visuals subtree, and FPS/TPS camera rig.
- `scenes/playground/playground.tscn`: editable native geometry, matching static
  colliders, lighting, materials and world-space labels. No runtime level generator.

| Control | Action |
| --- | --- |
| WASD | Camera-relative movement (physical key positions) |
| Shift | Sprint |
| Space | Jump while grounded |
| Mouse | Look / orbit |
| V | Switch TPS / FPS |
| Escape | Release cursor and disable movement input |
| Left click | Capture cursor and resume controls |
| R | Return to initial spawn and reset view |

Losing application focus releases the cursor. Falling below -12 m returns to
spawn. There is no pause menu; gravity/collisions continue while controls are off.

## Player and camera

The 1.78 m tall placeholder is separate from the 0.6 m wide collision capsule.
Origin is at the feet. Inspector exports on Player adjust speed, acceleration,
air acceleration, jumping, turn speed, mouse sensitivity (radians/pixel), and TPS
distance. Default walk/sprint speeds are 4.5/7 m/s. Mouse input is not multiplied
by frame delta. The model turns toward travel in TPS; the camera can orbit freely
while idle. FPS hides the complete model and uses the same locomotion.

Floor snapping and constant ground speed support ramps up to 45 degrees.
Steeper slopes block ascent. Steps are deliberate jump obstacles: there is no
automatic step-up, crouching, jump buffering or coyote time in this version.

Physics interpolation smooths the body. The independent camera pivot follows its
interpolated position at render time, keeping mouse-look immediate. A native
SpringArm3D with a 0.18 m sphere and margin retracts the TPS camera at walls; the
player is excluded from its collision checks. FPS places the camera at 1.62 m
inside the capsule footprint with a 0.05 m near plane. Physics layers: 1 = World,
2 = Player. See the [Godot spring arm documentation](https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html).

## Playground

The bounded 48 x 48 m playground contains:

- Flat spawn and a marked, empty 7 x 7 m area for later tests.
- 15, 30 and 50 degree ramps with elevated landings.
- Eight 0.18 m stair risers and a neighboring access ramp.
- Jump platforms at 0.35, 0.65, 1.0, 1.5 and 1.8 m.
- Obstacles, a low beam, 0.8/1.2 m passages, and a tall camera collision wall.
- 1.0, 1.78 and 3.0 m scale references, color-coded geometry and labels.

## Validation

No external framework or plugin is needed. From the repository root in PowerShell:

```powershell
$godotExe = 'C:\Users\scami\Downloads\Godot_v4.7.2-stable_win64.exe'
$projectRoot = (Get-Location).Path
New-Item -ItemType Directory -Force -Path .godot | Out-Null
$commonArgs = "--path `"$projectRoot`""
$result = Start-Process -FilePath $godotExe -ArgumentList "$commonArgs --headless --import --log-file `"$projectRoot/.godot/import.log`"" -WindowStyle Hidden -Wait -PassThru
$result.ExitCode
Get-Content .godot/import.log
$result = Start-Process -FilePath $godotExe -ArgumentList "$commonArgs --headless --script res://tests/player_smoke_test.gd --log-file `"$projectRoot/.godot/smoke.log`"" -WindowStyle Hidden -Wait -PassThru
$result.ExitCode
Get-Content .godot/smoke.log
$result = Start-Process -FilePath $godotExe -ArgumentList "$commonArgs --headless --quit-after 120 --log-file `"$projectRoot/.godot/startup-headless.log`"" -WindowStyle Hidden -Wait -PassThru
$result.ExitCode
Get-Content .godot/startup-headless.log
$result = Start-Process -FilePath $godotExe -ArgumentList "$commonArgs --quit-after 120 --log-file `"$projectRoot/.godot/startup-graphics.log`"" -WindowStyle Hidden -Wait -PassThru
$result.ExitCode
Get-Content .godot/startup-graphics.log
```

Expect exit code 0 and no script/scene errors in each log. The integration test
simulates actions against actual Godot physics: spawn, acceleration, sprint,
normalized diagonal speed, stopping, jumping/landing, walls, slopes, stairs,
narrow passage, camera-relative movement, FPS/TPS switching, look limits, camera
wall retraction/recovery, released controls and fall recovery. It has a 40 second
timeout. Headless drivers cannot capture a physical cursor; the test exercises
the controller's capture intent separately from OS cursor state.

Godot is not on PATH on this machine. Restricted execution can block Godot user
settings and Windows certificate access; use normal OS access for validation.
Generated logs, screenshots and editor caches live in ignored `.godot/`.
Keep generated script `.uid` sidecars in version control. GDScript uses tabs;
`.gitattributes` enforces LF for Godot source and documentation.

Interactive acceptance still requires a person using a mouse and keyboard:
walk/sprint/jump through the zones, orbit close to walls, switch perspectives by
walls and under geometry, and check camera feel at different frame rates.
There are no animations or packaged-build/export checks yet. No other gameplay
systems are implemented.

Verified on 2026-10-22 with Godot 4.7.2: project import, 120-iteration headless
startup, 120-iteration graphical startup, and the physics integration suite all
exited with code 0 and no logged errors. The suite passed 23 checks. TPS, FPS and
overview screenshots were rendered on OpenGL 3.3 / NVIDIA GeForce RTX 5060 Ti;
the captures were visually inspected. Physical mouse/keyboard playtesting and
frame-rate comparisons were not performed.
