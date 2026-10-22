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
| E | Interact with the targeted object within reach |
| Escape | Release cursor and disable movement input |
| Left click | Capture cursor and resume controls |
| R | Return to initial spawn and reset view |

Losing application focus releases the cursor. Falling below -12 m returns to
spawn. There is no pause menu; gravity/collisions continue while controls are off.

## Player and camera

The 1.78 m tall placeholder is separate from the 0.6 m wide collision capsule.
Origin is at the feet. Inspector exports on Player adjust speed, acceleration,
air acceleration, jumping, turn speed, mouse sensitivity (radians/pixel), and TPS
distance. Default walk/sprint speeds are 4.5/6.2 m/s. Sprint speed builds at 2 m/s²
while moving, independently of responsive walking acceleration. Holding Shift at
rest does not precharge speed. Jump height is exported as 1.5 m; a 1.4 gravity
multiplier shortens airtime while preserving horizontal momentum and air control.
Jump launch speed is derived from height and current gravity, with discrete-step
compensation for an accurate apex. Mouse input is not multiplied
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
- An interaction test area to the left of spawn: switch, one-shot beacon and test token.

## Interaction foundation

`scenes/interaction/world_interactable.gd` defines a small StaticBody3D contract:
`can_interact(actor)`, `get_prompt()` and `interact(actor)`. Extend it and override
`_on_interact(actor)` for behavior, or override the availability/prompt methods.
The base guards disabled objects and emits `interacted(actor)` after activation.
Keep the body on the World layer, with an actual collision shape; Area3D-only
targets are not supported by this deliberately small contract.

The player's `player_interaction.gd` component selects the first World-layer body
along the camera center ray. The player itself is excluded. A valid interactable
must also be within 2.5 m of the player's eye to the hit surface and pass a second
ray from that eye to the hit. TPS camera distance never increases reach; walls
and ordinary non-interactable objects block selection. These checks are repeated
when E is pressed, so an old prompt cannot authorize an invalid interaction.
The distance and collision mask are exported on Player/Interaction; keep all
world blockers included in that mask. The same targeting runs in FPS and TPS.

A small aim dot and contextual `[E]` prompt form the entire interaction UI.
The prompt clears when looking away, moving out of range, losing sight, releasing
controls, disabling an object, or removing it. Holding E does not repeat actions.

`scenes/playground/interaction_test_object.tscn` supplies three test-only behaviors:
the switch toggles state/color and its prompt, the beacon activates once and then
disables interaction, and the token disappears without creating any item data.
Each object owns its display material. Restart the scene to restore the beacon
and token; R only resets the player. There is no inventory or saved world state.

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
$result = Start-Process -FilePath $godotExe -ArgumentList "$commonArgs --headless --script res://tests/interaction_smoke_test.gd --log-file `"$projectRoot/.godot/interaction-smoke.log`"" -WindowStyle Hidden -Wait -PassThru
$result.ExitCode
Get-Content .godot/interaction-smoke.log
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
The interaction suite adds progressive sprint speed and sprint-jump measurements,
FPS/TPS range and wall checks, an offset-camera corner-peeking check, prompts,
input activation, held-key behavior, disabled targets and test-object lifecycles.

Godot is not on PATH on this machine. Restricted execution can block Godot user
settings and Windows certificate access; use normal OS access for validation.
Generated logs, screenshots and editor caches live in ignored `.godot/`.
Keep generated script `.uid` sidecars in version control. GDScript uses tabs;
`.gitattributes` enforces LF for Godot source and documentation.

Interactive acceptance still requires a person using a mouse and keyboard:
walk/sprint/jump through the zones, orbit close to walls, switch perspectives by
walls and under geometry, and check camera feel at different frame rates.
There are no animations or packaged-build/export checks yet. No inventory,
crafting, gathering or other gameplay systems are implemented.

Verified on 2026-10-22 with Godot 4.7.2: project import, 120-iteration headless
startup, 120-iteration graphical startup, and the physics integration suite all
exited with code 0 and no logged errors. The suite passed 23 checks. TPS, FPS and
overview screenshots were rendered on OpenGL 3.3 / NVIDIA GeForce RTX 5060 Ti;
the captures were visually inspected. Physical mouse/keyboard playtesting and
frame-rate comparisons were not performed.

Task 2 verification on 2026-10-22: 23 controller regressions and 26 movement /
interaction checks passed, all with exit code 0 and no logged errors. Standing
jump peak measured 1.504 m at 60 physics ticks/s; full-sprint jump traveled 5.891 m.
Sprint samples were 4.5 (walk), 4.833, 5.5 and 6.2 m/s. Graphical FPS/TPS prompt
and switch-state captures were rendered successfully and visually inspected.
