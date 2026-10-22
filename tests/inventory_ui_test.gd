extends SceneTree
## Real menu/input integration plus isolated populated fixture. -- --capture-ui
## enables graphical snapshots; production gameplay is always checked empty.

var checks: int = 0
var failures: int = 0
var elapsed: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 35.0:
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


func _capture(name: String) -> void:
	if "--capture-ui" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + name + ".png")


func _run() -> void:
	change_scene_to_file("res://scenes/menus/main_menu.tscn")
	await _frames(12)
	root.mode = Window.MODE_WINDOWED
	var menu: Node = current_scene.get_node("Menu")
	await _key(KEY_I)
	_check(not menu.inventory_view.visible and not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "I does nothing in the main menu")
	menu.primary_button.pressed.emit()
	await _frames(12)
	menu = current_scene.get_node("Menu")
	var player: CharacterBody3D = current_scene.get_node("Player")
	var inventory: SlotInventory = player.inventory
	var view: Control = menu.inventory_view
	var empty := true
	for index in range(inventory.get_capacity()):
		empty = empty and inventory.get_stack(index) == null
	_check(inventory.get_capacity() == 20 and empty, "normal player owns twenty empty slots with no automatic items")
	await _key(KEY_I)
	_check(paused and view.visible and not menu.overlay.visible and not player.controls_active, "I opens inventory and suspends gameplay without showing pause menu")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not player.get_node("Interaction").prompt.visible, "inventory releases mouse and clears interaction HUD")
	_check(view._buttons.size() == 20 and "Empty" in view._buttons[0].text and root.gui_get_focus_owner() == view._buttons[0], "empty grid has correct slot count and initial keyboard focus")
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
	_check(player.position.is_equal_approx(position) and is_equal_approx(player.camera_yaw.rotation.y, yaw) and player.first_person == fps and player.get_node("Interaction").target == null, "inventory blocks movement, jumping, look, camera toggling and E interaction")
	for action in ["move_forward", "jump", "interact"]:
		Input.action_release(action)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(5, 5)
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not player.controls_active, "inventory background click cannot recapture the mouse")
	await _key(KEY_I, true)
	_check(view.visible and paused, "held I key echoes do not repeatedly toggle inventory")
	await _key(KEY_ESCAPE)
	_check(not paused and not view.visible and not menu.overlay.visible and player.controls_active and player.inventory == inventory, "Escape closes inventory directly into gameplay without replacing its data")
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "closing inventory captures the graphical OS cursor")
	await _key(KEY_I)
	await _key(KEY_I)
	_check(not paused and not view.visible and player.controls_active, "I also closes inventory and restores gameplay")
	await _key(KEY_ESCAPE)
	await _key(KEY_I)
	_check(paused and menu.overlay.visible and not view.visible, "I cannot bypass the pause menu")
	menu.primary_button.pressed.emit()
	await _frames()
	change_scene_to_file("res://tests/fixtures/inventory_demo.tscn")
	await _frames(12)
	var game: Node = current_scene.get_node("Gameplay")
	player = game.get_node("Player")
	menu = game.get_node("Menu")
	view = menu.inventory_view
	var fixture_inventory: SlotInventory = player.inventory
	_check(paused and view.visible and fixture_inventory.count_item(&"test_alpha") == 17 and fixture_inventory.count_item(&"test_beta") == 6 and fixture_inventory.count_item(&"test_gamma") == 1, "only the isolated fixture starts with populated test stacks")
	_check(inventory.count_item(&"test_alpha") == 0 and fixture_inventory != inventory, "fixture data is separate from the normal player inventory")
	_check("Test Alpha" in view._buttons[0].text and "10 / 10" in view._buttons[0].text and "Test Gamma" in view._buttons[4].text, "grid displays item placeholders, names and quantities")
	view._buttons[1].pressed.emit()
	view._buttons[5].pressed.emit()
	_check(fixture_inventory.get_stack(1) == null and fixture_inventory.get_stack(5).quantity == 7 and "Empty" in view._buttons[1].text, "slot clicks request a model move and refresh from its notification")
	view._buttons[5].pressed.emit()
	view.split_button.pressed.emit()
	view._buttons[6].pressed.emit()
	_check(fixture_inventory.get_stack(5).quantity == 4 and fixture_inventory.get_stack(6).quantity == 3 and fixture_inventory.count_item(&"test_alpha") == 17, "Split Half requests a conserving split, rounding down")
	view._buttons[6].pressed.emit()
	view._buttons[5].pressed.emit()
	_check(fixture_inventory.get_stack(6) == null and fixture_inventory.get_stack(5).quantity == 7, "slot clicks merge matching stacks")
	view._buttons[5].pressed.emit()
	view._buttons[0].pressed.emit()
	_check(fixture_inventory.get_stack(5).quantity == 7 and "No change" in view.status.text, "full destination is rejected without UI-side quantity edits")
	view._buttons[2].pressed.emit()
	_check(fixture_inventory.get_stack(2).item_id == &"test_beta" and fixture_inventory.count_item(&"test_alpha") == 17, "UI cannot overwrite another item type")
	view.clear_selection()
	fixture_inventory.add(&"test_alpha", 1)
	_check("8 / 10" in view._buttons[5].text, "external model changes refresh the observing UI")
	for size in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(800, 600)]:
		root.size = size
		await _frames()
		var panel: Control = view.get_node("Center/Panel")
		_check(root.get_visible_rect().encloses(panel.get_global_rect()) and view.grid.columns == 5 and is_equal_approx(view._buttons[0].size.x, view._buttons[4].size.x), "inventory panel and symmetric grid fit %s" % size)
		await _capture("inventory-populated-%dx%d" % [size.x, size.y])
	var alternate := SlotInventory.new(ItemCatalog.new([load("res://data/items/test_alpha.tres")]), 8)
	view.bind_inventory(alternate)
	alternate.add(&"test_alpha", 3)
	_check(view._buttons.size() == 8 and not fixture_inventory.changed.is_connected(view._refresh) and "3 / 10" in view._buttons[0].text, "view can rebind capacity/model and disconnect its old observer")
	view.bind_inventory(fixture_inventory)
	_check(player.inventory == fixture_inventory and fixture_inventory.count_item(&"test_alpha") == 18, "rebinding the view never replaces or destroys player-owned inventory")
	view.close_button.pressed.emit()
	await _frames()
	_check(not paused and not view.visible and player.controls_active, "Close button resumes gameplay through the menu controller")
	await _key(KEY_I)
	menu.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames()
	_check(paused and not view.visible and menu.overlay.visible and fixture_inventory.count_item(&"test_alpha") == 18, "focus loss replaces inventory with pause menu without losing items")
	menu.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames()
	_check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "focus return keeps gameplay paused")
	menu.main_menu_button.pressed.emit()
	await _frames(12)
	menu = current_scene.get_node("Menu")
	_check(not paused and not menu.inventory_view.visible and not current_scene.has_node("Player"), "return to main menu clears pause and removes gameplay/inventory UI")
	menu.primary_button.pressed.emit()
	await _frames(12)
	player = current_scene.get_node("Player")
	_check(not paused and player.controls_active and player.inventory.count_item(&"test_alpha") == 0 and player.inventory.count_item(&"test_beta") == 0, "fresh normal game after fixture still starts empty")
	print("INVENTORY UI RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
