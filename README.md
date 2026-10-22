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
| Tab | Open / close inventory (right) |
| C | Open / close character equipment (left) |
| Escape | Close both item windows, or pause / resume gameplay |
| Left mouse drag | Move / merge items or equip / unequip |
| Shift + left mouse drag | Move half a stack, rounded down |
| R | Rotate dragged item; during gameplay return to spawn and reset view |

Menus support mouse clicks and arrow keys / Enter. Pause offers Resume, Main Menu
and Quit. Losing application focus pauses gameplay and releases the cursor;
returning focus keeps the pause menu open until explicitly resumed. Clicking a
menu background never captures the cursor. Falling below -12 m returns to spawn.
Either item window pauses gameplay and releases the mouse. Both can remain open;
closing one keeps gameplay paused until the last closes. Escape closes both
directly into gameplay. They are unavailable from the main menu or pause menu.

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

## Items and grid inventory

`data/items/item_definition.gd` defines static Godot Resources with a stable
`item_id`, display name, optional description, maximum stack size, optional
Texture2D icon and optional PackedScene world model. No final art is assigned.
The four neutral resources are Test Alpha (1x1, stack 10), Test Beta (1x2,
stack 5), Test Gamma (2x1, stack 1), and Test Delta (2x3, stack 1).
`grid_size` stores the static footprint and `equipment_slots` the six-bit
compatibility mask; neither field is mutable inventory state. IDs are explicit lowercase ASCII identifiers beginning
with a letter; limits must be between 1 and 1,000,000 and names nonblank.
Keep IDs stable independently of display names and file renames.

`ItemCatalog` is a locally constructed, validated lookup, not a global manager.
A null/invalid definition or duplicate ID rejects the entire catalog. It takes
snapshots of authoring definitions and returns copies, so callers cannot change
live inventory rules by editing a Resource. Unknown lookups return null/0.

`data/inventory/slot_inventory.gd` is a scene/UI-independent RefCounted model.
The player owns a fresh instance configured by exported `inventory_grid_size`
and item definitions. The default **6x6 grid / 36 cells is always empty** in normal
gameplay. Construct it with `SlotInventory.new(catalog, width, height)`; omitting
both dimensions means 6x6. A former linear capacity N is now explicitly Nx1.
Dimensions are fixed at construction; runtime resizing is not implemented.

Each stack is stored once at its top-left anchor, with ID, quantity and a rotation
flag. `get_stack(anchor)` returns a detached snapshot including its Vector2i
position and rotation. Row-major indices convert through `cell_to_index()` and
`index_to_cell()`. **A null get_stack(cell) does not imply an empty cell:** it may
be covered by another anchor. Use `get_anchor_at(cell)` (-1 means empty).
Occupancy is derived from anchors and footprints; there is no second mutable map
that could become stale. Counts sum anchors once, regardless of occupied area.

| Operation | Result / rules |
| --- | --- |
| `add(id, quantity)` | Actual count accepted; fills existing stacks, then row-major fitting footprints, trying rotated placement if necessary. Caller handles `requested - accepted`. |
| `add_at(id, quantity, cell, rotated = false)` | Actual count accepted at a particular Vector2i anchor; validates the entire footprint or merges at a matching existing anchor. |
| `remove(id, quantity)` | Actual count removed, potentially less than requested; exhausted slots become empty. |
| `move_stack(from, to, quantity = -1, rotate = false)` | Actual count moved/merged; -1 means all. rotate toggles orientation during the move. Different items are rejected, never overwritten/swapped. |
| `split_stack(from, to, quantity)` | Exact split into an empty slot; true on success. Amount must be positive and smaller than the source. |
| `transfer_to(destination, from, to, quantity = -1, rotate = false)` | Actual count transferred; fits the full footprint at a new anchor or partially merges into a matching stack. Remainder stays at source; both owners commit before signals. |
| `rotate_stack(anchor)` | Toggle width/height (0/90 degrees); blocked rotations do nothing. Rectangular 180/270 footprints are equivalent to these two orientations. |
| `get_capacity()`, `count_item(id)`, `get_definition(id)`, `get_catalog()` | Read/query API; catalog can be shared explicitly with another inventory. |

Invalid indices/quantities, unknown IDs, full/incompatible targets and invalid
inventories return 0/false without mutation or change notifications. Transfers
require the same catalog instance, ensuring one authoritative ID/stack definition:
create a compatible inventory with `SlotInventory.new(source.get_catalog(), 4, 2)`.
Successful operations emit `changed` once per affected inventory (only once for
same-inventory moves); no notification is emitted halfway through a transfer.
A full same-grid move may overlap its own previous footprint; partial moves and
splits cannot, because the source still occupies it. Merging retains the target's
orientation and footprint. Removing a stack frees all covered cells.

Shared placement APIs for Task 4.2 are `can_place(id, cell, rotated, ignore_anchor)`,
`find_free_position()`, `find_add_position()`, `get_addable_at()` and
`get_transfer_amount()`. `can_place` checks empty space; get_addable_at also checks
stack merging/limits. Ignore an existing anchor only when previewing that whole
stack moving/rotating. Commit methods perform their own validation. Negative
positions, row wrapping, occupied rectangles and fragmented insufficient space
are rejected even if the total number of unused cells would be large enough.

## Equipment data

Player also owns `data/inventory/equipment_inventory.gd`, using the same catalog.
`ItemDefinition.EquipmentSlot` defines Head, Chest, Legs, Feet, Primary, Secondary
(indices 0..5). Static compatibility flags are data only; neutral Beta supports
Head/Feet, Gamma Primary/Secondary, and Delta Chest/Legs. These are test assignments,
not finalized equipment types. Each equipment slot holds exactly one unit.

`is_compatible()`/`can_equip()` validate placement; `equip_from(grid, anchor, slot)`
takes one quantity from the grid. Occupied/incompatible gear slots reject without
implicitly swapping. `can_unequip_to()`/`unequip_to(grid, slot, to = -1, rotate = false)`
return the item only if a matching stack or the complete footprint can accept it.
-1 chooses a matching stack/free position for the requested orientation; callers
can request rotation when needed. Failed unequip retains the equipped item.
Both data owners are committed before observers run and emit one change each.
Reads return snapshots. All six slots start empty. There is no attribute system,
equipment effects, handedness or backpack behavior.

## Grid inventory and character UI

`scenes/inventory/inventory_view.tscn` observes injected player-owned inventory and
equipment. Its script constructs two anchored PanelContainers with VBox/Margin
layouts: inventory on the right, character on the left. Both retain their positions
when the other closes. A neutral drawn silhouette sits among the six named gear
slots. `inventory_board.gd` only draws: square grid cells share single thin lines,
and each stack occupies one rectangle matching its full footprint. Charcoal panels,
neutral item markers and quantities require no external assets. The 600-unit square
drawing area fits configurable grid dimensions with one shared cell size; the
default 6x6 grid uses 100-unit cells. Both panels fit the 1920x1080 reference and
scale with the existing canvas configuration, including 800x600 windowed mode.

Left-drag to move or merge; Shift-drag takes half, rounded down (minimum one).
R toggles the dragged footprint by 90 degrees. Green/red overlays preview valid
and invalid destinations using the model's placement/transfer/equipment APIs.
Drop onto compatible empty equipment to equip exactly one unit; drag it back to
the grid to unequip, optionally rotated. Occupied gear slots reject; there are no
implicit swaps. Partial merges leave overflow at the source. Source data remains
unchanged throughout a drag; release outside, Escape, window changes and focus
loss cancel safely. A changed source snapshot also rejects stale drops.

Tab/C/Close buttons route through MenuController, which alone controls pause and
mouse capture. Escape closes both windows. Focus loss replaces them with the
pause menu and preserves all quantities. No world dropping, pickups, crafting,
attributes, container UI or persistence are implemented.

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
runs player, interaction, menu flow, inventory model, grid/equipment and inventory UI suites, and
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
mixed operations checking conservation. The same 49 assertions are retained as
explicit Nx1 grids using 1x1 test-definition copies; production footprints are
covered separately. Grid/equipment adds 60 checks across all five requested shapes,
blocked/overlapping placement, rotations, fragmented space, partial transfers,
every equipment slot and 400 deterministic mixed operations with conservation.
Inventory UI covers empty ownership, actual mouse/key dispatch, independent
windows, model binding, multi-cell drag/drop, rotation, partial merges, splitting,
equipment, stale sources, cancellation, focus/pause compatibility and layout at
1920 x 1080, 1280 x 720 and 800 x 600: currently 59 headless / 60 graphical
assertions. Counts and executed results are recorded below.

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
equipment effects, world pickups and other gameplay systems remain unimplemented.

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

Task 4.1 verification on 2026-10-22: full graphical runner passed **303 assertion
executions** (23 player, 26 interaction, 39 menu, 49 legacy inventory model,
60 grid/equipment, 32 inventory UI, plus graphical repeats of 41 menu and 33
inventory UI checks). Import, headless/main-menu/direct-gameplay startup and
graphical startup passed without logged errors. Empty and populated compatibility
UI captures were inspected. The new 400-operation scenario made 64 successful
changes and conserved every item across two grids and equipment.

Outdated tests were adapted explicitly: former capacities N now construct Nx1
grids and legacy definitions are copied as 1x1 fixtures, preserving all original
49 quantity/limit/notification assertions. UI expectations now require 36 cells
and six columns; Alpha move/split targets shifted from cells 5/6 to 6/7 because
Gamma now covers cell 5. Two new UI checks verify initially empty equipment and
covered-cell ownership. Player, interaction and menu test sources are unchanged.
No drag/drop, rotation key or equip buttons were added in Task 4.1; these are now
implemented by Task 4.2 without changes to the inventory/equipment data models.

Task 4.2 verification on 2026-10-22: the full graphical runner passed **355
assertion executions** (23 player, 26 interaction, 39 menu, 49 inventory model,
60 grid/equipment, 58 inventory UI, plus 41 menu and 59 UI graphical repeats).
Import, bounded main-menu/direct-gameplay startup and graphical startup passed
with no logged errors. After the final redundant-window-close pause guard and
drag-label polish, focused reruns passed **39 menu, 59 headless UI and 60 graphical
UI checks**, again with exit 0 and no logged errors. The extra UI assertion
ensures window-close requests cannot silently unpause the pause menu.

Rendered empty/populated windows at 1920x1080, 1280x720 and 800x600 and valid/invalid
drag previews were visually inspected. Two-digit quantities and shared grid lines
were corrected after visual inspection. The old per-cell Button assertions were
replaced with real mouse press/motion/release tests and footprint checks; previous
ownership, move/split/merge, observer, pause, focus and fresh-session coverage is
retained. The five non-UI suite sources and both data models are unchanged.
The graphical tests use synthetic input and focus notifications, not a physical
mouse/keyboard playtest. At 800x600 labels are necessarily small; unusual DPI,
ultrawide/portrait layouts and exports remain unverified. No plugins or dependencies
were added, and no commits, pushes or merges were created.
