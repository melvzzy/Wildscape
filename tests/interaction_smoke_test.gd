extends SceneTree
## Integration checks for movement tuning and the interaction contract.

var player: CharacterBody3D
var interactor: Node
var main: Node3D
var failures: int = 0
var checks: int = 0
var elapsed: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 35.0:
		push_error("FAIL: interaction test timeout")
		quit(1)
	return false


func _frames(count: int) -> void:
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


func _place(position: Vector3) -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump", "interact"]:
		Input.action_release(action)
	player.reset_to_spawn()
	player.global_position = position
	player.reset_physics_interpolation()
	player.set_mouse_captured(true)
	await _frames(20)


func _aim(point: Vector3) -> void:
	var direction := point - (player.global_position + Vector3.UP * 1.62)
	player.camera_yaw.rotation.y = atan2(-direction.x, -direction.z)
	player.camera_pitch.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())
	await _frames(5)


func _press_interact() -> void:
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)


func _wall(position: Vector3, width: float = 2.0) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 3.0, 0.2)
	collision.shape = shape
	wall.add_child(collision)
	main.add_child(wall)
	wall.position = position
	return wall


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	player = main.get_node("Player")
	interactor = player.get_node("Interaction")
	await _place(Vector3(0, 0.05, 17))
	Input.action_press("move_forward")
	await _frames(30)
	var walk_speed := -player.velocity.z
	Input.action_press("sprint")
	await _frames(10)
	var early_speed := -player.velocity.z
	await _frames(20)
	var middle_speed := -player.velocity.z
	await _frames(40)
	var full_speed := -player.velocity.z
	print("MEASURED sprint speeds: walk %.3f, early %.3f, middle %.3f, full %.3f m/s" % [walk_speed, early_speed, middle_speed, full_speed])
	_check(early_speed > walk_speed and early_speed < 5.1, "sprint begins gradually from walking")
	_check(middle_speed > early_speed + 0.3 and middle_speed < full_speed - 0.2, "sprint continues accelerating progressively")
	_check(absf(full_speed - 6.2) < 0.05, "sprint reaches configured maximum")
	Input.action_release("sprint")
	await _frames(20)
	_check(absf(-player.velocity.z - 4.5) < 0.05, "releasing sprint restores responsive walking")
	await _place(Vector3(0, 0.05, 17))
	Input.action_press("sprint")
	await _frames(60)
	Input.action_press("move_forward")
	await _frames(15)
	_check(-player.velocity.z < 5.1, "holding sprint at rest does not precharge running speed")
	await _place(Vector3(0, 0.05, 17))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(80)
	var jump_start := player.position
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	var air_frames := 1
	while not player.is_on_floor() and air_frames < 120:
		await _frames(1)
		air_frames += 1
	var jump_distance := jump_start.z - player.position.z
	print("MEASURED sprint jump: %.3f m horizontal, %d physics steps" % [jump_distance, air_frames])
	_check(jump_distance > 4.5 and jump_distance < 6.3 and player.is_on_floor(), "sprint jump preserves momentum with reduced travel distance")
	var area := main.get_node("Playground/InteractionArea")
	var switch: WorldInteractable = area.get_node("Switch")
	var beacon: WorldInteractable = area.get_node("Beacon")
	var token: WorldInteractable = area.get_node("Token")
	var point := switch.global_position + Vector3.UP * 0.9
	await _place(switch.global_position + Vector3(0, 0.05, 2.1))
	player.set_first_person(true)
	await _aim(point)
	_check(interactor.target == switch and interactor.prompt.visible, "FPS targets nearby object and displays prompt")
	_check(interactor.prompt.text == "[E] Switch on", "prompt describes available switch action")
	var emitted := [0]
	switch.interacted.connect(func(_actor: Node3D) -> void: emitted[0] += 1)
	await _press_interact()
	_check(switch.active and emitted[0] == 1, "E toggles switch and emits contract signal once")
	_check(interactor.prompt.text == "[E] Switch off", "prompt updates after state change")
	Input.action_press("interact")
	await _frames(20)
	Input.action_release("interact")
	await _frames(2)
	_check(not switch.active and emitted[0] == 2, "held E does not repeatedly activate")
	player.set_first_person(false)
	await _frames(6)
	_check(interactor.target == switch and interactor.prompt.visible, "TPS targets same object at same player position")
	await _press_interact()
	_check(switch.active, "TPS interaction uses the same contract")
	await _place(switch.global_position + Vector3(0, 0.05, 3.5))
	await _aim(point)
	for fps in [false, true]:
		player.set_first_person(fps)
		await _frames(6)
		await _press_interact()
		_check(interactor.target == null and not interactor.prompt.visible and switch.active, "range blocks activation and prompt in %s" % ("FPS" if fps else "TPS"))
	await _place(switch.global_position + Vector3(0, 0.05, 2.1))
	await _aim(point)
	var wall := _wall(switch.global_position + Vector3(0, 1.5, 1.0))
	await _frames(5)
	for fps in [true, false]:
		player.set_first_person(fps)
		await _frames(6)
		await _press_interact()
		_check(interactor.target == null and not interactor.prompt.visible and switch.active, "wall blocks prompt and E in %s" % ("FPS" if fps else "TPS"))
	wall.queue_free()
	await _frames(3)
	# Simulate an offset TPS view: camera sees around a thin obstacle, player cannot.
	wall = _wall(switch.global_position + Vector3(0, 1.5, 1.0), 0.4)
	await _frames(5)
	player.camera.global_position = switch.global_position + Vector3(2, 1.62, 4.0)
	player.camera.look_at(point)
	var camera_hit: Dictionary = interactor._ray(player.camera.global_position, point)
	_check(not camera_hit.is_empty() and camera_hit.collider == switch, "offset camera can see past the narrow test wall")
	interactor.try_interact()
	_check(interactor.target == null and switch.active, "player eye sight check rejects TPS corner peeking")
	player.camera.rotation = Vector3.ZERO
	wall.queue_free()
	await _frames(6)
	await _aim(point)
	player.set_mouse_captured(false)
	await _frames(3)
	await _press_interact()
	_check(interactor.target == null and not interactor.prompt.visible and not interactor.aim_dot.visible and switch.active, "released controls hide prompt and block interactions")
	player.set_mouse_captured(true)
	switch.interaction_enabled = false
	await _frames(3)
	_check(interactor.target == null and not interactor.prompt.visible, "disabled interactable cannot be targeted")
	switch.interaction_enabled = true
	await _aim(player.global_position + Vector3(3, 1, 0))
	_check(interactor.target == null and not interactor.prompt.visible, "looking away clears prompt")
	await _place(beacon.global_position + Vector3(0, 0.05, 2.1))
	await _aim(beacon.global_position + Vector3.UP * 0.9)
	await _press_interact()
	_check(beacon.active and not beacon.interaction_enabled and interactor.target == null, "beacon activates once then loses prompt")
	_check(switch.active, "beacon does not change neighboring switch state")
	await _place(token.global_position + Vector3(0, 0.05, 2.1))
	await _aim(token.global_position + Vector3.UP * 0.9)
	_check(interactor.target == token, "test token is targetable")
	await _press_interact()
	_check(not is_instance_valid(token) and interactor.target == null and not interactor.prompt.visible, "test token disappears and clears target safely")
	print("INTERACTION RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
