# Wildscape

Solo-developed 3D sandbox survival RPG using Godot **4.7.2 stable** and GDScript.
One Godot unit is one meter. Compatibility rendering is the current baseline;
art direction and later gameplay systems remain undecided.

## Open and play

Import `project.godot` into Godot and press F5 for the main menu, then choose Play.
Open `scenes/main.tscn` and press F6 to launch gameplay directly for development.
The gameplay scene composes two independent, reusable scenes:

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
| I | Open / close inventory |
| Escape | Pause / resume gameplay |
| R | Return to initial spawn and reset view |

Menus support mouse clicks and arrow keys / Enter. Pause offers Resume, Main Menu
and Quit. Losing application focus pauses gameplay and releases the cursor;
returning focus keeps the pause menu open until explicitly resumed. Clicking a
menu background never captures the cursor. Falling below -12 m returns to spawn.
While inventory is open, Escape closes it directly into gameplay. The inventory
is unavailable from the main menu or pause menu.

## Menu ownership, pause and display

`scenes/menus/main_menu.tscn` is the startup scene. It and gameplay each instance
`game_menu.tscn`, whose scene-local `menu_controller.gd` owns scene transitions,
Escape, pause, focus loss and OS mouse capture. `menu_theme.tres` is a small shared
theme with a visible keyboard focus border. There are no autoloads or global state
managers. The menu changes between Play/Quit and Resume/Main Menu/Quit, and also
hosts the inventory view. It owns all inventory mouse/pause transitions.

The gameplay root explicitly uses Pausable; player, camera and interactions
inherit it. Only the menu CanvasLayer uses Always, so it remains operable while
the SceneTree and physics servers are paused. Keep gameplay outside that subtree.
Pause disables player input and immediately clears interaction prompts. Returning
to the main menu clears the paused state and removes the gameplay scene; Play
creates a fresh session. No world state is saved.

The existing player `set_mouse_captured()` method is retained as the input gate
used by tests/controller, but no longer modifies the OS cursor. The controller
enables gameplay input after the menu activation tick has passed, preventing
Space/E used in menus from leaking into jumping/interactions on resume.

Display uses a 1920 x 1080 UI reference, `canvas_items` scaling with aspect
`expand`, and Containers/anchors. Borderless fullscreen (mode 3) follows the
monitor's desktop size; it does not request an exclusive display-mode switch.
Windowed overrides are 1280 x 720 for development/testing. There is no settings
menu or persistent display configuration.

The 3D backend is unchanged: `physics/3d/physics_engine` is `DEFAULT`, which
resolves to **GodotPhysics3D**; it is not an explicit Jolt configuration. The value
was inspected in the running Godot 4.7.2 build; resolution of DEFAULT follows the
[Godot ProjectSettings reference](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-physics-3d-physics-engine).

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
and token; R only resets the player. The test token does not add inventory items.
Neither object states nor inventory contents are saved.

## Items and slot inventory

`data/items/item_definition.gd` defines static Godot Resources with a stable
`item_id`, display name, optional description, maximum stack size, optional
Texture2D icon and optional PackedScene world model. No final art is assigned.
The three neutral resources are Test Alpha (stack 10), Test Beta (stack 5), and
Test Gamma (stack 1). IDs are explicit lowercase ASCII identifiers beginning
with a letter; limits must be between 1 and 1,000,000 and names nonblank.
Keep IDs stable independently of display names and file renames.

`ItemCatalog` is a locally constructed, validated lookup, not a global manager.
A null/invalid definition or duplicate ID rejects the entire catalog. It takes
snapshots of authoring definitions and returns copies, so callers cannot change
live inventory rules by editing a Resource. Unknown lookups return null/0.

`data/inventory/slot_inventory.gd` is a scene/UI-independent RefCounted model.
The player owns a fresh instance, configured by exported capacity and item
definitions. Its default 20 slots are always empty in normal gameplay. Slots are
null or internal InventoryStack objects containing only an ID and quantity.
`get_stack()` returns a detached snapshot, never a writable live stack.

| Operation | Result / rules |
| --- | --- |
| `add(id, quantity)` | Actual count accepted; existing stacks fill first, then empty slots. Caller retains responsibility for `requested - accepted`. |
| `remove(id, quantity)` | Actual count removed, potentially less than requested; exhausted slots become empty. |
| `move_stack(from, to, quantity = -1)` | Actual count moved/merged; -1 means all available. Different target items are rejected, never overwritten or swapped. |
| `split_stack(from, to, quantity)` | Exact split into an empty slot; true on success. Amount must be positive and smaller than the source. |
| `transfer_to(destination, from, to, quantity = -1)` | Actual count transferred; destination capacity limits the amount, remainder stays at source. Both sides commit before signals. |
| `get_capacity()`, `count_item(id)`, `get_definition(id)`, `get_catalog()` | Read/query API; catalog can be shared explicitly with another inventory. |

Invalid indices/quantities, unknown IDs, full/incompatible targets and invalid
inventories return 0/false without mutation or change notifications. Transfers
require the same catalog instance, ensuring one authoritative ID/stack definition:
create a compatible inventory with `SlotInventory.new(source.get_catalog(), 8)`.
Successful operations emit `changed` once per affected inventory (only once for
same-inventory moves); no notification is emitted halfway through a transfer.
Capacity is chosen at construction; runtime resizing is not implemented.

`scenes/inventory/inventory_view.tscn` observes and requests operations without
owning item data. I opens the five-column grid and releases the cursor; gameplay,
physics and E interactions pause. I, Escape or Close resumes through the existing
controller. Click a stack then an empty/matching slot to move or merge it.
Split Half followed by an empty slot creates a separate half stack (rounded down).
Selecting the same slot or Deselect cancels selection. Focus loss replaces the
inventory with the pause menu and preserves quantities. No drag-and-drop,
equipment, dropping, world pickups or persistence are implemented.

For populated examples, open **`tests/fixtures/inventory_demo.tscn` with F6**.
Only this isolated fixture seeds 17 Alpha, 6 Beta and 1 Gamma and opens inventory.
Its script is not referenced by production scenes. R does not reset quantities;
restart the fixture to restore its example contents.

## Validation

The reusable PowerShell runner needs only Godot, with no external framework:

```powershell
./tests/run_tests.ps1 -GodotPath 'C:\Users\scami\Downloads\Godot_v4.7.2-stable_win64.exe'
# Also test the real graphics driver, fullscreen and capture menu layouts:
./tests/run_tests.ps1 -GodotPath 'C:\Users\scami\Downloads\Godot_v4.7.2-stable_win64.exe' -Graphical
```

If Godot is on PATH, `-GodotPath` can be omitted. The runner imports the project,
runs player, interaction, menu flow, inventory model and inventory UI suites, and
starts both the default main menu and the independent gameplay scene headlessly.
`-Graphical` additionally checks normal fullscreen startup and runs the menu flow
with rendered captures at 1920 x 1080, 1280 x 720, 1024 x 768 and 800 x 600.
Two extra graphical assertions check borderless fullscreen and OS cursor mode. Window sizes
are changed only in the test process; project defaults remain fullscreen. The
graphical inventory suite also captures empty/populated grids up to 1920 x 1080.

Each invocation must exit with code 0, log no Godot script/scene errors, and
(for suites) report a successful assertion count. The runner fails on logged
errors even when Godot exits with 0, on missing result/log files, and on a 60
second per-process timeout. Each GDScript suite also has its own timeout.

The 23 player checks cover spawn, walk/sprint, diagonal speed, stopping, jump,
collisions, slopes/stairs/passages, camera-relative movement, FPS/TPS, camera
collision, input gating and fall recovery. The 26 interaction checks cover sprint
progression, jump travel, range, walls, offset-camera visibility, prompts,
activation signals, held-key behavior, disabled targets and object lifecycles.
The 39 headless menu checks cover startup, navigation, responsive layout, scene
changes, actual Escape/Enter dispatch, pause/resume, player and rigid-body freeze,
camera/input blocking, interactions, focus notifications, returning to main menu,
independent gameplay startup and Quit. The same flow has 41 graphical checks,
including borderless fullscreen and actual OS mouse capture.
Inventory adds 49 pure model checks, including ID validation, invalid operations,
stack limits, overflow, partial transfers, notifications and 250 deterministic
mixed operations checking conservation. Inventory UI adds 30 headless checks
(31 graphical) for empty ownership, controls, model binding, slot operations,
focus/pause compatibility and layout at 1920 x 1080, 1280 x 720 and 800 x 600.

Headless drivers cannot capture a physical cursor; regression tests use the
player input gate separately from OS cursor state. Restricted execution may block
Godot user settings and Windows certificate access; run with normal OS access.
Logs and generated UI screenshots are in ignored `.godot/`. Keep generated `.uid`
sidecars versioned. GDScript uses tabs and LF as specified in `.gitattributes`.

Interactive acceptance still requires a person using a mouse and keyboard:
walk/sprint/jump through the zones, orbit close to walls, switch perspectives by
walls and under geometry, check camera feel at different frame rates, and try
real Alt-Tab/focus changes and menu navigation. Automated focus checks simulate
Godot focus notifications; they do not constitute a physical Alt-Tab playtest.
There are no animations or packaged-build/export checks yet. Crafting, gathering,
equipment, world pickups and other gameplay systems remain unimplemented.

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

Task 3 verification on 2026-10-22: the unchanged existing suites still report
23 + 26 = 49 checks. Menu flow adds 39 headless checks and repeats them with two
additional graphical checks (41), giving 129 assertion executions in the full
graphical runner. All passed with no logged errors. Import, main-menu startup,
independent gameplay startup and normal graphical startup also passed. Main and
pause menu captures were visually inspected at the tested sizes; fullscreen was
1920 x 1080 on the 1920 x 1080 monitor. No physics-backend change was made.

Task 4 verification on 2026-10-22: all previous suites passed unchanged (23 player,
26 interaction, 39 headless menu / 41 graphical menu). New suites passed 49 model
checks and 30 headless / 31 graphical inventory UI checks: **239 total assertion
executions** with the graphical runner, without logged errors. Import and normal
startup checks passed. Empty and populated inventory captures were visually
inspected. Real mouse/keyboard playtesting, unusual DPI/monitor setups and export
validation remain manual follow-ups; no save/load behavior is claimed.
