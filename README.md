# Wildscape

Solo-developed 3D sandbox survival RPG using Godot **4.7.2 stable** and GDScript.
One Godot unit is one meter. Compatibility rendering is the current baseline;
art direction and later gameplay systems remain undecided.

## Open and play

Import `project.godot` into Godot and press F5 for the main menu, then choose Play
to explore `scenes/island/island.tscn`. Open that scene and press F6 for direct
island development. Its saved, editable Terrain3D region is 512 x 512 m, with
roughly 114,000 m² dry land, broad connected lowlands and an off-center lake.
See [island authoring and verification](scenes/island/README.md).

Open `scenes/main.tscn` and press F6 for the original development playground,
including pickup, gathering and equipment fixtures. That scene still composes:

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
theme with a visible keyboard focus marker. The gameplay UI adds no autoloads or
global state managers. The menu changes between Play/Quit and Resume/Main Menu/Quit, and also
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
- A collection area to the right of spawn: three neutral pickups and a finite gathering source.
- Just beyond it, two tool pickups, a primitive tree and rock for tool-gated gathering.

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

## World pickups and finite gathering

`scenes/interaction/world_pickup.tscn` is a reusable World-layer StaticBody3D
with neutral geometry, matching collision and a world-space label. Configure
`item_id` and positive `quantity` in the Inspector. IDs resolve through the
recipient's existing ItemCatalog; no separate pickup catalog or runtime item
definitions are created. Player exposes its owned model through `get_inventory()`.

`world_item_source.gd` implements the existing WorldInteractable contract. The
unchanged player interactor owns E, camera targeting, 2.5 m eye range and wall
checks. A source calls `SlotInventory.add(id, quantity)` once and subtracts only
the returned accepted count. Existing stack space, grid footprints and automatic
rotation use the inventory's existing rules. Partial quantities stay in the world;
a fully collected pickup disables interaction immediately and is queued for
removal. A failed placement leaves both quantities unchanged and adds a short
"No room" message to the existing E prompt. Invalid IDs, nonpositive quantities,
missing/wrong inventories and paused sources reject safely.

The collection lock covers synchronous inventory-change and final interaction
signals. Reentrant callbacks cannot collect the same source again before its
world count is updated, including partial collection. A later interaction may
collect the remainder. Inventory notifications keep their existing semantics:
the inventory is committed when its signal fires; the source's world quantity
is updated when add() returns, before the final interaction signal.

`gathering_source.tscn` inherits the pickup scene and shares all insertion logic.
It sets `remove_when_depleted = false`: one E requests all available units that
fit. At zero it stays collidable, turns gray, reads DEPLETED and rejects further
interaction. This original example remains tool-free and collects all fitting
units per E. The tree/rock examples below add tool requirements and small amounts;
there are no harvesting timers or respawns.

Play/F6, then walk right from spawn toward **PICKUPS / FINITE GATHERING** at
approximately x=6..13.5, z=15. Aim at a light box within reach and press E; Tab
shows the collected stacks. Pickups contain Alpha x17, Beta x6 and Delta x1;
the taller green-gray source supplies Alpha x24. V switches FPS/TPS. The normal
player still starts empty. Re-enter gameplay to restore these test quantities;
R resets the player only. The old switch, beacon and removal-only token are
unchanged. No world dropping, saves, loot tables or Terrain3D test world is added.

## Wood, stone and basic tools

Four neutral definitions extend the player's existing catalog; inventory and
equipment still start empty:

| Stable ID | Name | Grid size | Stack limit | Equipment |
| --- | --- | --- | --- | --- |
| `test_wood` | Wood | 1x2 | 20 | None |
| `test_stone` | Stone | 1x1 | 20 | None |
| `test_axe` | Axe | 1x2 | 1 | Primary or Secondary |
| `test_pickaxe` | Pickaxe | 2x2 | 1 | Primary or Secondary |

`tree_source.tscn` and `rock_source.tscn` reuse WorldItemSource with only primitive
meshes and solid materials. The tree starts with 15 wood and requests 3 per E;
the rock starts with 18 stone and requests 2 per E. `required_tool_id` is checked
against the actor's existing EquipmentInventory via `get_equipment()`, in either
hand slot. A tool in the grid alone does not qualify. The actor and equipment
are rechecked on activation; changing tools after aiming cannot bypass the check.
Tools are never consumed or worn down.

Missing tools leave the source targetable with a Requires equipped Axe/Pickaxe
prompt, but `interact()` refuses all mutations. A positive
`amount_per_interaction` caps the request at min(amount, remaining); zero retains
the Task 5 all-at-once behavior, and negative values reject. Empty
`required_tool_id` retains tool-free pickups. Unknown tool IDs reject safely.
The same add() result, reentrancy lock, pause checks, partial-acceptance and
depletion logic applies; there is no separate harvesting system.

For manual testing, continue past the original pickup row to **WOOD / STONE**:
tools are at approximately (6,12) and (8.5,12), tree at (7.5,9), rock at (10,9)
in x/z meters. Use E on the neutral tool boxes. Open Tab and C together and drag
Axe/Pickaxe to Primary/Secondary. Escape closes the windows. Aim at the tree trunk
or rock within reach, press E repeatedly, and inspect the resulting wood/stone
stacks with Tab. Unequip or use the wrong tool to check rejection. Each press
requests a bounded amount; holding E does not auto-repeat. At zero, the source
stays collidable and reads DEPLETED. No skills, durability, animations, crafting,
saves or resource regeneration are implemented.

## Items and grid inventory

`data/items/item_definition.gd` defines static Godot Resources with a stable
`item_id`, display name, optional description, maximum stack size, optional
Texture2D icon and optional PackedScene world model. No final art is assigned.
The original four neutral resources are Test Alpha (1x1, stack 10), Test Beta (1x2,
stack 5), Test Gamma (2x1, stack 1), and Test Delta (2x3, stack 1).
The four provisional resource/tool definitions above use the same fields and
validation; no tool attributes, icons or final models are added.
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
not finalized equipment types. Axe and Pickaxe also support both hand slots.
Each equipment slot holds exactly one unit.

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
Task 4.4 uses left-aligned title rows with compact close controls, a thin shared
separator and no permanent instruction footer. The 600x600 grid and its drag
targets remain unchanged; the panel reference width is 640. A 40% larger central
silhouette sits between two symmetric columns: Head/Chest/Legs on the left,
Primary/Secondary/Feet on the right. Both use the shared graphite menu theme,
restrained borders/shadows and one dimming layer. Text retains the Task 4.3
small-window readability floor (names 10 px, quantities/slot labels 11 px) and
buttons retain at least 22 px height; the grid is never shrunk for this polish.
The main and pause menus use an open title/action composition with a short rule
instead of a dialog box, subtitles or permanent navigation hints. Their actions
and keyboard navigation are unchanged; hover/focus use a muted accent. Main-menu
type, pause-menu type and action text maintain separate size hierarchies and
minimum readable sizes in small windows.

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
pause menu and preserves all quantities. No world dropping, crafting,
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
runs player, interaction, menu flow, inventory model, grid/equipment, inventory UI
and world collection suites, and
starts both the default main menu and the independent gameplay scene headlessly.
`-Graphical` additionally checks normal fullscreen startup and runs the menu flow
with rendered captures at 1920 x 1080, 1280 x 720, 1024 x 768 and 800 x 600.
Two extra graphical assertions check borderless fullscreen and OS cursor mode. Window sizes
are changed only in the test process; project defaults remain fullscreen. The
graphical inventory suite also captures empty/populated grids up to 1920 x 1080.
The graphical collection suite captures the new playground area, FPS/TPS prompts,
depletion and inventory contents after actual E collection.

Each invocation must exit with code 0, log no Godot script/scene errors, and
(for suites) report a successful assertion count. The runner fails on logged
errors even when Godot exits with 0, on missing result/log files, and on a 60
second per-process timeout. Each GDScript suite also has its own timeout.

The 23 player checks cover spawn, walk/sprint, diagonal speed, stopping, jump,
collisions, slopes/stairs/passages, camera-relative movement, FPS/TPS, camera
collision, input gating and fall recovery. The 26 interaction checks cover sprint
progression, jump travel, range, walls, offset-camera visibility, prompts,
activation signals, held-key behavior, disabled targets and object lifecycles.
The 42 headless menu checks cover startup, navigation, responsive layout, scene
changes, actual Escape/Enter dispatch, pause/resume, player and rigid-body freeze,
camera/input blocking, interactions, focus notifications, returning to main menu,
independent gameplay startup and Quit. The same flow has 44 graphical checks,
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
1920 x 1080, 1280 x 720 and 800 x 600: currently 65 headless / 66 graphical
assertions. Counts and executed results are recorded below.
World collection has 92 checks covering partial/full insertion, footprints and
rotated merges, invalid IDs/quantities/receivers, depletion, signal reentrancy,
180 deterministic conservation steps across two inventories, and actual FPS/TPS
targeting, E dispatch, range, walls, pause, UI ownership and original interactables.
The tool checks cover correct/wrong/carried/unequipped tools in both hand slots,
bounded harvests, last remainders, wood/stone conservation, reentrant callbacks,
invalid requirements, actual tool pickup and drag-to-equip, and FPS/TPS harvesting.

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
There are no animations or packaged-build/export checks yet. Crafting, advanced
equipment effects and other gameplay systems remain unimplemented. World pickups,
finite gathering and basic equipped-tool requirements are implemented as above.

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

Task 4.3 verification on 2026-10-22: Godot 4.7.2 full graphical runner passed
**357 assertion executions**: 23 player, 26 interaction, 39 menu, 49 inventory
model, 60 grid/equipment, 59 inventory UI, plus 41 menu and 60 UI graphical
repeats. Import, bounded headless main-menu/direct-gameplay starts and graphical
startup exited with code 0 and no logged errors. Existing test sources, item and
equipment models, menu/input logic and main/pause theme were left unchanged.
Rendered empty/populated windows at 1920x1080, 1280x720 and 800x600 were visually
inspected; 800x600 Secondary/Gamma labels were given sufficient width after the
first inspection. The grid remains square with single separators. No reference
image was supplied. Physical mouse/keyboard playtesting and unusual DPI/monitor
configurations remain manual follow-ups.

Task 4.4 verification on 2026-10-22: full graphical runner passed **375 assertion
executions** (23 player, 26 interaction, 42 menu, 49 inventory model, 60
grid/equipment, 65 inventory UI, plus graphical repeats of 44 menu and 66 UI).
Import, bounded main-menu/direct-gameplay headless startup and graphical startup
passed with exit 0 and no logged errors. The existing tests were extended with
three pause-layout checks and six independent side-window position checks;
no existing assertions or data-model operations were removed or weakened.

Fifteen rendered views were visually inspected: main menu, pause menu, both side
panels, character alone and inventory alone at 1920x1080, 1280x720 and 800x600.
Captures are in `.godot/main-menu-*.png`, `pause-menu-*.png`,
`inventory-populated-*.png`, `character-only-*.png` and `inventory-only-*.png`.
The first full run exposed a headless minimum-height issue in the empty status
label. Empty status labels now leave the layout; failed-drop messages remain
visible. The complete runner then passed, including the original bounds check.
No connected Godot MCP tools were available. Existing local project/plugin
changes were preserved; no plugins, data-model changes, gameplay systems or final
assets were added. Physical mouse/keyboard feel, real Alt-Tab and unusual DPI or
monitor configurations remain manual checks.

Task 5 verification on 2026-10-22: Godot 4.7.2 full graphical runner passed
**467 assertion executions**: all prior 375 executions plus 46 headless and 46
graphical world-collection checks. Import, bounded headless main-menu and direct
gameplay starts, and graphical startup exited with code 0 and no logged errors.
The seven-suite runner additionally detects logged errors independently of exits.
The new collection checks include partial acceptance, rotated/multi-cell placement,
full/fragmented grids, invalid IDs/quantities/receivers, depletion, held/repeated E,
reentrancy in both inventory and interaction signals, and 180 deterministic mixed
operations checking item conservation. Real camera rays verify FPS/TPS, range,
walls and pause; inventory/UI/menu regressions passed unchanged.

Rendered collection-area overview, FPS/TPS E prompts, depleted resource and the
existing UI containing collected stacks were visually inspected; screenshots are
in `.godot/collection-*.png`. No physical mouse/keyboard playtest was performed.
Resources offer all units that fit per E and do not regenerate; restarting a
gameplay session restores the authored world quantities. No new plugins, UI
redesign, inventory data-model changes, final assets, Terrain3D world, commits,
pushes or merges were introduced. Pre-existing local UI/plugin changes remain.

Task 6 verification on 2026-10-22: Godot 4.7.2 full graphical runner passed
**559 assertion executions**: the unchanged 375 non-collection executions plus
92 headless and 92 graphical world-collection checks. All original Task 5 checks
remain in the suite. Import, bounded headless main-menu/direct-gameplay starts
and graphical startup exited with code 0 and no logged errors. Collection now
also covers both hand slots, incorrect/carried/removed tools, invalid harvest
configuration, limited/partial/full acceptance, automatic wood rotation, finite
remainders, callback reentrancy, actual tool pickups, mouse drag-to-equip and
real FPS/TPS E harvesting. Quantities and reusable tools are conserved.

Rendered primitive resources, missing-tool feedback, equipped tools, wood/stone
prompts, depletion and collected inventory were visually inspected in
`.godot/collection-resources-playground.png`, `collection-tool-required.png`,
`collection-equipped-tools.png`, `collection-wood-prompt.png`,
`collection-stone-prompt.png`, `collection-resources-depleted.png` and
`collection-resource-inventory.png`. Visual inspection caught a tree touching an
old obstacle; only the new tree was moved, and a native overlap check now verifies
both resource colliders. The complete runner passed again after that correction.
No UI redesign, inventory/equipment data-model changes, plugins, tool art,
textures, Terrain3D changes, commits, pushes or merges were introduced. Physical
mouse/keyboard playtesting and export checks remain manual; this is finite,
singleplayer test gathering without regeneration, persistence or durability.
