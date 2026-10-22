extends SceneTree
## Real physics/input integration checks. Run with --headless --path . --script.

var player: CharacterBody3D
var failures: int = 0
var checks: int = 0
var elapsed: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 40.0:
		push_error("FAIL: smoke test timeout")
		quit(1)
	return false


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
	# Resume after bodies have completed their physics callbacks.
	await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _place(position: Vector3) -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump"]:
		Input.action_release(action)
	player.position = position
	player.velocity = Vector3.ZERO
	player.get_node("CameraYaw").rotation.y = 0.0
	player.set_mouse_captured(true)
	await _frames(20)


func _run() -> void:
	var world := load("res://scenes/main.tscn") as PackedScene
	_check(world != null, "main scene loads")
	if world == null:
		quit(1)
		return
	var main := world.instantiate()
	root.add_child(main)
	current_scene = main
	player = main.get_node("Player") as CharacterBody3D
	await _frames(40)
	_check(player.is_on_floor() and absf(player.position.y) < 0.03, "spawn settles on floor")
	player.set_mouse_captured(true)
	var start := player.position
	Input.action_press("move_forward")
	await _frames(60)
	var walk_distance := start.z - player.position.z
	_check(walk_distance > 3.5 and walk_distance < 5.0, "walk accelerates to expected speed")
	Input.action_release("move_forward")
	await _frames(25)
	_check(Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "release decelerates to rest")
	await _place(Vector3(0, 0.05, 17))
	start = player.position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(60)
	_check(start.z - player.position.z > walk_distance + 0.5, "gradual sprint is faster than walk")
	await _place(Vector3(0, 0.05, 17))
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await _frames(40)
	_check(Vector2(player.velocity.x, player.velocity.z).length() < 4.6, "diagonal speed is normalized")
	await _place(Vector3(0, 0.05, 17))
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	var peak := player.position.y
	for frame in range(100):
		await _frames(1)
		peak = maxf(peak, player.position.y)
	print("MEASURED standing jump peak: %.3f m" % peak)
	_check(peak > 1.4 and peak < 1.65 and player.is_on_floor(), "jump peaks near 1.5 meters and lands under gravity")
	await _place(Vector3(22, 0.05, 15))
	Input.action_press("move_right")
	await _frames(60)
	_check(player.position.x < 23.55 and player.get_slide_collision_count() > 0, "boundary stops capsule")
	await _place(Vector3(-16, 0.05, -5))
	Input.action_press("move_forward")
	await _frames(80)
	_check(player.position.y > 0.8 and player.is_on_floor(), "15 degree ramp is walkable")
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await _frames(65)
	_check(player.position.y < 0.2 and player.is_on_floor(), "descending ramp stays grounded")
	await _place(Vector3(-10, 0.05, -5))
	Input.action_press("move_forward")
	await _frames(90)
	_check(player.position.y > 1.4 and player.is_on_floor(), "30 degree ramp is walkable")
	await _place(Vector3(-4, 0.05, -5))
	Input.action_press("move_forward")
	await _frames(100)
	_check(player.position.y < 0.5, "50 degree ramp blocks uphill walking")
	await _place(Vector3(13, 0.05, 10))
	Input.action_press("move_forward")
	await _frames(110)
	_check(player.position.z < 3.0, "0.8 meter passage admits 0.6 meter capsule")
	await _place(Vector3(6, 1.5, -11.55))
	Input.action_press("move_back")
	await _frames(90)
	_check(player.position.z > -6.0 and player.position.y < 0.1 and player.is_on_floor(), "stairs can be descended without snagging")
	await _place(Vector3(0, 0.05, 17))
	player.get_node("CameraYaw").rotation.y = PI / 2.0
	Input.action_press("move_forward")
	await _frames(35)
	_check(player.position.x < -1.5, "movement follows camera yaw")
	await _place(Vector3(0, 0.05, 17))
	var toggle := InputEventAction.new()
	toggle.action = "toggle_camera"
	toggle.pressed = true
	player._unhandled_input(toggle)
	_check(player.first_person and not player.visuals.visible and player.spring_arm.spring_length == 0.0, "V action selects FPS and hides model")
	Input.action_press("move_forward")
	await _frames(25)
	_check(player.position.z < 16.0, "FPS uses the same movement controller")
	Input.action_release("move_forward")
	player._unhandled_input(toggle)
	_check(not player.first_person and player.visuals.visible and player.spring_arm.spring_length == 3.5, "V action restores TPS")
	var motion := InputEventMouseMotion.new()
	motion.screen_relative = Vector2(20, 100000)
	player._unhandled_input(motion)
	_check(absf(player.camera_yaw.rotation.y + 0.05) < 0.001 and absf(player.camera_pitch.rotation.x - deg_to_rad(-80)) < 0.001, "mouse sensitivity and pitch clamp")
	player.reset_to_spawn()
	await _frames(20)
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 4, 0.3)
	collider.shape = shape
	wall.add_child(collider)
	main.add_child(wall)
	wall.position = Vector3(0, 2, 19)
	await _frames(10)
	_check(player.spring_arm.get_hit_length() < 2.0, "TPS spring arm retracts before wall")
	wall.queue_free()
	await _frames(10)
	_check(player.spring_arm.get_hit_length() > 3.4, "TPS spring arm extends in open space")
	player.set_mouse_captured(false)
	Input.action_press("move_forward")
	await _frames(30)
	_check(absf(player.velocity.z) < 0.01, "released mouse disables movement input")
	Input.action_release("move_forward")
	player.position.y = -15.0
	await _frames(10)
	_check(player.position.distance_to(Vector3(0, 0, 17)) < 0.1, "fall recovery returns to spawn")
	print("SMOKE RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
