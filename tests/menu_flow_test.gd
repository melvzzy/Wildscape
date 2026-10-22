extends SceneTree
## Exercises real scene changes and input dispatch. Optional -- --capture-ui
## saves menu screenshots when run with a graphical display driver.

var checks: int = 0
var failures: int = 0
var elapsed: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 35.0:
		push_error("FAIL: menu flow timeout")
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


func _escape() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await _frames()


func _accept() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await _frames(12)


func _navigate(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await _frames(2)


func _capture(name: String) -> void:
	if "--capture-ui" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + name + ".png")


func _run() -> void:
	var startup: String = ProjectSettings.get_setting("application/run/main_scene")
	_check(startup == "res://scenes/menus/main_menu.tscn", "F5 starts at the main menu")
	_check(ProjectSettings.get_setting_with_override("physics/3d/physics_engine") == "DEFAULT", "existing physics backend setting is unchanged (DEFAULT / GodotPhysics3D)")
	print("PHYSICS BACKEND: DEFAULT resolves to GodotPhysics3D; no engine switch")
	change_scene_to_file(startup)
	await _frames(12)
	var menu: Node = current_scene.get_node("Menu")
	_check(not paused and menu.overlay.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "main menu is unpaused with a visible cursor")
	_check(menu.primary_button.text == "Play" and not menu.main_menu_button.visible and menu.quit_button.text == "Quit", "main menu exposes only Play and Quit")
	_check(root.gui_get_focus_owner() == menu.primary_button, "Play receives initial keyboard focus")
	await _navigate(KEY_DOWN)
	_check(root.gui_get_focus_owner() == menu.quit_button, "Down navigates from Play to Quit, skipping hidden pause-only controls")
	await _navigate(KEY_UP)
	_check(root.gui_get_focus_owner() == menu.primary_button, "Up returns keyboard focus to Play")
	if DisplayServer.get_name() != "headless":
		_check(root.mode == Window.MODE_FULLSCREEN, "graphical startup uses borderless fullscreen, not exclusive mode")
		print("DISPLAY: fullscreen window %s on monitor %s" % [root.size, DisplayServer.screen_get_size()])
	root.mode = Window.MODE_WINDOWED
	for size in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(800, 600)]:
		root.size = size
		await _frames(3)
		var panel: Control = menu.get_node("Overlay/Center/Panel")
		var viewport_rect := root.get_visible_rect()
		var panel_rect := panel.get_global_rect()
		_check(viewport_rect.encloses(panel_rect) and panel_rect.get_center().distance_to(viewport_rect.get_center()) < 2.0, "menu stays centered and visible at %s" % size)
		_check(is_equal_approx(menu.primary_button.size.x, menu.quit_button.size.x), "button widths are symmetric at %s" % size)
		await _capture("main-menu-%dx%d" % [size.x, size.y])
	await _accept()
	_check(current_scene.scene_file_path == "res://scenes/main.tscn", "keyboard Enter on Play loads gameplay")
	menu = current_scene.get_node("Menu")
	var player: CharacterBody3D = current_scene.get_node("Player")
	_check(not paused and player.controls_active and not menu.overlay.visible, "entering gameplay enables controls and hides menus")
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "graphical gameplay captures the OS cursor")
	Input.action_press("move_forward")
	await _frames(20)
	_check(player.position.z < 16.5, "gameplay movement remains responsive")
	Input.action_release("move_forward")
	var rigid := RigidBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = SphereShape3D.new()
	rigid.add_child(collision)
	current_scene.add_child(rigid)
	rigid.position = Vector3(2, 7, 17)
	Input.action_press("jump")
	await _frames(5)
	Input.action_release("jump")
	await _escape()
	_check(paused and menu.overlay.visible and not player.controls_active, "Escape pauses gameplay and opens the pause menu")
	_check(menu.primary_button.text == "Resume" and menu.main_menu_button.visible, "pause menu offers Resume, Main Menu and Quit")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pause releases the OS cursor")
	_check(not player.can_process() and not player.get_node("Interaction").can_process() and not player.spring_arm.can_process(), "player, interaction and spring arm are all paused")
	_check(menu.can_process(), "menu remains processable while gameplay is paused")
	var frozen_position := player.position
	var frozen_velocity := player.velocity
	var rigid_position := rigid.position
	var yaw: float = player.camera_yaw.rotation.y
	var fps: bool = player.first_person
	Input.action_press("move_forward")
	Input.action_press("jump")
	Input.action_press("interact")
	var mouse := InputEventMouseMotion.new()
	mouse.screen_relative = Vector2(150, 100)
	root.push_input(mouse)
	var toggle := InputEventAction.new()
	toggle.action = "toggle_camera"
	toggle.pressed = true
	root.push_input(toggle)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(10, 10)
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await _frames(12)
	_check(player.position.is_equal_approx(frozen_position) and player.velocity.is_equal_approx(frozen_velocity), "pause freezes player motion and jump physics")
	_check(rigid.position.is_equal_approx(rigid_position), "pause also freezes independent rigid-body physics")
	_check(is_equal_approx(player.camera_yaw.rotation.y, yaw) and player.first_person == fps, "pause blocks mouse look and camera switching")
	_check(not player.controls_active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "clicking menu background cannot capture the mouse")
	for size in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(800, 600)]:
		root.size = size
		await _frames(3)
		var panel: Control = menu.get_node("Overlay/Center/Panel")
		_check(root.get_visible_rect().encloses(panel.get_global_rect()) and panel.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center()) < 2.0 and is_equal_approx(menu.primary_button.size.x, menu.main_menu_button.size.x), "pause composition stays centered, visible and aligned at %s" % size)
		await _capture("pause-menu-%dx%d" % [size.x, size.y])
	for action in ["move_forward", "jump", "interact"]:
		Input.action_release(action)
	await _escape()
	_check(not paused and player.controls_active, "Escape resumes gameplay")
	await _frames(15)
	_check(not rigid.position.is_equal_approx(rigid_position), "rigid-body physics continues after resume")
	rigid.queue_free()
	# Aim at a real interactable, then ensure pause blocks even direct activation.
	player.reset_to_spawn()
	player.position = Vector3(-12, 0.05, 13.1)
	player.reset_physics_interpolation()
	await _frames(20)
	player.set_first_person(true)
	var interactable: WorldInteractable = current_scene.get_node("Playground/InteractionArea/Switch")
	var aim := interactable.global_position + Vector3.UP * 0.9 - (player.global_position + Vector3.UP * 1.62)
	player.camera_yaw.rotation.y = atan2(-aim.x, -aim.z)
	player.camera_pitch.rotation.x = atan2(aim.y, Vector2(aim.x, aim.z).length())
	await _frames()
	var interaction: Node = player.get_node("Interaction")
	_check(interaction.target == interactable and interaction.prompt.visible, "interaction is available before pausing")
	menu.set_paused(true)
	interaction.try_interact()
	Input.action_press("interact")
	await _frames(5)
	_check(not interactable.active and interaction.target == null and not interaction.prompt.visible, "pause blocks E/direct interaction and clears prompts immediately")
	Input.action_release("interact")
	Input.action_press("jump")
	menu.primary_button.pressed.emit()
	await _frames(5)
	Input.action_release("jump")
	_check(not paused and player.controls_active and player.position.y < 0.1, "Resume button works without leaking its Space/jump input")
	menu.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(2)
	_check(paused and not player.controls_active and menu.overlay.visible, "focus loss pauses and releases gameplay controls")
	menu.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(2)
	_check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "focus return does not silently resume")
	menu.main_menu_button.pressed.emit()
	await _frames(12)
	menu = current_scene.get_node("Menu")
	_check(current_scene.scene_file_path == startup and not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "returning to main menu clears pause and releases cursor")
	_check(not current_scene.has_node("Player"), "returning to main menu removes the old gameplay scene")
	menu.primary_button.pressed.emit()
	await _frames(12)
	_check(not paused and current_scene.get_node("Player").controls_active and not current_scene.get_node("Playground/InteractionArea/Switch").active, "Play after pause return creates a fresh usable gameplay session")
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(12)
	menu = current_scene.get_node("Menu")
	_check(not paused and current_scene.get_node("Player").controls_active and not menu.overlay.visible, "gameplay scene also starts independently (F6 path)")
	menu.set_paused(true)
	menu.quit_button.pressed.emit()
	_check(not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Quit clears pause and releases cursor before exit")
	print("FLOW RESULT: %d checks, %d failures" % [checks, failures])
	if failures > 0:
		quit(1)
