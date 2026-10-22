extends SceneTree
## Real input routing, menu integration and isolated populated fixture. These
## assertions replace the obsolete one-Button-per-cell implementation checks.

var checks: int = 0
var failures: int = 0
var elapsed: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 50.0:
		push_error("FAIL: inventory UI timeout")
		quit(1)
	return false


func _frames(count: int = 5) -> void:
	for frame in range(count):
		await physics_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _key(key: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await _frames()


func _mouse(point: Vector2, pressed: bool, half: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.shift_pressed = half
	root.push_input(event, true)


func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	root.push_input(event, true)


func _cell(view: Control, index: int) -> Vector2:
	return view.grid.global_position + (Vector2(view._inventory.index_to_cell(index)) + Vector2(0.5, 0.5)) * view.cell_size()


func _gear(view: Control, index: int) -> Vector2:
	return view.character_board.global_position + view.equipment_rect(index).get_center()


func _drag(view: Control, from: int, to: int, half: bool = false) -> void:
	_mouse(_cell(view, from), true, half)
	_motion(_cell(view, to))
	_mouse(_cell(view, to), false)
	await _frames()


func _capture(name: String) -> void:
	if "--capture-ui" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + name + ".png")


func _run() -> void:
	change_scene_to_file("res://scenes/menus/main_menu.tscn")
	await _frames(12)
	root.mode = Window.MODE_WINDOWED
	var menu: Node = current_scene.get_node("Menu")
	await _key(KEY_TAB)
	await _key(KEY_C)
	_check(not menu.inventory_view.visible and not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Tab and C do nothing in the main menu")
	menu.primary_button.pressed.emit()
	await _frames(12)
	menu = current_scene.get_node("Menu")
	var player: CharacterBody3D = current_scene.get_node("Player")
	var inventory: SlotInventory = player.inventory
	var view: Control = menu.inventory_view
	var empty := true
	for index in range(inventory.get_capacity()):
		empty = empty and inventory.get_stack(index) == null
	_check(inventory.get_grid_size() == Vector2i(6, 6) and empty, "normal player owns an empty 6x6 grid with no automatic items")
	var gear_empty := true
	for slot in range(6):
		gear_empty = gear_empty and player.equipment.get_stack(slot) == null
	_check(gear_empty, "player owns six initially empty equipment slots")
	await _key(KEY_TAB)
	_check(paused and view.inventory_panel.visible and not view.character_panel.visible and not menu.overlay.visible and not player.controls_active, "Tab opens only inventory and suspends gameplay")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not player.get_node("Interaction").prompt.visible, "inventory releases mouse and hides interaction HUD")
	_check(root.gui_get_focus_owner() == view.close_button, "inventory has a keyboard-accessible Close button")
	await _capture("inventory-empty")
	var position := player.position
	var yaw: float = player.camera_yaw.rotation.y
	var fps: bool = player.first_person
	Input.action_press("move_forward")
	Input.action_press("jump")
	Input.action_press("interact")
	var look := InputEventMouseMotion.new()
	look.screen_relative = Vector2(100, 80)
	root.push_input(look)
	await _key(KEY_V)
	player.get_node("Interaction").try_interact()
	await _frames()
	_check(player.position.is_equal_approx(position) and is_equal_approx(player.camera_yaw.rotation.y, yaw) and player.first_person == fps and player.get_node("Interaction").target == null, "UI blocks movement, jumping, look, camera toggle and E")
	for action in ["move_forward", "jump", "interact"]:
		Input.action_release(action)
	_mouse(Vector2(5, 5), true)
	_mouse(Vector2(5, 5), false)
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not player.controls_active, "background click cannot capture the mouse")
	await _key(KEY_TAB, true)
	_check(view.visible and paused, "key echoes cannot repeatedly toggle windows")
	var right_position: Vector2 = view.inventory_panel.position
	await _key(KEY_C)
	_check(view.character_panel.visible and view.inventory_panel.visible and paused and view.inventory_panel.position == right_position, "both windows open independently without shifting the inventory")
	await _key(KEY_TAB)
	_check(not view.inventory_panel.visible and view.character_panel.visible and paused and not player.controls_active, "closing inventory keeps character open and gameplay paused")
	await _key(KEY_C)
	_check(not view.visible and not paused and player.controls_active, "closing last window resumes gameplay")
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "last window restores graphical mouse capture")
	await _key(KEY_C)
	_check(view.character_panel.visible and not view.inventory_panel.visible and paused, "C opens character independently from gameplay")
	await _key(KEY_TAB)
	await _key(KEY_ESCAPE)
	_check(not paused and not view.visible and not menu.overlay.visible and player.inventory == inventory, "Escape closes both windows into gameplay and preserves model ownership")
	await _key(KEY_ESCAPE)
	await _key(KEY_TAB)
	await _key(KEY_C)
	_check(paused and menu.overlay.visible and not view.visible, "neither window bypasses the pause menu")
	menu.set_inventory_open(false)
	menu.set_character_open(false)
	_check(paused and menu.overlay.visible and not player.controls_active, "redundant window close requests cannot unpause the pause menu")
	menu.primary_button.pressed.emit()
	await _frames()
	change_scene_to_file("res://tests/fixtures/inventory_demo.tscn")
	await _frames(12)
	var game: Node = current_scene.get_node("Gameplay")
	player = game.get_node("Player")
	menu = game.get_node("Menu")
	view = menu.inventory_view
	var model: SlotInventory = player.inventory
	var equipment: EquipmentInventory = player.equipment
	_check(paused and model.count_item(&"test_alpha") == 17 and model.count_item(&"test_beta") == 6 and model.count_item(&"test_gamma") == 1, "only isolated fixture starts populated")
	_check(inventory.count_item(&"test_alpha") == 0 and model != inventory, "fixture inventory is isolated from normal game data")
	_check(view._inventory == model and view._equipment == equipment, "UI observes the player's existing inventory and equipment")
	_mouse(_cell(view, 8), true)
	_check(view._selected == 2 and model.get_stack(8) == null and model.count_item(&"test_beta") == 6, "covered-cell press resolves to owning multi-cell stack without changing data")
	_mouse(Vector2(5, 5), false)
	_check(view._drag.is_empty() and model.get_stack(2).quantity == 5, "release outside cancels without rollback or item loss")
	await _drag(view, 8, 14)
	_check(model.get_stack(8) != null and model.get_anchor_at(14) == 8 and model.get_stack(2) == null, "grabbing a covered cell preserves its offset when moving the multi-cell footprint")
	await _drag(view, 14, 8)
	_check(model.get_stack(2) != null and model.get_anchor_at(8) == 2, "covered-cell reverse move restores original footprint without duplication")
	await _drag(view, 1, 6)
	_check(model.get_stack(1) == null and model.get_stack(6) != null and model.get_stack(6).quantity == 7, "real mouse drag moves a stack and observes model notification")
	await _drag(view, 6, 7, true)
	_check(model.get_stack(6).quantity == 4 and model.get_stack(7).quantity == 3 and model.count_item(&"test_alpha") == 17, "Shift-drag splits half, rounding down and conserving items")
	await _drag(view, 7, 6)
	_check(model.get_stack(7) == null and model.get_stack(6).quantity == 7, "drag merges matching stacks")
	await _drag(view, 6, 0)
	_check(model.get_stack(6).quantity == 7 and "No change" in view.status.text, "full stack drop rejects without changes")
	await _drag(view, 6, 2)
	_check(model.get_stack(2).item_id == &"test_beta" and model.count_item(&"test_alpha") == 17, "drop cannot overwrite another item type")
	model.remove_from_slot(0, 2)
	await _drag(view, 6, 0)
	_check(model.get_stack(0).quantity == 10 and model.get_stack(6).quantity == 5, "partial merge leaves overflow safely in source")
	_mouse(_cell(view, 4), true)
	_motion(_cell(view, 10))
	await _key(KEY_R)
	_check(view._drag.rotate and model.get_stack(4) != null and not model.get_stack(4).rotated and view.can_drop("grid", 10), "R changes only preview rotation and uses model placement validation")
	await _capture("inventory-drag-valid")
	_mouse(_cell(view, 10), false)
	_check(model.get_stack(10).rotated and model.get_anchor_at(16) == 10 and model.get_stack(4) == null, "rotated drop commits a genuine 1x2 footprint")
	_mouse(_cell(view, 10), true)
	_motion(_cell(view, 35))
	_check(not view.can_drop("grid", 35), "out-of-bounds multi-cell placement previews invalid")
	await _capture("inventory-drag-invalid")
	_mouse(_cell(view, 35), false)
	_check(model.get_stack(10) != null and model.count_item(&"test_gamma") == 1, "invalid rotated placement preserves source")
	_mouse(_cell(view, 10), true)
	await _key(KEY_R)
	_mouse(_cell(view, 10), false)
	_check(not model.get_stack(10).rotated and model.get_anchor_at(11) == 10, "rotation in place delegates to existing rotate_stack operation")
	view.begin_drag("grid", 6)
	model.remove_from_slot(6, 1)
	_check(not view.can_drop("grid", 12) and not view.commit_drop("grid", 12) and model.get_stack(6).quantity == 4, "stale drag snapshot rejects changed source without modifying it")
	menu.set_character_open(true)
	await _frames()
	_mouse(_cell(view, 2), true)
	_motion(_gear(view, 1))
	_check(not view.can_drop("equipment", 1), "equipment incompatibility comes from model validator")
	_mouse(_gear(view, 1), false)
	_check(equipment.get_stack(1) == null and model.count_item(&"test_beta") == 6, "invalid equipment drop conserves all items")
	_mouse(_cell(view, 2), true)
	_motion(_gear(view, 0))
	_check(view.can_drop("equipment", 0), "compatible head slot previews valid")
	_mouse(_gear(view, 0), false)
	_check(equipment.get_stack(0).item_id == &"test_beta" and model.count_item(&"test_beta") == 5, "equipping consumes exactly one unit through equipment model")
	_mouse(_gear(view, 0), true)
	_motion(_cell(view, 0))
	_mouse(_cell(view, 0), false)
	_check(equipment.get_stack(0) != null and model.count_item(&"test_beta") == 5 and model.get_stack(0).item_id == &"test_alpha", "blocked unequip retains equipped item and cannot overwrite grid contents")
	_mouse(_cell(view, 2), true)
	_motion(_gear(view, 0))
	_mouse(_gear(view, 0), false)
	_check(equipment.count_item(&"test_beta") == 1 and model.count_item(&"test_beta") == 5, "occupied equipment slot rejects without implicit swaps")
	_mouse(_gear(view, 0), true)
	_motion(_cell(view, 12))
	await _key(KEY_R)
	_mouse(_cell(view, 12), false)
	_check(equipment.get_stack(0) == null and model.get_stack(12).rotated and model.get_anchor_at(13) == 12 and model.count_item(&"test_beta") == 6, "unequip supports rotated placement and conserves the unit")
	_mouse(_cell(view, 10), true)
	_motion(_gear(view, 4))
	_mouse(_gear(view, 4), false)
	_check(equipment.get_stack(4) != null and model.count_item(&"test_gamma") == 0 and equipment.count_item(&"test_gamma") == 1, "primary equipment slot is bound and conserves its item")
	model.add(&"test_delta", 1)
	for size in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(800, 600)]:
		root.size = size
		await _frames()
		var left: Rect2 = view.character_panel.get_global_rect()
		var right: Rect2 = view.inventory_panel.get_global_rect()
		_check(root.get_visible_rect().encloses(left) and root.get_visible_rect().encloses(right) and not left.intersects(right), "both fixed panels fit without overlap at %s" % size)
		var cell_rect := Rect2(Vector2.ZERO, Vector2.ONE * view.cell_size())
		_check(is_equal_approx(cell_rect.size.x, cell_rect.size.y) and view.cell_size() * 6 <= view.grid.size.x and view.cell_size() * 6 <= view.grid.size.y, "six square cells per axis fit their drawing surface at %s" % size)
		await _capture("inventory-populated-%dx%d" % [size.x, size.y])
		menu.set_inventory_open(false)
		await _frames(2)
		_check(paused and view.character_panel.get_global_rect() == left, "character stays fixed when inventory closes at %s" % size)
		await _capture("character-only-%dx%d" % [size.x, size.y])
		menu.set_inventory_open(true)
		menu.set_character_open(false)
		await _frames(2)
		_check(paused and view.inventory_panel.get_global_rect() == right, "inventory stays fixed when character closes at %s" % size)
		await _capture("inventory-only-%dx%d" % [size.x, size.y])
		menu.set_character_open(true)
		await _frames(2)
	_mouse(_gear(view, 4), true)
	_motion(_cell(view, 18))
	_mouse(_cell(view, 18), false)
	_check(model.count_item(&"test_gamma") == 1 and equipment.count_item(&"test_gamma") == 0, "equipment returns safely to the grid after UI scaling changes")
	var alternate := SlotInventory.new(ItemCatalog.new([load("res://data/items/test_alpha.tres")]), 8, 1)
	view.bind_inventory(alternate)
	alternate.add(&"test_alpha", 3)
	_check(not model.changed.is_connected(view._refresh) and view.cell_size() == 75 and view._inventory.get_stack(0).quantity == 3, "rebind disconnects old observer and adapts square grid to configurable dimensions")
	view.bind_inventory(model, equipment)
	_check(player.inventory == model and model.count_item(&"test_alpha") == 14, "view rebinding preserves player-owned quantities")
	view.close_button.pressed.emit()
	await _frames()
	_check(paused and view.character_panel.visible and not view.inventory_panel.visible, "Close inventory button preserves character window pause")
	await _key(KEY_C)
	_check(not paused and not view.visible and player.controls_active, "C closes the remaining character window")
	await _key(KEY_TAB)
	_mouse(_cell(view, 0), true)
	_motion(_cell(view, 24))
	await _key(KEY_ESCAPE)
	_mouse(_cell(view, 24), false)
	_check(view._drag.is_empty() and model.get_stack(0).quantity == 10 and model.get_stack(24) == null and not paused, "Escape cancels an active drag without committing and closes windows")
	await _key(KEY_TAB)
	_mouse(_cell(view, 0), true)
	menu.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames()
	_check(paused and not view.visible and menu.overlay.visible and view._drag.is_empty() and model.count_item(&"test_alpha") == 14, "focus loss cancels drag and replaces windows with pause menu without losing items")
	menu.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames()
	_check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "focus return keeps gameplay paused")
	menu.main_menu_button.pressed.emit()
	await _frames(12)
	menu = current_scene.get_node("Menu")
	_check(not paused and not menu.inventory_view.visible and not current_scene.has_node("Player"), "return to main menu clears pause and removes gameplay")
	menu.primary_button.pressed.emit()
	await _frames(12)
	player = current_scene.get_node("Player")
	_check(not paused and player.controls_active and player.inventory.count_item(&"test_alpha") == 0 and player.inventory.count_item(&"test_beta") == 0, "fresh normal game after fixture still starts empty")
	print("INVENTORY UI RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
