extends SceneTree
## Native terrain, exploration route, persistence and island UI integration.

const SCENE := "res://scenes/island/island.tscn"
var checks := 0
var failures := 0
var elapsed := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 50.0:
		push_error("FAIL: island test timeout")
		quit(1)
	return false


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _capture(name: String) -> void:
	await _frames(5)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://.godot/island-" + name + ".png") == OK, "capture " + name)


func _run() -> void:
	var world := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	var terrain: Terrain3D = world.get_node("Terrain3D")
	var player: CharacterBody3D = world.get_node("Player")
	var menu: CanvasLayer = world.get_node("Menu")
	await _frames(60)
	_check(terrain.region_size == 256 and terrain.vertex_spacing == 1.0 and terrain.data.get_region_count() == 1, "one native 256 m editable region loaded")
	_check(terrain.assets.get_texture_count() == 3, "grass earth stone assets loaded")
	_check(player.is_on_floor() and player.position.y > 3.0, "safe dry spawn settles on terrain")
	_check(player.inventory.get_capacity() == 36 and player.inventory.get_stack(0) == null, "existing empty player inventory retained")
	var collision_matches := true
	for point in [Vector3(128, 0, 180), Vector3(128, 0, 128), Vector3(85, 0, 104), Vector3(171, 0, 90), Vector3(103, 0, 156)]:
		# Native dynamic collision follows the active camera; test each position
		# inside its generated radius instead of assuming a world-wide collider.
		player.position = point + Vector3.UP * (terrain.data.get_height(point) + 2.0)
		player.velocity = Vector3.ZERO
		await _frames(30)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 80, point + Vector3.DOWN * 10, 1))
		collision_matches = collision_matches and not hit.is_empty() and absf(hit.position.y - terrain.data.get_height(point)) < 0.15
	player.reset_to_spawn()
	await _frames(40)
	_check(collision_matches, "terrain collision matches saved heights at spawn valley peaks and shelf")
	_check(terrain.data.get_height(Vector3(85, 0, 104)) > 25 and terrain.data.get_height(Vector3(171, 0, 90)) > 23 and terrain.data.get_height(Vector3(128, 0, 128)) < 12, "two elevated areas flank a lower central valley")
	_check(terrain.data.get_height(Vector3(10, 0, 10)) < -5 and terrain.data.get_height(Vector3(240, 0, 240)) < -5, "terrain borders submerged below sea")
	var start := player.position
	player.set_mouse_captured(true)
	Input.action_press("move_forward")
	await _frames(720)
	Input.action_release("move_forward")
	await _frames(20)
	_check(start.z - player.position.z > 50 and player.is_on_floor() and player.position.y > 0, "twelve second exploration walk reaches central valley on dry ground")
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	await _frames(95)
	_check(player.is_on_floor(), "jump lands on island terrain")
	menu.set_inventory_open(true)
	menu.set_character_open(true)
	var frozen := player.position
	await _frames(10)
	_check(paused and not player.controls_active and player.position == frozen and menu.inventory_view.inventory_panel.visible and menu.inventory_view.character_panel.visible, "both inventory windows pause island and player")
	menu.set_inventory_open(false)
	_check(paused, "character window keeps island paused")
	menu.set_character_open(false)
	await _frames(4)
	_check(not paused and player.controls_active, "closing both windows resumes island")
	# Native edit/save/reload uses scratch copies only, preserving hand edits.
	var original := terrain.data.get_height(Vector3(128, 0, 128))
	var scratch := "res://.godot/island_roundtrip"
	DirAccess.make_dir_recursive_absolute(scratch)
	terrain.data.set_height(Vector3(128, 0, 128), original + 0.25)
	terrain.data.set_region_modified(Vector2i.ZERO, true)
	terrain.data.save_directory(scratch)
	terrain.data.load_directory(scratch)
	_check(is_equal_approx(terrain.data.get_height(Vector3(128, 0, 128)), original + 0.25), "native terrain edit save reload preserves height")
	terrain.data.load_directory("res://scenes/island/data")
	_check(is_equal_approx(terrain.data.get_height(Vector3(128, 0, 128)), original), "original island data reloads unchanged")
	if "--capture-island" in OS.get_cmdline_user_args():
		player.reset_to_spawn()
		await _frames(40)
		await _capture("ground-tps")
		player.set_first_person(true)
		await _capture("ground-fps")
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(285, 195, 320)
		camera.look_at(Vector3(128, 2, 125))
		camera.current = true
		terrain.set_camera(camera)
		await _capture("overview")
		camera.position = Vector3(128, 310, 128)
		camera.look_at(Vector3(128, 0, 128), Vector3.FORWARD)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 285
		await _capture("top")
	world.queue_free()
	await process_frame
	print("ISLAND RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
